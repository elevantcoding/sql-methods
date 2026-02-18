# sql-methods
A curated collection of SQL methods refined through enterprise development — real code that solved real problems.

# Key Highlights:
DDL Dependency Guard: A trigger-based system that parses metadata to prevent the deletion of objects referenced in dynamic SQL strings.

Dynamic Transformation: Utilized UNPIVOT to normalize flat "Weekly" time entries into discrete daily relational records.

Temporal Logic: Leveraged the LEAD window function to dynamically derive effective date ranges for pay rates, eliminating manual data entry errors and ensuring continuous temporal coverage.

Hybrid Architecture: Managed data flow across Linked Servers with robust error-handling to prevent partial updates.
