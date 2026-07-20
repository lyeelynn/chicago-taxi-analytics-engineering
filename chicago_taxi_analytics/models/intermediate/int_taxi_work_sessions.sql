WITH base AS (
    SELECT
        taxi_id,
        trip_start_timestamp,
        trip_end_timestamp,
        LAG(trip_end_timestamp) OVER (
            PARTITION BY taxi_id
            ORDER BY trip_start_timestamp
        ) AS previous_trip_end_timestamp
    -- for local test
    FROM 'stg_taxi_trips.parquet'
    -- for dbt prod
    -- FROM {{ ref('stg_taxi_trips') }}
),

trip_gaps AS (
    SELECT
        *,
        DATE_DIFF('minute', previous_trip_end_timestamp, trip_start_timestamp) / 60.0 AS break_hours
    FROM base
),

flagged AS (
    SELECT
        *,
        CASE
            WHEN previous_trip_end_timestamp IS NULL THEN true
            WHEN break_hours > 3 THEN true
            ELSE false
        END AS is_new_session
    FROM trip_gaps
),

sessioned AS (
    SELECT
        *,
        SUM(
            CASE 
                WHEN is_new_session 
                THEN 1 ELSE 0 
            END) 
            OVER (
            PARTITION BY taxi_id
            ORDER BY trip_start_timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_id,
        -- only the first session of the new session has pre_session_break_hours
        CASE 
            WHEN is_new_session 
            THEN break_hours 
        END AS pre_session_break_hours
    FROM flagged
),

session_summary AS (
    SELECT
        taxi_id,
        CAST(session_id AS INTEGER) AS session_id,
        MIN(trip_start_timestamp) AS session_start_timestamp,
        MAX(trip_end_timestamp) AS session_end_timestamp,
        COUNT(*) AS total_trips,
        DATE_DIFF('minute', MIN(trip_start_timestamp), MAX(trip_end_timestamp)) / 60.0 AS session_duration_hours,
        -- exactly one non-null row per session
        MAX(pre_session_break_hours) AS break_before_session_hours
    FROM sessioned
    GROUP BY 1, 2
)

SELECT
    taxi_id,
    session_id,
    session_start_timestamp,
    session_end_timestamp,
    total_trips,
    session_duration_hours,
    break_before_session_hours,
    CASE
        WHEN break_before_session_hours < 8 THEN 1
        ELSE 0
    END is_short_break,
    CASE 
        WHEN COALESCE(session_duration_hours, 0) > 9 THEN 1
        ELSE 0
    END AS is_long_shift
FROM session_summary