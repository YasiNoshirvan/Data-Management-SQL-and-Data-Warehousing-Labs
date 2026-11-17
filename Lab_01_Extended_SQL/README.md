# Lab 01 - Extended SQL Analytical Queries

This lab focuses on **extended SQL / OLAP-style analytics** using aggregation and window functions.

## Files

- `ExtendedSQL_ENG.pdf` - original exercise sheet
- `extended_sql_solutions.sql` - complete SQL solutions
- `README.md` - lab documentation

## What the lab covers

The exercise contains two analytical scenarios:

1. **Seaside rentals** - calculate rental counts and income by object, then rank objects globally and by month.
2. **Sales analysis** - calculate province performance within regions and cumulative monthly sales.

The solution demonstrates:

- `GROUP BY` aggregation
- `LEFT JOIN` to preserve objects with no rentals
- `RANK()` window functions
- partitioned ranking
- cumulative `SUM() OVER (...)`
- year-aware monthly analysis to avoid mixing equal month numbers across years

## Source assumption

In Exercise 2 the PDF defines `Category(CategoryID, CatName)`, while the `Sales` relation contains an attribute named `ItemID`. Because the exercise is clearly category-oriented, the solution treats `Sales.ItemID` as the category foreign key when a category join is needed. The requested Exercise 2 queries themselves do not require that join.

## SQL dialect

The queries use standard analytical SQL and are written in a PostgreSQL-compatible style. They can be adapted easily to other DBMSs that support window functions.

## Learning outcome

The lab shows how SQL can move beyond simple aggregation and express common Business Intelligence operations such as ranking, within-group comparisons, and running totals directly in the database layer.
