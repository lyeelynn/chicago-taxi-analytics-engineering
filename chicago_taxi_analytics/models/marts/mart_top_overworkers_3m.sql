WITH cte_date AS (
    {{ get_rolling_period(
        'session_start_timestamp',
        ref('int_taxi_work_sessions'),
        3
    ) }}
),

cte_agg AS (
    SELECT
        taxi_id,

        -- sessions
        COUNT(DISTINCT session_id) as total_sessions,
        SUM(session_duration_hours) as total_working_hours,
        MAX(session_duration_hours) as max_working_hours,
        SUM(total_trips) as total_trips,
        SUM(session_duration_hours)/COUNT(DISTINCT session_id) working_hours_per_session,
        SUM(total_trips)/COUNT(DISTINCT session_id) as trips_per_session,

        -- break hours
        SUM(break_before_session_hours)/COUNT(DISTINCT session_id) as avg_break_hours,
        MIN(break_before_session_hours) as min_break_hours,

        -- overworking indicators
        SUM(is_long_shift) as long_shift_count,
        SUM(is_long_shift)/COUNT(DISTINCT session_id) as long_shift_pct,
        SUM(is_short_break) as short_break_count,
        SUM(is_short_break)/COUNT(DISTINCT session_id) as short_break_pct

    FROM {{ ref('int_taxi_work_sessions') }}  
    WHERE DATE(session_start_timestamp) >= (
        SELECT period_start_date
        FROM cte_date
    )
    GROUP BY 1
),

cte_ranked AS (
    SELECT 
        *,
        PERCENT_RANK() OVER (ORDER BY total_working_hours) AS total_working_hours_percentile
    FROM cte_agg
),

cte_scored AS (
    SELECT 
        *,
        (
            (total_working_hours_percentile * 0.5) + -- 50% weightage: working hours
            (long_shift_pct * 0.3) + -- 30% weightage: long shifts
            (short_break_pct * 0.2) -- 20% weightage: short_breaks
        ) as overworker_score
    FROM cte_ranked
    WHERE long_shift_pct >= 0.3 -- at least 30% shifts are long hours
    AND short_break_count > 0 -- at least 1 short break
)

SELECT 
    (SELECT period_start_date FROM cte_date) as period_start_date,
    (SELECT period_end_date FROM cte_date) as period_end_date,
    scored.*,
    DENSE_RANK() OVER(ORDER BY overworker_score DESC) as overworker_rank
FROM cte_scored scored