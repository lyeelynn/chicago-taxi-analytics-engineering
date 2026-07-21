WITH taxi_details as (
    SELECT DISTINCT
        taxi_id,
        taxi_company as taxi_company,
        date(trip_start_timestamp) as trip_date
    FROM {{ ref('stg_taxi_trips') }} as trips
    WHERE taxi_company IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY
            taxi_id,
            DATE(trip_start_timestamp)
        ORDER BY taxi_company
    ) = 1
    -- if a taxi_id is tied to multiple companies
    -- only keep the first company alphabetically for that taxi_id on that trip_date
),

daily_details as (
    SELECT 
        taxi_id,
        date(trip_start_timestamp) as trip_date,

        -- trip
        count(distinct unique_key) as total_trips,
        sum(trip_miles) as total_miles,
        max(trip_miles) as max_trip_miles,
        sum(trip_seconds) as total_seconds,
        max(trip_seconds) as max_trip_seconds,
        min(trip_start_timestamp) as first_trip_start_datetime,
        max(trip_end_timestamp) as last_trip_end_datetime,


        -- revenue
        sum(fare + tips + tolls + extras) as total_revenue,
        sum(fare + tips) as total_driver_earnings,
        sum(fare) as total_fare,
        sum(tips) as total_tips,
        sum(tolls) as total_tolls,
        sum(extras) as total_extras
    FROM {{ ref('stg_taxi_trips') }} as trips
    GROUP BY 1,2
),

details_per_trip as (
    SELECT DISTINCT
        taxi_id,
        trip_date,
        (total_revenue / total_trips) as revenue_per_trip,
        (total_driver_earnings / total_trips) as driver_earnings_per_trip,
        (total_fare / total_trips) as fare_per_trip,
        (total_tips / total_trips) as tips_per_trip,
        (total_tolls / total_trips) as tolls_per_trip,
        (total_extras / total_trips) as extras_per_trip,
        (total_seconds / total_trips) as seconds_per_trip,
        (total_miles / total_trips) as miles_per_trip
    FROM daily_details
)

SELECT 
    dd.taxi_id,
    dd.trip_date,
    CASE
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 1 THEN 'Sunday'
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 2 THEN 'Monday'
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 3 THEN 'Tuesday'
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 4 THEN 'Wednesday'
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 5 THEN 'Thursday'
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 6 THEN 'Friday'
        WHEN EXTRACT(DAYOFWEEK from dd.trip_date) = 7 THEN 'Saturday'
    END as day_of_week,
    CASE
        WHEN hol.holiday_name IS NOT NULL THEN 1
        ELSE 0
    END as is_holiday,
    hol.holiday_name,
    td.taxi_company,
    dd.total_trips,
    dd.total_miles,
    dd.max_trip_miles,
    dd.total_seconds,
    dd.max_trip_seconds,
    dd.first_trip_start_datetime,
    dd.last_trip_end_datetime,
    dd.total_revenue,
    dd.total_driver_earnings,
    dd.total_fare,
    dd.total_tips,
    dd.total_tolls,
    dd.total_extras,
    (dd.total_revenue / dd.total_trips) as revenue_per_trip,
    (dd.total_driver_earnings / dd.total_trips) as driver_earnings_per_trip,
    (dd.total_fare / dd.total_trips) as fare_per_trip,
    (dd.total_tips / dd.total_trips) as tips_per_trip,
    (dd.total_tolls / dd.total_trips) as tolls_per_trip,
    (dd.total_extras / dd.total_trips) as extras_per_trip,
    (dd.total_seconds / dd.total_trips) as seconds_per_trip,
    (dd.total_miles / dd.total_trips) as miles_per_trip
FROM daily_details dd
LEFT JOIN taxi_details td
    on dd.taxi_id = td.taxi_id
    and dd.trip_date = td.trip_date
LEFT JOIN {{ ref('us_federal_holidays') }} AS hol
    ON dd.trip_date = DATE(hol.holiday_date)