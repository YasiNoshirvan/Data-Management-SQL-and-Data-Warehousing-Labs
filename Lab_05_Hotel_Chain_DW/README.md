# Lab 05 - Hotel Chain Data Warehouse

This lab models a global hotel chain that needs to analyze **room status and income** by time, geography, hotel category, and room features.

## Files

- `05-DW-project-hotel-text.pdf` - original assignment
- `hotel_chain_dw.sql` - warehouse schema, frequent queries, materialized view, and indexes
- `README.md` - design documentation

## Model

The fact table is `fact_room_daily`, at one row per **room x day**. This grain makes room-state percentages straightforward and avoids ambiguity when combining room status with daily income.

Dimensions cover:

- date and public-holiday flag
- hotel and category
- geographic location
- room
- room features

Room features are many-to-many, so they are represented with a bridge table. Queries requiring more than one feature use `EXISTS` predicates to prevent duplicate fact rows.

## Analytics implemented

The SQL includes all frequent analyses listed in the assignment:

- monthly reserved/free/unavailable room percentages by state
- state ranking by reserved-room share
- monthly and cumulative income for 4-star hotels
- public-holiday income
- income from rooms with both satellite TV and whirlpool bath

## Performance strategy

The assignment contains only two years of data and about 500 hotels, so a compact monthly materialized view is sufficient for the repeated state/month status and income analyses. Supporting indexes target the main dimension joins and room-feature filters.

## SQL dialect

PostgreSQL 14+.
