/*
===============================================================================
Lab 01 - Extended SQL Analytical Queries
Dialect: PostgreSQL / ANSI SQL window-function style
Source: ExtendedSQL_ENG.pdf
===============================================================================

The PDF provides logical relations rather than physical CREATE TABLE statements.
The queries below solve all requested exercises using aggregation and window
functions.

Source note for Exercise 2:
The PDF defines Category(CategoryID, CatName) but Sales uses ItemID. Because the
questions analyze sales by category, this solution assumes Sales.ItemID references
Category.CategoryID.
*/

-- -----------------------------------------------------------------------------
-- Exercise 1A
-- For each object: total rentals, total income, and both ranks.
-- -----------------------------------------------------------------------------
WITH object_totals AS (
    SELECT
        o.ObjectID,
        o.ObjectType,
        COUNT(r.ObjectID) AS total_rentals,
        COALESCE(SUM(r.Price), 0) AS total_income
    FROM OBJECTS AS o
    LEFT JOIN RENTALS AS r
        ON r.ObjectID = o.ObjectID
    GROUP BY o.ObjectID, o.ObjectType
)
SELECT
    ObjectID,
    ObjectType,
    total_rentals,
    total_income,
    RANK() OVER (ORDER BY total_rentals DESC) AS rental_rank,
    RANK() OVER (ORDER BY total_income DESC) AS income_rank
FROM object_totals
ORDER BY ObjectID;

-- -----------------------------------------------------------------------------
-- Exercise 1B
-- For each object and month: monthly income and rank within the month.
-- Year is included to avoid mixing the same month across different years.
-- -----------------------------------------------------------------------------
WITH object_monthly_income AS (
    SELECT
        o.ObjectID,
        o.ObjectType,
        t.Year,
        t.Month,
        SUM(r.Price) AS monthly_income
    FROM RENTALS AS r
    JOIN OBJECTS AS o
        ON o.ObjectID = r.ObjectID
    JOIN TIME AS t
        ON t.TimeID = r.TimeID
    GROUP BY o.ObjectID, o.ObjectType, t.Year, t.Month
)
SELECT
    ObjectID,
    ObjectType,
    Year,
    Month,
    monthly_income,
    RANK() OVER (
        PARTITION BY Year, Month
        ORDER BY monthly_income DESC
    ) AS monthly_income_rank
FROM object_monthly_income
ORDER BY Year, Month, monthly_income_rank, ObjectID;

-- -----------------------------------------------------------------------------
-- Exercise 2A
-- Total sales by province and rank of each province within its region.
-- -----------------------------------------------------------------------------
WITH province_sales AS (
    SELECT
        c.Province,
        c.Region,
        SUM(s.TotAmount) AS total_sale_amount
    FROM Sales AS s
    JOIN Customer AS c
        ON c.CustomerID = s.CustomerID
    GROUP BY c.Province, c.Region
)
SELECT
    Province,
    Region,
    total_sale_amount,
    RANK() OVER (
        PARTITION BY Region
        ORDER BY total_sale_amount DESC
    ) AS province_rank_in_region
FROM province_sales
ORDER BY Region, province_rank_in_region, Province;

-- -----------------------------------------------------------------------------
-- Exercise 2B
-- Monthly sales by region and cumulative sales from the beginning of the year.
-- -----------------------------------------------------------------------------
WITH region_monthly_sales AS (
    SELECT
        c.Region,
        t.Year,
        t.Month,
        SUM(s.TotAmount) AS monthly_sale_amount
    FROM Sales AS s
    JOIN Customer AS c
        ON c.CustomerID = s.CustomerID
    JOIN TIME AS t
        ON t.TimeID = s.TimeID
    GROUP BY c.Region, t.Year, t.Month
)
SELECT
    Region,
    Year,
    Month,
    monthly_sale_amount,
    SUM(monthly_sale_amount) OVER (
        PARTITION BY Region, Year
        ORDER BY Month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sale_amount
FROM region_monthly_sales
ORDER BY Region, Year, Month;
