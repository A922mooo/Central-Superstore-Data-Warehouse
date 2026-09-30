/*
================================================================================
 08_View.sql
 Central Superstore Data Warehouse Project
 Purpose : dw.vw_SalesPerformance -- a reusable, BI-tool-friendly view that
           pre-joins FactSales to its date and product dimensions at a
           Year / Month / Category / SubCategory grain. Intended to be the
           direct data source for Power BI / Tableau / Excel PivotTables.
 Safe to re-run: YES (CREATE OR ALTER).
================================================================================
*/

USE CentralSuperstoreDW;
GO

CREATE OR ALTER VIEW dw.vw_SalesPerformance
AS
SELECT
    d.YearNumber                                   AS SalesYear,
    d.MonthNumber                                  AS SalesMonth,
    d.MonthName                                    AS SalesMonthName,
    d.QuarterNumber                                AS SalesQuarter,
    p.Category,
    p.SubCategory,
    COUNT(DISTINCT f.OrderID)                      AS Orders,
    SUM(f.Quantity)                                AS TotalQuantity,
    SUM(f.Sales)                                   AS TotalSales,
    SUM(f.Discount * f.Sales) / NULLIF(SUM(f.Sales), 0) AS WeightedAvgDiscount,
    SUM(f.Profit)                                  AS TotalProfit,
    CAST(SUM(f.Profit) * 100.0 / NULLIF(SUM(f.Sales), 0) AS DECIMAL(6,2)) AS ProfitMarginPct
FROM dw.FactSales f
JOIN dw.DimDate    d ON f.OrderDateKey = d.DateKey
JOIN dw.DimProduct p ON f.ProductKey   = p.ProductKey
GROUP BY
    d.YearNumber, d.MonthNumber, d.MonthName, d.QuarterNumber,
    p.Category, p.SubCategory;
GO

PRINT 'View dw.vw_SalesPerformance created/altered successfully.';
GO

-------------------------------------------------------------------------------
-- Example usage
-------------------------------------------------------------------------------
-- All Central Region sales performance, most recent year first:
SELECT TOP 20 *
FROM dw.vw_SalesPerformance
ORDER BY SalesYear DESC, SalesMonth DESC, TotalSales DESC;

-- Category performance for a single year:
SELECT Category, SUM(TotalSales) AS TotalSales, SUM(TotalProfit) AS TotalProfit
FROM dw.vw_SalesPerformance
WHERE SalesYear = 2016
GROUP BY Category
ORDER BY TotalSales DESC;
GO

/*
[SSMS SCREENSHOT PLACEHOLDER:
 Object Explorer -> Views -> dw.vw_SalesPerformance, plus SELECT results grid]
*/
