/*
================================================================================
 11_Master_Deploy.sql
 Central Superstore Data Warehouse Project
 Purpose : Single entry point to deploy the entire schema in the correct
           order: database/staging -> dimensions -> fact -> view ->
           stored procedures -> indexes.

 *** REQUIRES SQLCMD MODE ***
 This script uses ":r" file-include directives, which only work when SSMS's
 SQLCMD Mode is enabled:
     SSMS menu -> Query -> SQLCMD Mode  (toggle ON)
 Then open this file and press Execute (F5). SSMS will run each referenced
 .sql file, in order, in a single pass.

 This script intentionally does NOT include 04_Load_Data.sql, 05_Validation.sql,
 06/07 (analytical queries) or 08/09 (view/proc examples) as part of the
 automatic chain for structural DDL, because loading requires you to first
 confirm the CSV path (04) and validation/analytics are meant to be reviewed
 interactively, not blown past silently. The recommended sequence is:

     1) Run 11_Master_Deploy.sql   (creates DB, schema, all tables, view, procs, indexes)
     2) Run 04_Load_Data.sql       (loads data -- edit @CsvPath first)
     3) Run 05_Validation.sql      (confirms warehouse == source)
     4) Run 06/07 as needed        (explore the analytics)

 Safe to re-run: YES, subject to the same guarantees as the individual scripts.
================================================================================
*/

:on error exit

PRINT '=== STEP 1/6: Database and staging setup ===';
:r .\01_Database_Setup.sql

PRINT '=== STEP 2/6: Dimension tables ===';
:r .\02_Create_Dimensions.sql

PRINT '=== STEP 3/6: Fact table ===';
:r .\03_Create_Fact.sql

PRINT '=== STEP 4/6: View ===';
:r .\08_View.sql

PRINT '=== STEP 5/6: Stored procedures ===';
:r .\09_Stored_Procedure.sql

PRINT '=== STEP 6/6: Indexes ===';
:r .\10_Indexes_Optimization.sql

PRINT '================================================================';
PRINT ' STRUCTURAL DEPLOYMENT COMPLETE.';
PRINT ' Next steps:';
PRINT '   1. Edit @CsvPath in 04_Load_Data.sql, then run it to load data.';
PRINT '   2. Run 05_Validation.sql to confirm the load matches the source.';
PRINT '   3. Explore 06_Analytical_Queries.sql and 07_Advanced_SQL.sql.';
PRINT '================================================================';
GO
