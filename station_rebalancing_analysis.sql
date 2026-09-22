-- Citi Bike Station Health & Rebalancing Analytics
-- Author: Serena Zhang
-- Purpose: Reproducible DuckDB workflow for August 2026 Citi Bike trip QA,
--          station entity resolution, station-hour aggregation, and
--          rebalancing-priority feature construction.
--
-- IMPORTANT:
-- 1) Replace the file path in the raw_trips view with your local/Drive path.
-- 2) This script intentionally treats long trips as QA flags rather than
--    automatically deleting them.
-- 3) Priority thresholds/weights are analytical decision rules, not claims
--    of confirmed stockouts or full docks.

-- ============================================================
-- 0. LOAD RAW TRIPS
-- ============================================================

CREATE OR REPLACE VIEW raw_trips AS
SELECT *
FROM read_csv_auto(
    '/path/to/202608-citibike-tripdata/*.csv',
    union_by_name = true,
    header = true
);

-- Confirm total trip count.
SELECT COUNT(*) AS trip_count
FROM raw_trips;

-- Expected project total:
-- 5,246,236 trips


-- ============================================================
-- 1. TRIP-DURATION QUALITY AUDIT
-- ============================================================

CREATE OR REPLACE VIEW trips_with_duration AS
SELECT
    *,
    date_diff(
        'second',
        CAST(started_at AS TIMESTAMP),
        CAST(ended_at AS TIMESTAMP)
    ) / 60.0 AS duration_min
FROM raw_trips;

SELECT
    median(duration_min) AS median_duration_min,
    quantile_cont(duration_min, 0.99) AS p99_duration_min,
    SUM(CASE WHEN duration_min > 240 THEN 1 ELSE 0 END) AS trips_over_4h
FROM trips_with_duration
WHERE duration_min IS NOT NULL;

-- Project QA results:
-- median = 9.78 min
-- p99    = 65.83 min
-- >4h    = 4,286 trips


-- ============================================================
-- 2. CANONICAL STATION-ID NORMALIZATION
-- ============================================================

-- Normalize IDs while preserving legitimate alphanumeric IDs.
-- Examples:
--   5343.1   -> 5343.10
--   5343.10  -> 5343.10
--   5303.06_ -> 5303.06
--   SYS016   -> SYS016
--
-- Numeric-looking IDs are standardized to two decimal places.
-- Trailing underscores are removed first.

CREATE OR REPLACE MACRO canonical_station_id(x) AS (
    CASE
        WHEN x IS NULL OR trim(CAST(x AS VARCHAR)) = '' THEN NULL
        WHEN regexp_matches(
            regexp_replace(trim(CAST(x AS VARCHAR)), '_+$', ''),
            '^[0-9]+(\.[0-9]+)?$'
        )
        THEN printf(
            '%.2f',
            CAST(
                regexp_replace(trim(CAST(x AS VARCHAR)), '_+$', '')
                AS DOUBLE
            )
        )
        ELSE regexp_replace(trim(CAST(x AS VARCHAR)), '_+$', '')
    END
);

CREATE OR REPLACE VIEW trips_normalized AS
SELECT
    ride_id,
    rideable_type,
    CAST(started_at AS TIMESTAMP) AS started_at,
    CAST(ended_at AS TIMESTAMP) AS ended_at,

    start_station_name,
    canonical_station_id(start_station_id) AS start_station_key,
    start_lat,
    start_lng,

    end_station_name,
    canonical_station_id(end_station_id) AS end_station_key,
    end_lat,
    end_lng,

    member_casual,
    duration_min
FROM trips_with_duration;


-- ============================================================
-- 3. STATION-IDENTITY QA
-- ============================================================

-- Inspect raw IDs that collapse to the same canonical key.
SELECT
    canonical_station_id(start_station_id) AS canonical_key,
    COUNT(DISTINCT CAST(start_station_id AS VARCHAR)) AS raw_id_count,
    list(DISTINCT CAST(start_station_id AS VARCHAR)) AS raw_ids
FROM raw_trips
WHERE start_station_id IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT CAST(start_station_id AS VARCHAR)) > 1
ORDER BY raw_id_count DESC, canonical_key;

-- Example project finding:
-- 5343.1 and 5343.10 referred to the same physical station.
--
-- After canonicalization:
-- arrivals   = 7,605
-- departures = 7,497
--
-- The apparent one-way imbalance largely disappeared.


-- ============================================================
-- 4. BUILD DEPARTURE / ARRIVAL EVENTS
-- ============================================================

CREATE OR REPLACE VIEW departures AS
SELECT
    start_station_key AS station_key,
    start_station_name AS station_name,
    CAST(started_at AS DATE) AS service_date,
    EXTRACT('hour' FROM started_at)::INTEGER AS hour,
    start_lat AS latitude,
    start_lng AS longitude,
    COUNT(*) AS departures
FROM trips_normalized
WHERE start_station_key IS NOT NULL
GROUP BY ALL;

CREATE OR REPLACE VIEW arrivals AS
SELECT
    end_station_key AS station_key,
    end_station_name AS station_name,
    CAST(ended_at AS DATE) AS service_date,
    EXTRACT('hour' FROM ended_at)::INTEGER AS hour,
    end_lat AS latitude,
    end_lng AS longitude,
    COUNT(*) AS arrivals
FROM trips_normalized
WHERE end_station_key IS NOT NULL
GROUP BY ALL;


-- ============================================================
-- 5. STATION-DAY-HOUR FLOW TABLE
-- ============================================================

CREATE OR REPLACE VIEW station_day_hour_observed AS
SELECT
    COALESCE(d.station_key, a.station_key) AS station_key,
    COALESCE(d.station_name, a.station_name) AS station_name,
    COALESCE(d.service_date, a.service_date) AS service_date,
    COALESCE(d.hour, a.hour) AS hour,

    COALESCE(d.latitude, a.latitude) AS latitude,
    COALESCE(d.longitude, a.longitude) AS longitude,

    COALESCE(d.departures, 0) AS departures,
    COALESCE(a.arrivals, 0) AS arrivals
FROM departures d
FULL OUTER JOIN arrivals a
    ON d.station_key = a.station_key
   AND d.service_date = a.service_date
   AND d.hour = a.hour;


-- ============================================================
-- 6. COMPLETE STATION × ACTIVE-DATE × HOUR GRID
-- ============================================================

-- This prevents persistence from being overstated by missing
-- zero-activity station-hours.

CREATE OR REPLACE VIEW station_dates AS
SELECT DISTINCT
    station_key,
    service_date
FROM station_day_hour_observed;

CREATE OR REPLACE VIEW hours AS
SELECT range AS hour
FROM range(24);

CREATE OR REPLACE VIEW station_day_hour_complete AS
SELECT
    sd.station_key,
    COALESCE(obs.station_name, meta.station_name) AS station_name,
    sd.service_date,
    h.hour,

    COALESCE(obs.latitude, meta.latitude) AS latitude,
    COALESCE(obs.longitude, meta.longitude) AS longitude,

    COALESCE(obs.departures, 0) AS departures,
    COALESCE(obs.arrivals, 0) AS arrivals,

    COALESCE(obs.arrivals, 0) - COALESCE(obs.departures, 0) AS net_flow,
    COALESCE(obs.arrivals, 0) + COALESCE(obs.departures, 0) AS total_activity
FROM station_dates sd
CROSS JOIN hours h
LEFT JOIN station_day_hour_observed obs
    ON sd.station_key = obs.station_key
   AND sd.service_date = obs.service_date
   AND h.hour = obs.hour
LEFT JOIN (
    SELECT
        station_key,
        any_value(station_name) AS station_name,
        median(latitude) AS latitude,
        median(longitude) AS longitude
    FROM station_day_hour_observed
    GROUP BY station_key
) meta
    ON sd.station_key = meta.station_key;


-- ============================================================
-- 7. DAY-LEVEL PRESSURE FLAGS
-- ============================================================

-- imbalance_rate ranges from -1 to +1:
--   negative -> departures dominate -> bike-availability pressure
--   positive -> arrivals dominate   -> dock-availability pressure
--
-- Thresholds ±0.20 are analytical rules used in this project.

CREATE OR REPLACE VIEW station_day_hour_flags AS
SELECT
    *,
    CASE
        WHEN total_activity = 0 THEN 0.0
        ELSE net_flow * 1.0 / total_activity
    END AS imbalance_rate,

    CASE
        WHEN total_activity > 0
         AND (net_flow * 1.0 / total_activity) <= -0.20
        THEN 1 ELSE 0
    END AS bike_pressure_flag,

    CASE
        WHEN total_activity > 0
         AND (net_flow * 1.0 / total_activity) >= 0.20
        THEN 1 ELSE 0
    END AS dock_pressure_flag
FROM station_day_hour_complete;


-- ============================================================
-- 8. STATION-HOUR KPI AGGREGATION
-- ============================================================

CREATE OR REPLACE VIEW station_hour_kpis AS
SELECT
    station_key,
    any_value(station_name) AS station_name,
    hour,
    median(latitude) AS latitude,
    median(longitude) AS longitude,

    AVG(arrivals) AS avg_arrivals,
    AVG(departures) AS avg_departures,
    AVG(net_flow) AS avg_net_flow,
    AVG(total_activity) AS avg_total_activity,

    AVG(abs(imbalance_rate)) AS imbalance_severity,

    AVG(bike_pressure_flag) AS bike_pressure_persistence,
    AVG(dock_pressure_flag) AS dock_pressure_persistence,

    COUNT(*) AS active_days
FROM station_day_hour_flags
GROUP BY station_key, hour;


-- ============================================================
-- 9. ASSIGN PRESSURE TYPE
-- ============================================================

CREATE OR REPLACE VIEW station_hour_pressure AS
SELECT
    *,
    CASE
        WHEN avg_net_flow < 0
         AND bike_pressure_persistence >= dock_pressure_persistence
        THEN 'Bike Availability Pressure'

        WHEN avg_net_flow > 0
         AND dock_pressure_persistence > bike_pressure_persistence
        THEN 'Dock Availability Pressure'

        ELSE 'Not Prioritized'
    END AS priority_type,

    GREATEST(
        bike_pressure_persistence,
        dock_pressure_persistence
    ) AS priority_persistence
FROM station_hour_kpis;


-- ============================================================
-- 10. NORMALIZE KPI COMPONENTS
-- ============================================================

-- Percentile ranks put Severity, Activity, and Persistence
-- on comparable 0-1 scales.

CREATE OR REPLACE VIEW station_hour_scored AS
SELECT
    *,

    percent_rank() OVER (
        ORDER BY imbalance_severity
    ) AS severity_score,

    percent_rank() OVER (
        ORDER BY avg_total_activity
    ) AS activity_score,

    percent_rank() OVER (
        ORDER BY priority_persistence
    ) AS persistence_score

FROM station_hour_pressure;


-- ============================================================
-- 11. COMPOSITE PRIORITY SCORE
-- ============================================================

-- Project weighting:
-- 40% Severity
-- 30% Activity
-- 30% Persistence

CREATE OR REPLACE VIEW station_hour_priorities AS
SELECT
    station_key,
    station_name,
    hour,
    latitude,
    longitude,

    avg_arrivals,
    avg_departures,
    avg_net_flow,
    avg_total_activity,

    imbalance_severity,
    bike_pressure_persistence,
    dock_pressure_persistence,
    priority_persistence,

    priority_type,

    ROUND(
        100 * (
            0.40 * severity_score
          + 0.30 * activity_score
          + 0.30 * persistence_score
        ),
        1
    ) AS priority_score

FROM station_hour_scored;


-- ============================================================
-- 12. FINAL OUTPUT FOR TABLEAU
-- ============================================================

SELECT *
FROM station_hour_priorities
ORDER BY hour, priority_score DESC;


-- Optional export:
--
-- COPY (
--     SELECT *
--     FROM station_hour_priorities
-- )
-- TO 'station_hour_priorities.csv'
-- (HEADER, DELIMITER ',');


-- ============================================================
-- 13. EXAMPLE QA / BUSINESS CHECKS
-- ============================================================

-- Top 10 priorities at 8 AM.
SELECT
    station_name,
    priority_type,
    priority_score,
    avg_arrivals,
    avg_departures,
    avg_net_flow,
    avg_total_activity,
    imbalance_severity,
    priority_persistence
FROM station_hour_priorities
WHERE hour = 8
  AND priority_type <> 'Not Prioritized'
ORDER BY priority_score DESC
LIMIT 10;

-- Number of prioritized stations by hour and pressure type.
SELECT
    hour,
    priority_type,
    COUNT(DISTINCT station_key) AS prioritized_stations
FROM station_hour_priorities
WHERE priority_type <> 'Not Prioritized'
GROUP BY hour, priority_type
ORDER BY hour, priority_type;
