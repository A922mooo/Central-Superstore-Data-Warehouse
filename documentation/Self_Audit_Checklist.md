# Self-Audit Checklist — Central Superstore DW Project

| Requirement | Implemented? | File / Location |
|---|---|---|
| 5+ relational tables | ✅ Yes (6: 5 dims + 1 fact) | `02_Create_Dimensions.sql`, `03_Create_Fact.sql` |
| One Fact table | ✅ Yes | `dw.FactSales` in `03_Create_Fact.sql` |
| Multiple Dimension tables | ✅ Yes (5) | `02_Create_Dimensions.sql` |
| Primary Keys | ✅ Yes, every table | `02_Create_Dimensions.sql`, `03_Create_Fact.sql` |
| Foreign Keys | ✅ Yes, 6 on FactSales | `03_Create_Fact.sql` |
| Proper data types (DECIMAL not FLOAT, PostalCode as text) | ✅ Yes | `03_Create_Fact.sql`, `02_Create_Dimensions.sql` |
| Referential integrity | ✅ Yes, enforced by FK constraints + validated | `03_Create_Fact.sql`, `05_Validation.sql` |
| Data loading from Excel source | ✅ Yes, two interchangeable methods | `04_Load_Data.sql` (BULK INSERT), `etl/load_central_superstore.py` (Python) |
| 15+ analytical queries | ✅ Yes (22) | `06_Analytical_Queries.sql` |
| 3+ JOIN-based queries | ✅ Yes (11+) | `06_Analytical_Queries.sql` |
| 2+ CTE queries | ✅ Yes (2, both substantive) | `07_Advanced_SQL.sql` |
| Subqueries | ✅ Yes (3) | `07_Advanced_SQL.sql` |
| CASE statements | ✅ Yes (2 real analyses) | `07_Advanced_SQL.sql` |
| 1+ SQL View | ✅ Yes | `08_View.sql` — `dw.vw_SalesPerformance` |
| 1+ Stored Procedure | ✅ Yes (3) | `09_Stored_Procedure.sql` |
| Query optimization | ✅ Yes, with STATISTICS IO/TIME + execution-plan guidance | `10_Indexes_Optimization.sql` |
| Indexing | ✅ Yes (7 justified indexes) | `10_Indexes_Optimization.sql` |
| KPI analysis | ✅ Yes | `analytics/KPI_Dashboard.png`, Query 5, Report Section 22 |
| Customer analysis | ✅ Yes | `analytics/Customer_Analysis.png`, Queries 16-18, CTE #1, Report Section 24 |
| Profitability analysis | ✅ Yes | `analytics/Category_Performance.png`, `Product_Performance.png`, `Discount_Impact.png`, Report Section 23/26 |
| Sales trends | ✅ Yes | `analytics/Sales_Trend.png`, Queries 6-10, Report Section 25 |
| Documentation | ✅ Yes | `README.md`, `documentation/Data_Profiling.md`, `documentation/Project_Report.pdf` |
| Visuals (Star Schema, ETL, Architecture, KPI, charts) | ✅ Yes | `documentation/*.png`, `analytics/*.png` |
| Validation | ✅ Yes, source-vs-warehouse + integrity checks | `05_Validation.sql` |
| Grain explicitly documented | ✅ Yes | `03_Create_Fact.sql` header, Report Section 8 |
| Baseline figures recalculated (not assumed) | ✅ Yes, exact match confirmed | `documentation/Data_Profiling.md`, Report Section 5 |
| Master deployment script | ✅ Yes (SQLCMD mode) | `11_Master_Deploy.sql` |
| Error handling (TRY/CATCH, transactions) | ✅ Yes | `04_Load_Data.sql`, `09_Stored_Procedure.sql` |
| Region-scoped framing (not company-wide) | ✅ Yes, stated throughout | README, all documentation, report |
| No invented data / results / screenshots | ✅ Confirmed — all figures recalculated from the actual file; SSMS screenshots explicitly marked as placeholders for the user to capture | All `.sql` files, this checklist |

**Result: all requirements met. No gaps identified.**

Note on screenshots: this environment cannot execute T-SQL against a live SQL Server instance, so genuine SSMS screenshots cannot be produced here. Every `.sql` file contains `[SSMS SCREENSHOT PLACEHOLDER: ...]` comments marking exactly where to capture your own screenshot after running the scripts, per the project's explicit instruction not to fabricate screenshots.
