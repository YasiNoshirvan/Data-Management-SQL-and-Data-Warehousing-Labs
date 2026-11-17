# Lab 08 - Craft Beer Data Warehouse

This lab models production and storage flows for a craft-beer company. The warehouse supports analysis by **factory, storage, beer type, hops, pack format, production date, and storage-arrival date**.

## Files

- `Craft_beer_DW_text.pdf` - original exercise
- `craft_beer_dw.sql` - star-schema DDL and both frequent queries
- `README.md` - design documentation

## Model highlights

The central `fact_beer_batch` records a produced batch and keeps two role-playing date keys:

- production date
- arrival date at storage

It stores additive measures for produced liters, produced bottles, and revenue.

Beer type and hop type are many-to-many because a beer may use several hops. This is represented through `bridge_beer_hop`.

## Queries implemented

### Query A
For six-bottle packs:

- monthly produced liters
- cumulative liters from the beginning of the year
- monthly share of annual factory production
- factory rank within each month

### Query B
For beer produced in 2018:

- average revenue per bottle
- average daily bottle count using arrival dates
- beer-type share of bottles within storage/month

## SQL dialect

PostgreSQL 14+.
