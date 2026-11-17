# Lab 07 - PC Assembler Data Warehouse

This assignment contains two distinct analytical processes: **component procurement** and **PC configuration sales**. The solution therefore uses a constellation with two fact tables rather than forcing incompatible measures into one table.

## Files

- `07-DW-project-PC-text.pdf` - original assignment
- `pc_assembler_dw.sql` - physical design, queries A-H, materialized views, and SCD strategy
- `README.md` - design rationale

## Core model

### Procurement fact
`fact_component_purchase`

Measures:

- quantity purchased
- component cost
- delivery cost

Analysis dimensions include supplier, supplier geography, component type/features, and purchase date.

### Sales fact
`fact_pc_sale`

Measures:

- production cost
- selling revenue
- sold quantity
- defective quantity

It is analyzed by standard PC configuration, retailer, and sale date.

A configuration stores the four required component references (RAM, HD, CPU, graphics board), making questions about component combinations directly queryable.

## Query coverage

The PDF formally asks for SQL for queries **D, E, and H**. The repository solution implements **all queries A-H** so the model can be checked end-to-end.

## Slowly changing dimensions

The assignment explicitly asks how changing dimensions should be handled. The design uses **SCD Type 2** for historically meaningful changes such as:

- number of shops for a retailer
- supplier geography if a supplier changes location

Surrogate keys preserve the dimensional state that was valid when each fact occurred.

## Source inconsistency

The cardinality list near the end of the PDF contains several lines about ski tows, tickets, and payment types. Those concepts do not appear anywhere in the PC-assembler problem statement and appear to be leftover text from another exercise. They are preserved in the source PDF but are intentionally not modeled here.

## SQL dialect

PostgreSQL 14+.
