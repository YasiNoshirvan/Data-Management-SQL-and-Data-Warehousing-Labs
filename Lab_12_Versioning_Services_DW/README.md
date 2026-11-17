# Lab 12 - Code Versioning Services Data Warehouse

This lab transforms activity from a Git/SVN-like code-versioning service into a dimensional warehouse for analyzing **commits, code additions, code deletions, repositories, branches, developers, teams, programming languages, and time**.

## Files

- `Versioning_services_DW_text.pdf` - original assignment
- `versioning_services_dw.sql` - warehouse schema and both frequent queries
- `README.md` - design explanation

## Model

`fact_commit` records commit activity at commit grain and stores:

- commit count
- added lines
- deleted lines
- commit hour

A branch belongs to one repository, while repositories can use several programming languages. This many-to-many relationship is represented by `bridge_repository_language`.

Developers belong to a work team and also carry the role needed by the source specification.

## Query A
For private repositories by month:

- average commits per active day
- average commits per active branch
- cumulative commits from the beginning of the year

## Query B
For repositories that include Scala:

- additions/deletions ratio by branch and work team
- share of additions relative to the entire repository
- ranking of work teams within each branch by additions/deletions ratio

`NULLIF` is used for ratios so zero deletions do not cause division-by-zero errors.

## SQL dialect

PostgreSQL 14+.
