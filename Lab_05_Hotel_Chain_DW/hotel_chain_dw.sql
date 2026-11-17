/*
===============================================================================
Lab 05 - Hotel Chain Data Warehouse
Dialect: PostgreSQL 14+
Source: 05-DW-project-hotel-text.pdf
===============================================================================

Grain: FACT_ROOM_DAILY stores one row per room per day. This supports room-state
percentages and daily/monthly/yearly income without duplicating room counts.
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    day_of_week     VARCHAR(12) NOT NULL,
    month_num       SMALLINT NOT NULL,
    month_name      VARCHAR(12) NOT NULL,
    year_num        SMALLINT NOT NULL,
    is_public_holiday BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE dim_location (
    location_key    INTEGER PRIMARY KEY,
    city            VARCHAR(120) NOT NULL,
    province        VARCHAR(120),
    region          VARCHAR(120),
    state           VARCHAR(120) NOT NULL,
    UNIQUE (city, province, region, state)
);

CREATE TABLE dim_hotel (
    hotel_key       INTEGER PRIMARY KEY,
    hotel_id        VARCHAR(60) NOT NULL UNIQUE,
    hotel_name      VARCHAR(180) NOT NULL,
    category_stars  SMALLINT NOT NULL CHECK (category_stars BETWEEN 1 AND 5),
    location_key    INTEGER NOT NULL REFERENCES dim_location(location_key)
);

CREATE TABLE dim_room (
    room_key        INTEGER PRIMARY KEY,
    hotel_key       INTEGER NOT NULL REFERENCES dim_hotel(hotel_key),
    room_number     VARCHAR(30) NOT NULL,
    beds            SMALLINT NOT NULL CHECK (beds > 0),
    UNIQUE (hotel_key, room_number)
);

CREATE TABLE dim_room_feature (
    feature_key     INTEGER PRIMARY KEY,
    feature_name    VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE bridge_room_feature (
    room_key        INTEGER NOT NULL REFERENCES dim_room(room_key),
    feature_key     INTEGER NOT NULL REFERENCES dim_room_feature(feature_key),
    PRIMARY KEY (room_key, feature_key)
);

CREATE TABLE fact_room_daily (
    date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    room_key        INTEGER NOT NULL REFERENCES dim_room(room_key),
    room_status     VARCHAR(20) NOT NULL
                    CHECK (room_status IN ('RESERVED','FREE','UNAVAILABLE')),
    daily_income    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (daily_income >= 0),
    PRIMARY KEY (date_key, room_key)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- 2005: portion of rooms reserved/free/unavailable by state and month.
SELECT
    l.state,
    d.month_num,
    100.0 * COUNT(*) FILTER (WHERE f.room_status = 'RESERVED') / NULLIF(COUNT(*), 0)
        AS reserved_pct,
    100.0 * COUNT(*) FILTER (WHERE f.room_status = 'FREE') / NULLIF(COUNT(*), 0)
        AS free_pct,
    100.0 * COUNT(*) FILTER (WHERE f.room_status = 'UNAVAILABLE') / NULLIF(COUNT(*), 0)
        AS unavailable_pct
FROM fact_room_daily AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_room AS r ON r.room_key = f.room_key
JOIN dim_hotel AS h ON h.hotel_key = r.hotel_key
JOIN dim_location AS l ON l.location_key = h.location_key
WHERE d.year_num = 2005
GROUP BY l.state, d.month_num
ORDER BY l.state, d.month_num;

-- Query B
-- 2005: reserved-room share by state and descending rank.
WITH state_stats AS (
    SELECT
        l.state,
        COUNT(*) FILTER (WHERE f.room_status = 'RESERVED') AS reserved_room_days,
        COUNT(*) AS total_room_days
    FROM fact_room_daily AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_room AS r ON r.room_key = f.room_key
    JOIN dim_hotel AS h ON h.hotel_key = r.hotel_key
    JOIN dim_location AS l ON l.location_key = h.location_key
    WHERE d.year_num = 2005
    GROUP BY l.state
), state_ratio AS (
    SELECT
        state,
        100.0 * reserved_room_days / NULLIF(total_room_days, 0) AS reserved_pct
    FROM state_stats
)
SELECT
    state,
    reserved_pct,
    RANK() OVER (ORDER BY reserved_pct DESC) AS reserved_room_rank
FROM state_ratio
ORDER BY reserved_room_rank, state;

-- Query C
-- 2005: monthly and cumulative income for 4-star hotels by state.
WITH monthly AS (
    SELECT
        l.state,
        d.month_num,
        SUM(f.daily_income) AS monthly_income
    FROM fact_room_daily AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_room AS r ON r.room_key = f.room_key
    JOIN dim_hotel AS h ON h.hotel_key = r.hotel_key
    JOIN dim_location AS l ON l.location_key = h.location_key
    WHERE d.year_num = 2005
      AND h.category_stars = 4
    GROUP BY l.state, d.month_num
)
SELECT
    state,
    month_num,
    monthly_income,
    SUM(monthly_income) OVER (
        PARTITION BY state
        ORDER BY month_num
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_income
FROM monthly
ORDER BY state, month_num;

-- Query D
-- Total public-holiday income by state and year.
SELECT
    l.state,
    d.year_num,
    SUM(f.daily_income) AS holiday_income
FROM fact_room_daily AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_room AS r ON r.room_key = f.room_key
JOIN dim_hotel AS h ON h.hotel_key = r.hotel_key
JOIN dim_location AS l ON l.location_key = h.location_key
WHERE d.is_public_holiday = TRUE
GROUP BY l.state, d.year_num
ORDER BY l.state, d.year_num;

-- Query E
-- 2005: hotel income from rooms having both Satellite TV and Whirlpool Bath.
SELECT
    h.hotel_id,
    h.hotel_name,
    SUM(f.daily_income) AS qualifying_room_income
FROM fact_room_daily AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_room AS r ON r.room_key = f.room_key
JOIN dim_hotel AS h ON h.hotel_key = r.hotel_key
WHERE d.year_num = 2005
  AND EXISTS (
      SELECT 1
      FROM bridge_room_feature b
      JOIN dim_room_feature x ON x.feature_key = b.feature_key
      WHERE b.room_key = r.room_key
        AND x.feature_name = 'Satellite TV'
  )
  AND EXISTS (
      SELECT 1
      FROM bridge_room_feature b
      JOIN dim_room_feature x ON x.feature_key = b.feature_key
      WHERE b.room_key = r.room_key
        AND x.feature_name = 'Whirlpool Bath'
  )
GROUP BY h.hotel_id, h.hotel_name
ORDER BY h.hotel_id;

-- =============================================================================
-- 3. PERFORMANCE STRUCTURES
-- =============================================================================

CREATE MATERIALIZED VIEW mv_hotel_month_status_income AS
SELECT
    r.hotel_key,
    d.year_num,
    d.month_num,
    COUNT(*) FILTER (WHERE f.room_status = 'RESERVED') AS reserved_room_days,
    COUNT(*) FILTER (WHERE f.room_status = 'FREE') AS free_room_days,
    COUNT(*) FILTER (WHERE f.room_status = 'UNAVAILABLE') AS unavailable_room_days,
    SUM(f.daily_income) AS total_income
FROM fact_room_daily AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_room AS r ON r.room_key = f.room_key
GROUP BY r.hotel_key, d.year_num, d.month_num;

CREATE UNIQUE INDEX idx_mv_hotel_month
    ON mv_hotel_month_status_income (hotel_key, year_num, month_num);
CREATE INDEX idx_room_hotel ON dim_room (hotel_key);
CREATE INDEX idx_hotel_location_category ON dim_hotel (location_key, category_stars);
CREATE INDEX idx_room_feature_room ON bridge_room_feature (room_key, feature_key);
CREATE INDEX idx_room_daily_date_status ON fact_room_daily (date_key, room_status);
