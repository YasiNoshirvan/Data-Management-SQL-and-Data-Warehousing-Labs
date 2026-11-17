/*
===============================================================================
Lab 10 - Music Event Tickets Data Warehouse
Dialect: PostgreSQL 14+
Source: Tickets_DW_text.pdf
===============================================================================
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    month_num           SMALLINT NOT NULL,
    month_of_year       VARCHAR(12) NOT NULL,
    two_month_period    SMALLINT NOT NULL,
    trimester           SMALLINT NOT NULL,
    four_month_period   SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    year_num            SMALLINT NOT NULL,
    is_working_day      BOOLEAN NOT NULL
);

CREATE TABLE dim_location (
    location_key    INTEGER PRIMARY KEY,
    venue_name      VARCHAR(180) NOT NULL,
    city            VARCHAR(120) NOT NULL,
    province        VARCHAR(120),
    region          VARCHAR(120),
    UNIQUE (venue_name, city)
);

CREATE TABLE dim_artist (
    artist_key      INTEGER PRIMARY KEY,
    artist_name     VARCHAR(180) NOT NULL UNIQUE,
    nationality     VARCHAR(100) NOT NULL
);

CREATE TABLE dim_tour (
    tour_key        INTEGER PRIMARY KEY,
    tour_name       VARCHAR(180) NOT NULL,
    artist_key      INTEGER NOT NULL REFERENCES dim_artist(artist_key),
    UNIQUE (tour_name, artist_key)
);

CREATE TABLE dim_genre (
    genre_key       INTEGER PRIMARY KEY,
    genre_name      VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bridge_tour_genre (
    tour_key        INTEGER NOT NULL REFERENCES dim_tour(tour_key),
    genre_key       INTEGER NOT NULL REFERENCES dim_genre(genre_key),
    PRIMARY KEY (tour_key, genre_key)
);

CREATE TABLE dim_purchase_mode (
    purchase_mode_key INTEGER PRIMARY KEY,
    purchase_mode     VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE dim_payment_method (
    payment_key     INTEGER PRIMARY KEY,
    payment_method  VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE fact_ticket_sales (
    ticket_fact_key     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tour_key            INTEGER NOT NULL REFERENCES dim_tour(tour_key),
    event_location_key  INTEGER NOT NULL REFERENCES dim_location(location_key),
    event_date_key      INTEGER NOT NULL REFERENCES dim_date(date_key),
    purchase_date_key   INTEGER NOT NULL REFERENCES dim_date(date_key),
    purchase_mode_key   INTEGER NOT NULL REFERENCES dim_purchase_mode(purchase_mode_key),
    payment_key         INTEGER NOT NULL REFERENCES dim_payment_method(payment_key),
    ticket_count        BIGINT NOT NULL CHECK (ticket_count >= 0),
    revenue             NUMERIC(18,2) NOT NULL CHECK (revenue >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Purchase mode/month: average daily revenue, cumulative YTD revenue, and
-- percentage of monthly tickets for the purchase mode.
WITH daily AS (
    SELECT
        f.purchase_mode_key,
        f.purchase_date_key,
        SUM(f.revenue) AS daily_revenue,
        SUM(f.ticket_count) AS daily_tickets
    FROM fact_ticket_sales AS f
    GROUP BY f.purchase_mode_key, f.purchase_date_key
), monthly AS (
    SELECT
        x.purchase_mode_key,
        p.purchase_mode,
        d.year_num,
        d.month_num,
        AVG(x.daily_revenue) AS avg_daily_revenue,
        SUM(x.daily_revenue) AS monthly_revenue,
        SUM(x.daily_tickets) AS monthly_tickets
    FROM daily AS x
    JOIN dim_date AS d ON d.date_key = x.purchase_date_key
    JOIN dim_purchase_mode AS p ON p.purchase_mode_key = x.purchase_mode_key
    GROUP BY x.purchase_mode_key, p.purchase_mode, d.year_num, d.month_num
)
SELECT
    purchase_mode,
    year_num,
    month_num,
    avg_daily_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY purchase_mode_key, year_num
        ORDER BY month_num
    ) AS cumulative_revenue_ytd,
    100.0 * monthly_tickets
      / NULLIF(SUM(monthly_tickets) OVER (
            PARTITION BY year_num, month_num
        ), 0) AS pct_monthly_tickets_for_mode
FROM monthly
ORDER BY year_num, month_num, purchase_mode;

-- Query B
-- Events held in 2017: artist nationality and city, average revenue per ticket,
-- and revenue share over the corresponding region.
WITH city_stats AS (
    SELECT
        a.nationality,
        l.region,
        l.city,
        SUM(f.revenue) AS revenue,
        SUM(f.ticket_count) AS tickets
    FROM fact_ticket_sales AS f
    JOIN dim_date AS e ON e.date_key = f.event_date_key
    JOIN dim_tour AS t ON t.tour_key = f.tour_key
    JOIN dim_artist AS a ON a.artist_key = t.artist_key
    JOIN dim_location AS l ON l.location_key = f.event_location_key
    WHERE e.year_num = 2017
    GROUP BY a.nationality, l.region, l.city
)
SELECT
    nationality,
    region,
    city,
    revenue / NULLIF(tickets, 0) AS avg_revenue_per_ticket,
    100.0 * revenue
      / NULLIF(SUM(revenue) OVER (PARTITION BY region), 0)
      AS pct_revenue_of_region
FROM city_stats
ORDER BY region, nationality, city;

-- =============================================================================
-- 3. INDEXES
-- =============================================================================

CREATE INDEX idx_ticket_purchase_date_mode
    ON fact_ticket_sales (purchase_date_key, purchase_mode_key);
CREATE INDEX idx_ticket_event_date_location
    ON fact_ticket_sales (event_date_key, event_location_key);
CREATE INDEX idx_ticket_tour ON fact_ticket_sales (tour_key);
CREATE INDEX idx_tour_genre_bridge ON bridge_tour_genre (tour_key, genre_key);
