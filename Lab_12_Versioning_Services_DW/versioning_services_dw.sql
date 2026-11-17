/*
===============================================================================
Lab 12 - Code Versioning Services Data Warehouse
Dialect: PostgreSQL 14+
Source: Versioning_services_DW_text.pdf
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
    year_num            SMALLINT NOT NULL
);

CREATE TABLE dim_repository (
    repository_key  INTEGER PRIMARY KEY,
    repository_name VARCHAR(180) NOT NULL,
    company_name    VARCHAR(180) NOT NULL,
    visibility      VARCHAR(20) NOT NULL CHECK (visibility IN ('PUBLIC','PRIVATE')),
    software_category VARCHAR(100) NOT NULL,
    UNIQUE (repository_name, company_name)
);

CREATE TABLE dim_language (
    language_key    INTEGER PRIMARY KEY,
    language_name   VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bridge_repository_language (
    repository_key  INTEGER NOT NULL REFERENCES dim_repository(repository_key),
    language_key    INTEGER NOT NULL REFERENCES dim_language(language_key),
    PRIMARY KEY (repository_key, language_key)
);

CREATE TABLE dim_branch (
    branch_key          INTEGER PRIMARY KEY,
    branch_name         VARCHAR(180) NOT NULL,
    repository_key      INTEGER NOT NULL REFERENCES dim_repository(repository_key),
    creation_date_key   INTEGER NOT NULL REFERENCES dim_date(date_key),
    UNIQUE (repository_key, branch_name)
);

CREATE TABLE dim_work_team (
    team_key        INTEGER PRIMARY KEY,
    team_name       VARCHAR(160) NOT NULL UNIQUE
);

CREATE TABLE dim_developer (
    developer_key   INTEGER PRIMARY KEY,
    developer_id    VARCHAR(80) NOT NULL UNIQUE,
    developer_name  VARCHAR(180),
    developer_role  VARCHAR(100) NOT NULL,
    team_key        INTEGER NOT NULL REFERENCES dim_work_team(team_key)
);

CREATE TABLE fact_commit (
    commit_key      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_key      INTEGER NOT NULL REFERENCES dim_branch(branch_key),
    developer_key   INTEGER NOT NULL REFERENCES dim_developer(developer_key),
    date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    commit_hour     SMALLINT NOT NULL CHECK (commit_hour BETWEEN 0 AND 23),
    commit_count    SMALLINT NOT NULL DEFAULT 1 CHECK (commit_count > 0),
    additions       BIGINT NOT NULL CHECK (additions >= 0),
    deletions       BIGINT NOT NULL CHECK (deletions >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Private repositories: month/repository average commits per day, average
-- commits per branch, and cumulative monthly commits from the start of the year.
WITH monthly AS (
    SELECT
        r.repository_key,
        r.repository_name,
        d.year_num,
        d.month_num,
        SUM(f.commit_count) AS monthly_commits,
        COUNT(DISTINCT d.full_date) AS active_days,
        COUNT(DISTINCT f.branch_key) AS active_branches
    FROM fact_commit AS f
    JOIN dim_branch AS b ON b.branch_key = f.branch_key
    JOIN dim_repository AS r ON r.repository_key = b.repository_key
    JOIN dim_date AS d ON d.date_key = f.date_key
    WHERE r.visibility = 'PRIVATE'
    GROUP BY r.repository_key, r.repository_name, d.year_num, d.month_num
)
SELECT
    repository_name,
    year_num,
    month_num,
    monthly_commits::NUMERIC / NULLIF(active_days, 0) AS avg_commits_per_day,
    monthly_commits::NUMERIC / NULLIF(active_branches, 0) AS avg_commits_per_branch,
    SUM(monthly_commits) OVER (
        PARTITION BY repository_key, year_num
        ORDER BY month_num
    ) AS cumulative_commits_ytd
FROM monthly
ORDER BY repository_name, year_num, month_num;

-- Query B
-- Repositories including Scala: branch x work team additions/deletions ratio,
-- share of repository additions, and work-team rank within each branch.
WITH branch_team AS (
    SELECT
        r.repository_key,
        r.repository_name,
        b.branch_key,
        b.branch_name,
        t.team_key,
        t.team_name,
        SUM(f.additions) AS additions,
        SUM(f.deletions) AS deletions
    FROM fact_commit AS f
    JOIN dim_branch AS b ON b.branch_key = f.branch_key
    JOIN dim_repository AS r ON r.repository_key = b.repository_key
    JOIN dim_developer AS dev ON dev.developer_key = f.developer_key
    JOIN dim_work_team AS t ON t.team_key = dev.team_key
    WHERE EXISTS (
        SELECT 1
        FROM bridge_repository_language brl
        JOIN dim_language l ON l.language_key = brl.language_key
        WHERE brl.repository_key = r.repository_key
          AND l.language_name = 'Scala'
    )
    GROUP BY r.repository_key, r.repository_name,
             b.branch_key, b.branch_name, t.team_key, t.team_name
), metrics AS (
    SELECT
        *,
        additions::NUMERIC / NULLIF(deletions, 0) AS add_delete_ratio,
        100.0 * additions
          / NULLIF(SUM(additions) OVER (PARTITION BY repository_key), 0)
          AS pct_additions_of_repository
    FROM branch_team
)
SELECT
    repository_name,
    branch_name,
    team_name,
    add_delete_ratio,
    pct_additions_of_repository,
    RANK() OVER (
        PARTITION BY branch_key
        ORDER BY add_delete_ratio DESC NULLS LAST
    ) AS team_rank_within_branch
FROM metrics
ORDER BY repository_name, branch_name, team_rank_within_branch, team_name;

-- =============================================================================
-- 3. INDEXES
-- =============================================================================

CREATE INDEX idx_commit_branch_date
    ON fact_commit (branch_key, date_key);
CREATE INDEX idx_commit_developer
    ON fact_commit (developer_key);
CREATE INDEX idx_branch_repository
    ON dim_branch (repository_key);
CREATE INDEX idx_repository_language_bridge
    ON bridge_repository_language (repository_key, language_key);
