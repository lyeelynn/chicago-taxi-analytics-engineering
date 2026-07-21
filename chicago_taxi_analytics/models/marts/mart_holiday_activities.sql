WITH cte_agg AS (
    SELECT 
        trip_date,

        -- total
        COUNT(DISTINCT taxi_id) as active_taxi_count,
        SUM(total_trips) as total_trips,
        SUM(total_driver_earnings) as total_driver_earnings,
        SUM(total_revenue) as total_revenue,
        SUM(total_miles) as total_miles,
        (SUM(total_seconds)/60/60) as total_trip_hours,

        -- per trip or taxi
        SUM(total_revenue)/SUM(total_trips) as revenue_per_trip,
        SUM(total_driver_earnings)/SUM(total_trips) as driver_earnings_per_trip,
        (SUM(total_seconds)/60/60)/SUM(total_trips) as hours_per_trip,
        SUM(total_trips)/COUNT(DISTINCT taxi_id) trips_per_taxi
    -- for local test
    FROM 'int_taxi_daily_metrics.parquet'
    -- for dbt prod
    -- FROM {{ ref('int_taxi_daily_metrics') }}  
    GROUP BY 1
),

holiday_dates as (
    SELECT DISTINCT 
        trip_date,
        holiday_name
    -- for local test
    FROM 'int_taxi_daily_metrics.parquet' hols
    -- for dbt prod
    -- FROM {{ ref('int_taxi_daily_metrics') }} 
    WHERE is_holiday = 1
),

cte_holidays as (
    SELECT
        hols.trip_date,
        hols.holiday_name,
        agg.active_taxi_count,
        agg.total_trips,
        agg.total_driver_earnings,
        agg.total_revenue,
        agg.total_miles,
        agg.total_trip_hours,
        agg.driver_earnings_per_trip,
        agg.revenue_per_trip,
        agg.trips_per_taxi
    FROM holiday_dates hols 
    LEFT JOIN cte_agg agg 
        on hols.trip_date = agg.trip_date
),

cte_non_holidays as (
    SELECT
        agg.*
    FROM cte_agg agg 
    LEFT JOIN holiday_dates hols 
        on hols.trip_date = agg.trip_date
    WHERE hols.holiday_name IS NULL
),

cte_baseline as (
    SELECT 
        hols.trip_date,

        -- baseline period
        (hols.trip_date - INTERVAL 28 DAY) as baseline_period_start,
        (hols.trip_date - INTERVAL 1 DAY) as baseline_period_end,

        -- baseline avg
        AVG(nh.active_taxi_count) as baseline_4w_avg_daily_active_taxi_count,
        AVG(nh.total_trips) as baseline_4w_avg_daily_trips,
        AVG(nh.total_driver_earnings) as baseline_4w_avg_daily_driver_earnings,
        AVG(nh.total_revenue) as baseline_4w_avg_daily_revenue,
        AVG(nh.total_miles) as baseline_4w_avg_daily_miles,
        AVG(nh.total_trip_hours) as baseline_4w_avg_daily_trip_hours,
        AVG(nh.driver_earnings_per_trip) as baseline_4w_avg_daily_driver_earnings_per_trip,
        AVG(nh.revenue_per_trip) as baseline_4w_avg_daily_revenue_per_trip,
        AVG(nh.trips_per_taxi) as baseline_4w_avg_daily_trips_per_taxi
    FROM holiday_dates hols
    LEFT JOIN cte_non_holidays nh
        ON nh.trip_date >= (hols.trip_date - INTERVAL 28 DAY)
        AND nh.trip_date < hols.trip_date
    GROUP BY hols.trip_date
)

SELECT 
    hols.trip_date,
    hols.holiday_name,
    base.baseline_period_start,
    base.baseline_period_end,

    -- holiday metrics
    hols.active_taxi_count,
    hols.total_trips,
    hols.total_driver_earnings,
    hols.total_revenue,
    hols.total_miles,
    hols.total_trip_hours,
    hols.driver_earnings_per_trip,
    hols.revenue_per_trip,
    hols.trips_per_taxi,
    
    -- baseline metrics
    baseline_4w_avg_daily_active_taxi_count,
    baseline_4w_avg_daily_trips,
    baseline_4w_avg_daily_driver_earnings,
    baseline_4w_avg_daily_revenue,
    baseline_4w_avg_daily_miles,
    baseline_4w_avg_daily_trip_hours,
    baseline_4w_avg_daily_driver_earnings_per_trip,
    baseline_4w_avg_daily_revenue_per_trip,
    baseline_4w_avg_daily_trips_per_taxi,

    -- pct chg
    (hols.active_taxi_count - baseline_4w_avg_daily_active_taxi_count)/ baseline_4w_avg_daily_active_taxi_count as pct_change_active_taxi_count,
    (hols.total_trips - baseline_4w_avg_daily_trips)/ baseline_4w_avg_daily_trips as pct_change_trips,
    (hols.total_driver_earnings - baseline_4w_avg_daily_driver_earnings)/ baseline_4w_avg_daily_driver_earnings as pct_change_driver_earnings,
    (hols.total_revenue - baseline_4w_avg_daily_revenue)/ baseline_4w_avg_daily_revenue as pct_change_revenue,
    (hols.total_miles - baseline_4w_avg_daily_miles)/ baseline_4w_avg_daily_miles as pct_change_miles,
    (hols.total_trip_hours - baseline_4w_avg_daily_trip_hours)/ baseline_4w_avg_daily_trip_hours as pct_change_trip_hours,
    (hols.driver_earnings_per_trip - baseline_4w_avg_daily_driver_earnings_per_trip)/ baseline_4w_avg_daily_driver_earnings_per_trip as pct_change_driver_earnings_per_trip,
    (hols.revenue_per_trip - baseline_4w_avg_daily_revenue_per_trip)/ baseline_4w_avg_daily_revenue_per_trip as pct_change_revenue_per_trip,
    (hols.trips_per_taxi - baseline_4w_avg_daily_trips_per_taxi)/ baseline_4w_avg_daily_trips_per_taxi as pct_change_trips_per_taxi

FROM cte_holidays hols
LEFT JOIN cte_baseline base
    ON hols.trip_date = base.trip_date
ORDER BY hols.trip_date