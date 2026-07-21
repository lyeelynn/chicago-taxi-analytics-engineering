WITH cte_date AS (
    {{ get_rolling_period(
        'trip_date',
        ref('int_taxi_daily_metrics'),
        3
    ) }}
),

cte_agg AS (
    SELECT
        taxi_id,

        -- period
        min(trip_date) as first_active_date,
        max(trip_date) as last_active_date,
        COUNT(DISTINCT trip_date) as active_days,

        -- trip
        SUM(total_miles) as total_miles,
        (SUM(total_seconds)/60/60) as total_trip_hours,

        -- earnings
        SUM(total_trips) as total_trips,
        SUM(total_fare) as total_fare,
        SUM(total_tips) as total_tips,
        SUM(total_revenue) as total_revenue,
        SUM(total_driver_earnings) as total_driver_earnings,

        -- per trip
        SUM(total_fare)/SUM(total_trips) as fare_per_trip,
        SUM(total_tips)/SUM(total_trips) as tips_per_trip,
        SUM(total_extras)/SUM(total_trips) as extras_per_trip,
        SUM(total_tolls)/SUM(total_trips) as tolls_per_trip,
        SUM(total_revenue)/SUM(total_trips) as revenue_per_trip,
        SUM(total_driver_earnings)/SUM(total_trips) as driver_earnings_per_trip,
        SUM(total_miles)/SUM(total_trips) as miles_per_trip,

        -- per active days
        SUM(total_fare)/COUNT(DISTINCT trip_date) as fare_per_active_day,
        SUM(total_tips)/COUNT(DISTINCT trip_date) as tips_per_active_day,
        SUM(total_revenue)/COUNT(DISTINCT trip_date) as revenue_per_active_day,
        SUM(total_driver_earnings)/COUNT(DISTINCT trip_date) as driver_earnings_per_active_day,

        -- per mile
        SUM(total_fare)/SUM(total_miles) as fare_per_mile,
        SUM(total_tips)/SUM(total_miles) as tips_per_mile,
        SUM(total_extras)/SUM(total_miles) as extras_per_mile,
        SUM(total_tolls)/SUM(total_miles) as tolls_per_mile,
        SUM(total_revenue)/SUM(total_miles) as revenue_per_mile,
        SUM(total_driver_earnings)/SUM(total_miles) as driver_earnings_per_mile,

        -- tips as pct
        SUM(total_tips) / SUM(total_fare) as tips_pct_of_fare,
        SUM(total_tips) / SUM(total_driver_earnings) as tips_pct_of_driver_earnings 

    FROM {{ ref('int_taxi_daily_metrics') }} 
    WHERE trip_date >= (SELECT period_start_date FROM cte_date)
    GROUP BY 1
)

SELECT
    date.period_start_date,
    date.period_end_date,
    agg.*,
    DENSE_RANK() OVER(ORDER BY total_revenue DESC) as rank_by_total_revenue,
    DENSE_RANK() OVER(ORDER BY total_driver_earnings DESC) as rank_by_total_driver_earnings,
    DENSE_RANK() OVER(ORDER BY total_tips DESC) as rank_by_total_tips,
    DENSE_RANK() OVER(ORDER BY tips_per_trip DESC) as rank_by_tips_per_trip
FROM cte_agg agg
CROSS JOIN cte_date date