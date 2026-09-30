/*
================================================================================
 09_Stored_Procedure.sql
 Central Superstore Data Warehouse Project
 Purpose : Parameterized stored procedures for repeatable reporting.
 Safe to re-run: YES (CREATE OR ALTER).
================================================================================
*/

USE CentralSuperstoreDW;
GO

-------------------------------------------------------------------------------
-- dw.usp_GetSalesByYear
-- Returns Total Sales, Total Profit, Total Quantity, and Order Count for a
-- given year. Validates the parameter and raises a clear error for years
-- outside the range actually present in the warehouse.
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_GetSalesByYear
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE YearNumber = @Year)
    BEGIN
        RAISERROR('No data exists in the warehouse for year %d.', 16, 1, @Year);
        RETURN;
    END

    SELECT
        @Year                           AS ReportYear,
        SUM(f.Sales)                    AS Total_Sales,
        SUM(f.Profit)                   AS Total_Profit,
        SUM(f.Quantity)                 AS Total_Quantity,
        COUNT(DISTINCT f.OrderID)       AS Order_Count,
        CAST(SUM(f.Profit) * 100.0 / NULLIF(SUM(f.Sales), 0) AS DECIMAL(6,2)) AS Profit_Margin_Pct
    FROM dw.FactSales f
    JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
    WHERE d.YearNumber = @Year;
END
GO

-------------------------------------------------------------------------------
-- dw.usp_GetTopProductsByProfit
-- Returns the top N most profitable products, optionally filtered to a
-- single category. Demonstrates an optional/default parameter and TRY/CATCH
-- error handling.
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_GetTopProductsByProfit
    @TopN       INT = 10,
    @Category   NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @TopN <= 0
        BEGIN
            RAISERROR('@TopN must be a positive integer.', 16, 1);
            RETURN;
        END

        SELECT TOP (@TopN)
            p.ProductName,
            p.Category,
            p.SubCategory,
            SUM(f.Sales)  AS Total_Sales,
            SUM(f.Profit) AS Total_Profit
        FROM dw.FactSales f
        JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
        WHERE (@Category IS NULL OR p.Category = @Category)
        GROUP BY p.ProductName, p.Category, p.SubCategory
        ORDER BY Total_Profit DESC;
    END TRY
    BEGIN CATCH
        PRINT 'Error in dw.usp_GetTopProductsByProfit: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-------------------------------------------------------------------------------
-- dw.usp_GetCustomerSummary
-- Returns a full sales/profit summary for one customer by CustomerID,
-- useful for account-review style lookups.
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_GetCustomerSummary
    @CustomerID NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dw.DimCustomer WHERE CustomerID = @CustomerID)
    BEGIN
        RAISERROR('CustomerID %s was not found in dw.DimCustomer.', 16, 1, @CustomerID);
        RETURN;
    END

    SELECT
        c.CustomerName,
        c.Segment,
        COUNT(DISTINCT f.OrderID) AS Total_Orders,
        SUM(f.Quantity)           AS Total_Quantity,
        SUM(f.Sales)              AS Total_Sales,
        SUM(f.Profit)             AS Total_Profit
    FROM dw.FactSales f
    JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
    WHERE c.CustomerID = @CustomerID
    GROUP BY c.CustomerName, c.Segment;
END
GO

PRINT 'Stored procedures dw.usp_GetSalesByYear, dw.usp_GetTopProductsByProfit, dw.usp_GetCustomerSummary created.';
GO

-------------------------------------------------------------------------------
-- Example executions
-- Guarded so this script can also be safely included by 11_Master_Deploy.sql
-- BEFORE data has been loaded (FactSales is empty at that point in the
-- deployment sequence) without raising an error that halts SQLCMD mode.
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM dw.FactSales)
BEGIN
    EXEC dw.usp_GetSalesByYear @Year = 2016;
    EXEC dw.usp_GetTopProductsByProfit @TopN = 10, @Category = 'Technology';
END
ELSE
BEGIN
    PRINT 'FactSales is empty -- skipping example EXEC calls. Run 04_Load_Data.sql first, '
        + 'then re-run the EXEC statements at the bottom of this file manually.';
END
GO

/*
[SSMS SCREENSHOT PLACEHOLDER:
 Results grid from EXEC dw.usp_GetSalesByYear @Year = 2016]
*/
