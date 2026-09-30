# Central Superstore Data Warehouse & Analytics Project

**Scope:** This entire project analyzes the **Central Region only**, from `Central_Superstore.xlsx` (2,323 order-line rows, 2013–2016). It is not a company-wide or global sales analysis.

This README assumes no advanced SQL background. Follow the steps in order.

---

## What you need before starting

| Requirement | Notes |
|---|---|
| SQL Server (2016+) | Developer or Express edition is fine |
| SQL Server Management Studio (SSMS) | Free download from Microsoft |
| The project folder | Keep the folder structure intact — scripts reference each other by relative path |
| (Optional) Python 3.9+ | Only needed if you use the Python ETL loader instead of BULK INSERT |

---

## Folder contents

```
Central_Superstore_SQL_Project/
├── README.md                        <- you are here
├── 01_Database_Setup.sql            <- creates the database + staging table
├── 02_Create_Dimensions.sql         <- creates the 5 dimension tables
├── 03_Create_Fact.sql               <- creates FactSales with all keys
├── 04_Load_Data.sql                 <- loads data (BULK INSERT method)
├── 05_Validation.sql                <- checks warehouse == source
├── 06_Analytical_Queries.sql        <- 20+ business queries
├── 07_Advanced_SQL.sql              <- CTEs, subqueries, CASE statements
├── 08_View.sql                      <- dw.vw_SalesPerformance
├── 09_Stored_Procedure.sql          <- 3 stored procedures
├── 10_Indexes_Optimization.sql      <- performance indexes + explanations
├── 11_Master_Deploy.sql             <- runs 01/02/03/08/09/10 in one go
├── data/
│   ├── Central_Superstore.xlsx      <- the original source file
│   └── Central_Superstore_Staging.csv  <- CSV export used by BULK INSERT
├── etl/
│   └── load_central_superstore.py   <- alternative Python loader
├── documentation/
│   ├── Project_Report.md/.pdf       <- full written report
│   ├── Data_Profiling.md            <- data profiling & quality findings
│   ├── Star_Schema.png
│   ├── ETL_Workflow.png
│   └── Database_Architecture.png
└── analytics/
    ├── KPI_Dashboard.png
    ├── Sales_Trend.png
    ├── Category_Performance.png
    ├── Product_Performance.png
    ├── Customer_Analysis.png
    ├── Geographic_Analysis.png
    └── Discount_Impact.png
```

---

## WHAT I NEED TO DO (minimum steps)

1. **Open SSMS**, connect to your SQL Server instance.
2. Enable **SQLCMD Mode**: menu **Query → SQLCMD Mode**.
3. Open **`11_Master_Deploy.sql`** and press **Execute (F5)**.
   This creates the database, schema, all 6 tables, the view, the 3 stored procedures, and the indexes.
4. Open **`04_Load_Data.sql`**, edit the `@CsvPath` variable near the top to point at your copy of `data\Central_Superstore_Staging.csv`, then Execute.
   *(If BULK INSERT fails or is blocked on your server, run the Python loader instead — see "Alternative loading" below.)*
5. Open **`05_Validation.sql`** and Execute. Confirm every row says **PASS** and every orphan/integrity count is **0**.
6. Open **`06_Analytical_Queries.sql`** and **`07_Advanced_SQL.sql`** to explore the business analysis (run whichever queries you want to review).
7. Optionally run the examples in **`08_View.sql`** and **`09_Stored_Procedure.sql`**.

That's it — everything else in this project (documentation, diagrams, charts, report) is already generated for you and needs no further action.

---

## Step-by-step detail

### Step 1: Install/verify SQL Server and SSMS
Any edition of SQL Server 2016 or newer works. Confirm you can connect to it in SSMS with a login that has permission to create databases.

### Step 2: Place the project files
Copy the whole `Central_Superstore_SQL_Project` folder somewhere on the machine running SQL Server (or a location the SQL Server *service account* can read from, for BULK INSERT). Note the full path — you'll need it in Step 4.

### Step 3: Run the master script
This is pure structure (tables, keys, view, procedures, indexes) — no data yet. Safe to re-run any time; it drops and recreates the relevant objects.

### Step 4: Run the ETL loader
Two interchangeable options:

**Option A — T-SQL BULK INSERT (`04_Load_Data.sql`)**
- Edit the line: `DECLARE @CsvPath NVARCHAR(400) = N'C:\...\data\Central_Superstore_Staging.csv';`
- Execute the whole script.
- If you see a permissions or "cannot bulk load" error, your SQL Server service account cannot read that path (common on locked-down or cloud instances) — use Option B instead.

**Option B — Python ETL (`etl\load_central_superstore.py`)**
```
pip install pandas openpyxl sqlalchemy pyodbc
python etl/load_central_superstore.py
```
- Edit the `CONFIG` dictionary at the top of the script (server name, database, authentication) first, or set the equivalent environment variables.
- Requires the "ODBC Driver 17 for SQL Server" to be installed.
- Reads `Central_Superstore.xlsx` directly — no CSV needed.
- Produces an identical warehouse to Option A.

### Step 5: Run validation
`05_Validation.sql` recomputes Total Sales, Total Profit, Total Quantity, Average Discount, and distinct Order/Customer/Product counts from the warehouse and compares them against the values independently recalculated from the Excel file. Every metric should read **PASS**.

### Step 6: Run analytical queries
`06_Analytical_Queries.sql` — 22 numbered, documented business queries across KPIs, trends, products, customers, geography, and shipping.

### Step 7: Execute stored procedures
```sql
EXEC dw.usp_GetSalesByYear @Year = 2016;
EXEC dw.usp_GetTopProductsByProfit @TopN = 10, @Category = 'Technology';
EXEC dw.usp_GetCustomerSummary @CustomerID = 'TC-20980';  -- use any real CustomerID
```

### Step 8: Open the view
```sql
SELECT * FROM dw.vw_SalesPerformance ORDER BY SalesYear, SalesMonth;
```

### Step 9: Review dashboard / report
Open the PNG charts in `analytics/` and the diagrams in `documentation/`, and read `documentation/Project_Report.md` (or the PDF, if generated) for the full write-up of findings.

---

## Configuration reference

| Setting | Where | Notes |
|---|---|---|
| SQL Server instance name | SSMS connection dialog | e.g. `localhost`, `.\SQLEXPRESS`, or a named server |
| Authentication | SSMS connection dialog / `etl` script CONFIG | Windows Authentication is simplest for a local install |
| Excel/CSV file path | `04_Load_Data.sql` (`@CsvPath`) and/or `etl` script CONFIG | Must be a path SQL Server (or Python) can actually read |
| ODBC driver | Only needed for the Python loader | "ODBC Driver 17 for SQL Server" |
| Database name | Fixed as `CentralSuperstoreDW` | Created automatically by `01_Database_Setup.sql` |

---

## Notes on data quality (see `documentation/Data_Profiling.md` for full detail)

- No missing values and no fully duplicated rows were found in the source.
- 16 Product IDs in the source map to more than one Product Name — this is a known quirk of this dataset, not a load error. `DimProduct` is keyed on the combination of ProductID + ProductName + Category + SubCategory to preserve every real product record.
- Order ID legitimately repeats across rows (multi-line orders) — this is expected and preserved; the fact table grain is one row per order **line**, not one row per order.
- All 2,323 rows passed type and business-rule validation (positive quantity, discount within [0,1], valid dates) — nothing was silently dropped.
