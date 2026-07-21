SELECT DISTINCT
    TRIM(unique_key) AS unique_key,
    TRIM(taxi_id) AS taxi_id,
    trip_start_timestamp,
    trip_end_timestamp,
    trip_seconds,
    trip_miles,
    pickup_census_tract,
    dropoff_census_tract,
    pickup_community_area,
    dropoff_community_area,
    COALESCE(fare, 0) AS fare,
    COALESCE(tips, 0) AS tips,
    COALESCE(tolls, 0) AS tolls,
    COALESCE(extras, 0) AS extras,
    trip_total,
    TRIM(payment_type) AS payment_type,
    UPPER(
            REGEXP_REPLACE(TRIM(company),'[^a-zA-Z0-9 ]','')
        ) AS taxi_company,
    pickup_latitude,
    pickup_longitude,
    TRIM(pickup_location) AS pickup_location,
    dropoff_latitude,
    dropoff_longitude,
    TRIM(dropoff_location) AS dropoff_location
FROM {{ source('chicago_taxi', 'taxi_trips') }}
WHERE NULLIF(TRIM(unique_key),'') IS NOT NULL
AND NULLIF(TRIM(taxi_id),'') IS NOT NULL
AND trip_start_timestamp IS NOT NULL
AND trip_seconds > 30
AND (
    COALESCE(fare, 0) + 
    COALESCE(tips, 0) + 
    COALESCE(tolls, 0) + 
    COALESCE(extras, 0)
    ) > 0