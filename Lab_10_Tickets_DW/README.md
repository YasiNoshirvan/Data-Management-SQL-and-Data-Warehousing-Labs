# Lab 10 - Music Event Tickets Data Warehouse

This lab designs a warehouse for a ticketing company that analyzes **revenue and ticket volumes** using both purchase-time and event-time perspectives.

## Files

- `Tickets_DW_text.pdf` - original assignment
- `tickets_dw.sql` - dimensional schema and both analytical queries
- `README.md` - design explanation

## Design

`fact_ticket_sales` keeps two role-playing date foreign keys:

- purchase date
- event date

This is necessary because the questions analyze different timelines independently.

Tour and musical genre are many-to-many, so `bridge_tour_genre` allows a tour to be associated with several genres without repeating ticket measures.

## Queries

### Query A
By purchase mode and purchase month:

- average daily revenue
- cumulative revenue from the start of the year
- percentage of monthly ticket volume attributable to each purchase mode

### Query B
For events held in 2017:

- average revenue per ticket by artist nationality and city
- revenue percentage relative to the corresponding region

## SQL dialect

PostgreSQL 14+.
