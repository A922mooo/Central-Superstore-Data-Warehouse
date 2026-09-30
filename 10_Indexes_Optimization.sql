/*
================================================================================
 10_Indexes_Optimization.sql
 Central Superstore Data Warehouse Project
 Purpose : Add targeted, justified indexes based on the JOIN / WHERE /
           GROUP BY / ORDER BY patterns actually used in 06 and 07, and show
           how to measure their effect with SET STATISTICS IO/TIME.

 Indexing philosophy applied here:
   - FactSales foreign keys are the single most common JOIN path in every
     analytical query, so each gets a nonclustered index.
   - We do NOT index every column. Dimension attribute columns used only in
     small dimension tables (a few hundred to a few thousand rows) gain
     little from indexing and are skipped to avoid needless write overhead.
   - Every index below is tied to a specific, real query pattern -- not
     created "just in case."
 Safe to re-run: YES.
================================================================================
*/

USE CentralSuperstoreDW;
GO

-------------------------------------------------------------------------------
-- Index 1: CustomerKey on FactSales
-- Why: every customer-analysis query (16, 17, 18, CTE #1, subquery #2) joins
-- FactSales to DimCustomer on this column.
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_CustomerKey')
    CREATE NONCLUSTERED INDEX IX_FactSales_CustomerKey ON dw.FactSales (CustomerKey);
GO

-------------------------------------------------------------------------------
-- Index 2: ProductKey on FactSales
-- Why: every product-analysis query (11-15, CTE #2, subqueries #1 and #3)
-- joins FactSales to DimProduct on this column.
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_ProductKey')
    CREATE NONCLUSTERED INDEX IX_FactSales_ProductKey ON dw.FactSales (ProductKey);
GO

-------------------------------------------------------------------------------
-- Index 3: OrderDateKey on FactSales, with included aggregation columns
-- Why: virtually every trend query (6-10) filters/groups by OrderDateKey via
-- DimDate, then aggregates Sales/Profit/Quantity. Including those columns
-- lets many trend queries be satisfied entirely from the index (a covering
-- index) without a lookup back to the clustered index.
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_OrderDateKey')
    CREATE NONCLUSTERED INDEX IX_FactSales_OrderDateKey
    ON dw.FactSales (OrderDateKey)
    INCLUDE (Sales, Profit, Quantity, OrderID);
GO

-------------------------------------------------------------------------------
-- Index 4: ShipDateKey on FactSales
-- Why: shipping analysis (query 22) joins DimDate a second time on this
-- column to compute shipping duration.
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_ShipDateKey')
    CREATE NONCLUSTERED INDEX IX_FactSales_ShipDateKey ON dw.FactSales (ShipDateKey);
GO

-------------------------------------------------------------------------------
-- Index 5: LocationKey on FactSales
-- Why: geographic analysis (queries 19-20) joins FactSales to DimLocation.
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_LocationKey')
    CREATE NONCLUSTERED INDEX IX_FactSales_LocationKey ON dw.FactSales (LocationKey);
GO

-------------------------------------------------------------------------------
-- Index 6: ShipModeKey on FactSales
-- Why: shipping analysis (query 21) joins FactSales to DimShipMode.
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_ShipModeKey')
    CREATE NONCLUSTERED INDEX IX_FactSales_ShipModeKey ON dw.FactSales (ShipModeKey);
GO

-------------------------------------------------------------------------------
-- Index 7: OrderID on FactSales
-- Why: COUNT(DISTINCT OrderID) appears in nearly every KPI and trend query;
-- a dedicated index speeds up the distinct-count scan considerably on
-- larger data volumes (marginal here at 2,323 rows, but this is the
-- correct index to have as the fact table grows).
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSales_OrderID')
    CREATE NONCLUSTERED INDEX IX_FactSales_OrderID ON dw.FactSales (OrderID);
GO

PRINT 'All indexes created (or already present).';
GO

-------------------------------------------------------------------------------
-- Trade-offs (documented, not just implemented):
--   - Each nonclustered index adds storage and a small write cost on every
--     INSERT/UPDATE/DELETE into FactSales, because the index must be
--     maintained alongside the clustered index. For a fact table refreshed
--     in periodic batch loads (as here), this cost is negligible compared
--     to the read-performance benefit for a BI/reporting workload.
--   - The covering index on OrderDateKey trades additional index size for
--     avoiding key lookups on the most frequently filtered column.
--   - We deliberately did NOT index Discount or Profit directly: they are
--     used in aggregate/CASE expressions, not equality/range filters, so a
--     b-tree index on them would not be selective enough to be used by the
--     optimizer.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Before/after measurement harness.
-- Run this block, note the IO/TIME output, then compare to the same query
-- run before the indexes above existed (e.g. on a freshly-loaded copy).
-------------------------------------------------------------------------------
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    p.Category,
    d.YearNumber,
    SUM(f.Sales)  AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
JOIN dw.DimDate    d ON f.OrderDateKey = d.DateKey
GROUP BY p.Category, d.YearNumber
ORDER BY d.YearNumber, p.Category;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

/*
EXECUTION PLAN GUIDANCE (SSMS):
  1. Press Ctrl+M (Include Actual Execution Plan) before running the query above.
  2. After execution, open the "Execution plan" tab.
  3. Confirm the plan shows an Index Seek (not a full Table/Clustered Index
     Scan) on FactSales for ProductKey and OrderDateKey.
  4. Hover over the SELECT operator to see estimated vs actual row counts;
     large discrepancies indicate stale statistics -- run
     UPDATE STATISTICS dw.FactSales; if that occurs after large data loads.

[SSMS SCREENSHOT PLACEHOLDER:
 Execution plan showing Index Seek operators on dw.FactSales]
*/

PRINT '10_Indexes_Optimization.sql completed.';
GO
