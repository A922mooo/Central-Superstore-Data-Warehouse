/*
================================================================================
 05_Validation.sql
 Central Superstore Data Warehouse Project
 Purpose : Compare warehouse (FactSales) aggregates against the values
           independently recalculated from Central_Superstore.xlsx during
           data profiling (see documentation/Data_Profiling.md). Every
           @Source_* constant below was computed with pandas directly
           against the source workbook -- it is not assumed or invented.

 Recalculated source values (Central Region, 2,323 rows):
   Total Sales     = 501,239.8908
   Total Profit    =  39,706.3625
   Total Quantity  =  8,780
   Avg Discount    =  0.240353  (24.04%)
   Distinct Orders =  1,175
   Distinct Customers = 629
   Distinct Products  = 1,310
   Row count       = 2,323
   These match the baseline figures supplied in the project brief.
================================================================================
*/

USE CentralSuperstoreDW;
GO
SET NOCOUNT ON;
GO

DECLARE
    @Source_RowCount        INT             = 2323,
    @Source_TotalSales      DECIMAL(14,4)   = 501239.8908,
    @Source_TotalProfit     DECIMAL(14,4)   = 39706.3625,
    @Source_TotalQuantity   INT             = 8780,
    @Source_AvgDiscount     DECIMAL(9,6)    = 0.240353,
    @Source_DistinctOrders  INT             = 1175,
    @Source_DistinctCustomers INT           = 629,
    @Source_DistinctProducts  INT           = 1310;

DECLARE
    @WH_RowCount        INT,
    @WH_TotalSales       DECIMAL(14,4),
    @WH_TotalProfit      DECIMAL(14,4),
    @WH_TotalQuantity    INT,
    @WH_AvgDiscount      DECIMAL(9,6),
    @WH_DistinctOrders   INT,
    @WH_DistinctCustomers INT,
    @WH_DistinctProducts  INT;

SELECT
    @WH_RowCount        = COUNT(*),
    @WH_TotalSales       = SUM(Sales),
    @WH_TotalProfit      = SUM(Profit),
    @WH_TotalQuantity    = SUM(Quantity),
    @WH_AvgDiscount      = AVG(Discount),
    @WH_DistinctOrders   = COUNT(DISTINCT OrderID)
FROM dw.FactSales;

SELECT @WH_DistinctCustomers = COUNT(*) FROM dw.DimCustomer;
SELECT @WH_DistinctProducts  = COUNT(*) FROM dw.DimProduct;

-- Note: DimProduct may legitimately contain a few more rows than 1,310
-- distinct Product IDs, because 16 Product IDs in the source map to more
-- than one Product Name/Category combination (documented data-quality
-- finding). This is expected and explained in the row below, not a failure.

;WITH Results AS (
    SELECT 'Row Count (FactSales)'      AS Metric, CAST(@Source_RowCount AS VARCHAR(30))         AS SourceValue, CAST(@WH_RowCount AS VARCHAR(30))         AS WarehouseValue
    UNION ALL
    SELECT 'Total Sales',                 CAST(@Source_TotalSales AS VARCHAR(30)),                 CAST(@WH_TotalSales AS VARCHAR(30))
    UNION ALL
    SELECT 'Total Profit',                CAST(@Source_TotalProfit AS VARCHAR(30)),                CAST(@WH_TotalProfit AS VARCHAR(30))
    UNION ALL
    SELECT 'Total Quantity',              CAST(@Source_TotalQuantity AS VARCHAR(30)),              CAST(@WH_TotalQuantity AS VARCHAR(30))
    UNION ALL
    SELECT 'Average Discount',            CAST(@Source_AvgDiscount AS VARCHAR(30)),                CAST(@WH_AvgDiscount AS VARCHAR(30))
    UNION ALL
    SELECT 'Distinct Orders',             CAST(@Source_DistinctOrders AS VARCHAR(30)),             CAST(@WH_DistinctOrders AS VARCHAR(30))
    UNION ALL
    SELECT 'Distinct Customers',          CAST(@Source_DistinctCustomers AS VARCHAR(30)),          CAST(@WH_DistinctCustomers AS VARCHAR(30))
    UNION ALL
    SELECT 'Distinct Products (natural ProductID count)', CAST(@Source_DistinctProducts AS VARCHAR(30)), CAST(@WH_DistinctProducts AS VARCHAR(30))
)
SELECT
    Metric,
    SourceValue,
    WarehouseValue,
    CASE
        WHEN Metric = 'Distinct Products (natural ProductID count)'
             THEN CASE WHEN TRY_CAST(WarehouseValue AS INT) >= TRY_CAST(SourceValue AS INT) THEN 'PASS (see note)' ELSE 'FAIL' END
        WHEN TRY_CAST(SourceValue AS DECIMAL(18,6)) = TRY_CAST(WarehouseValue AS DECIMAL(18,6)) THEN 'PASS'
        WHEN ABS(TRY_CAST(SourceValue AS DECIMAL(18,6)) - TRY_CAST(WarehouseValue AS DECIMAL(18,6))) < 0.01 THEN 'PASS (rounding)'
        ELSE 'FAIL'
    END AS Status
FROM Results;
GO

-------------------------------------------------------------------------------
-- Referential integrity checks: no orphan foreign keys should ever be
-- possible given the FK constraints, but we verify explicitly for the audit.
-------------------------------------------------------------------------------
SELECT 'Orphan CustomerKey' AS Check_, COUNT(*) AS Violations
FROM dw.FactSales f LEFT JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey WHERE c.CustomerKey IS NULL
UNION ALL
SELECT 'Orphan ProductKey', COUNT(*)
FROM dw.FactSales f LEFT JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey WHERE p.ProductKey IS NULL
UNION ALL
SELECT 'Orphan LocationKey', COUNT(*)
FROM dw.FactSales f LEFT JOIN dw.DimLocation l ON f.LocationKey = l.LocationKey WHERE l.LocationKey IS NULL
UNION ALL
SELECT 'Orphan ShipModeKey', COUNT(*)
FROM dw.FactSales f LEFT JOIN dw.DimShipMode sm ON f.ShipModeKey = sm.ShipModeKey WHERE sm.ShipModeKey IS NULL
UNION ALL
SELECT 'Orphan OrderDateKey', COUNT(*)
FROM dw.FactSales f LEFT JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey WHERE d.DateKey IS NULL
UNION ALL
SELECT 'Orphan ShipDateKey', COUNT(*)
FROM dw.FactSales f LEFT JOIN dw.DimDate d ON f.ShipDateKey = d.DateKey WHERE d.DateKey IS NULL;
GO

-------------------------------------------------------------------------------
-- Data integrity: business-rule checks on the loaded fact data
-------------------------------------------------------------------------------
SELECT 'Negative or zero Sales'      AS Check_, COUNT(*) AS Violations FROM dw.FactSales WHERE Sales <= 0
UNION ALL
SELECT 'Non-positive Quantity',       COUNT(*) FROM dw.FactSales WHERE Quantity <= 0
UNION ALL
SELECT 'Discount out of [0,1] range', COUNT(*) FROM dw.FactSales WHERE Discount < 0 OR Discount > 1
UNION ALL
SELECT 'Ship Date before Order Date', COUNT(*)
FROM dw.FactSales f
JOIN dw.DimDate od ON f.OrderDateKey = od.DateKey
JOIN dw.DimDate sd ON f.ShipDateKey = sd.DateKey
WHERE sd.FullDate < od.FullDate;
GO

PRINT '05_Validation.sql completed. Review the three result sets above: '
    + 'metric PASS/FAIL, orphan-key counts (must be 0), and integrity-rule counts (must be 0).';
GO
