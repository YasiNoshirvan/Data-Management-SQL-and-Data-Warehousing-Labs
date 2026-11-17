[README.md](https://github.com/user-attachments/files/34973308/README.md)
# Lab 02 - Extended SQL Exercise

This lab practices analytical SQL on a small sales schema containing customers, item categories, agents, time, and sales facts.

## Files

- `ExtendedSQL-Exercise-1-text-2021.pdf` - original exercise sheet
- `extended_sql_exercise_1.sql` - complete query solutions
- `README.md` - lab documentation

## Queries implemented

1. **Category analysis** - total revenue, number of sold items, and two independent ranks.
2. **Province analysis** - total revenue and rank within the corresponding region.
3. **Province-month analysis** - monthly revenue and rank across provinces for each month.
4. **Region-month analysis** - monthly revenue and cumulative revenue from the beginning of the year.

## Techniques used

- fact-to-dimension joins
- grouped aggregation
- `RANK()` with and without `PARTITION BY`
- cumulative windows using `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`
- deterministic ordering for analytical output

The original questions refer to months without always displaying the year. The implementation retains `Year` in monthly queries so that the same month number from different years is never combined accidentally.

## SQL dialect

PostgreSQL-compatible analytical SQL. The queries are also portable to most modern relational database systems with minor syntax changes.
