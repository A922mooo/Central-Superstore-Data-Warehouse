/*
================================================================================
 04_Load_Data.sql (CORRECTED VERSION 2)
================================================================================
*/

USE CentralSuperstoreDW;
GO
SET NOCOUNT ON;
GO

-------------------------------------------------------------------------------
-- STEP 0: Configure the CSV path (EDIT THIS LINE FOR YOUR MACHINE)
-------------------------------------------------------------------------------
DECLARE @CsvPath NVARCHAR(400) = N'C:\Users\DELL\Desktop\Central_Superstore_SQL_Project\Central_Superstore_SQL_Project\data\Central_Superstore_Staging.csv';

-------------------------------------------------------------------------------
-- STEP 1: Load raw CSV into staging (truncate-and-reload)
-------------------------------------------------------------------------------
TRUNCATE TABLE stg.CentralSuperstoreRaw;
TRUNCATE TABLE dw.FactSales;

DECLARE @sql NVARCHAR(MAX) = N'
BULK INSERT stg.CentralSuperstoreRaw
FROM ''' + @CsvPath + N'''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

BEGIN TRY
    EXEC sp_executesql @sql;
    PRINT 'Staging load complete: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows staged.';
END TRY
BEGIN CATCH
    PRINT 'BULK INSERT failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-------------------------------------------------------------------------------
-- STEP 2: Basic ETL validation
-------------------------------------------------------------------------------
DECLARE @BadRows INT, @TotalStaged INT;
SELECT @TotalStaged = COUNT(*) FROM stg.CentralSuperstoreRaw;
SELECT @BadRows = COUNT(*)
FROM stg.CentralSuperstoreRaw
WHERE TRY_CAST(OrderDate AS DATE) IS NULL
   OR TRY_CAST(ShipDate  AS DATE) IS NULL
   OR TRY_CAST(Sales     AS DECIMAL(12,4)) IS NULL
   OR TRY_CAST(Quantity  AS INT) IS NULL
   OR TRY_CAST(Discount  AS DECIMAL(5,4)) IS NULL
   OR TRY_CAST(Profit    AS DECIMAL(12,4)) IS NULL;

IF @TotalStaged = 0
    RAISERROR('Staging table is empty.', 16, 1);
ELSE IF @BadRows > 0
    PRINT CAST(@BadRows AS VARCHAR(10)) + ' row(s) failed validation.';
ELSE
    PRINT 'Type validation passed: all ' + CAST(@TotalStaged AS VARCHAR(10)) + ' staged rows OK.';
GO

-------------------------------------------------------------------------------
-- STEP 3: Load DimCustomer  (DELETE, not TRUNCATE -- FK-referenced table)
-------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dw.DimCustomer;
    INSERT INTO dw.DimCustomer (CustomerID, CustomerName, Segment)
    SELECT DISTINCT CustomerID, CustomerName, Segment
    FROM stg.CentralSuperstoreRaw
    WHERE TRY_CAST(OrderDate AS DATE) IS NOT NULL
      AND TRY_CAST(ShipDate AS DATE) IS NOT NULL
      AND TRY_CAST(Sales AS DECIMAL(12,4)) IS NOT NULL
      AND TRY_CAST(Quantity AS INT) IS NOT NULL
      AND TRY_CAST(Discount AS DECIMAL(5,4)) IS NOT NULL
      AND TRY_CAST(Profit AS DECIMAL(12,4)) IS NOT NULL;
    PRINT 'DimCustomer loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows.';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'DimCustomer load failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-------------------------------------------------------------------------------
-- STEP 4: Load DimProduct
-------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dw.DimProduct;
    INSERT INTO dw.DimProduct (ProductID, ProductName, Category, SubCategory)
    SELECT DISTINCT ProductID, ProductName, Category, SubCategory
    FROM stg.CentralSuperstoreRaw
    WHERE TRY_CAST(OrderDate AS DATE) IS NOT NULL
      AND TRY_CAST(ShipDate AS DATE) IS NOT NULL
      AND TRY_CAST(Sales AS DECIMAL(12,4)) IS NOT NULL
      AND TRY_CAST(Quantity AS INT) IS NOT NULL
      AND TRY_CAST(Discount AS DECIMAL(5,4)) IS NOT NULL
      AND TRY_CAST(Profit AS DECIMAL(12,4)) IS NOT NULL;
    PRINT 'DimProduct loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows.';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'DimProduct load failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-------------------------------------------------------------------------------
-- STEP 5: Load DimLocation
-------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dw.DimLocation;
    INSERT INTO dw.DimLocation (Country, City, State, PostalCode, Region)
    SELECT DISTINCT Country, City, State, PostalCode, Region
    FROM stg.CentralSuperstoreRaw
    WHERE TRY_CAST(OrderDate AS DATE) IS NOT NULL
      AND TRY_CAST(ShipDate AS DATE) IS NOT NULL
      AND TRY_CAST(Sales AS DECIMAL(12,4)) IS NOT NULL
      AND TRY_CAST(Quantity AS INT) IS NOT NULL
      AND TRY_CAST(Discount AS DECIMAL(5,4)) IS NOT NULL
      AND TRY_CAST(Profit AS DECIMAL(12,4)) IS NOT NULL;
    PRINT 'DimLocation loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows.';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'DimLocation load failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-------------------------------------------------------------------------------
-- STEP 6: Load DimShipMode
-------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dw.DimShipMode;
    INSERT INTO dw.DimShipMode (ShipMode)
    SELECT DISTINCT ShipMode
    FROM stg.CentralSuperstoreRaw
    WHERE TRY_CAST(OrderDate AS DATE) IS NOT NULL
      AND TRY_CAST(ShipDate AS DATE) IS NOT NULL
      AND TRY_CAST(Sales AS DECIMAL(12,4)) IS NOT NULL
      AND TRY_CAST(Quantity AS INT) IS NOT NULL
      AND TRY_CAST(Discount AS DECIMAL(5,4)) IS NOT NULL
      AND TRY_CAST(Profit AS DECIMAL(12,4)) IS NOT NULL;
    PRINT 'DimShipMode loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows.';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'DimShipMode load failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-------------------------------------------------------------------------------
-- STEP 7: Load DimDate
-------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dw.DimDate;

    DECLARE @MinDate DATE, @MaxDate DATE;
    SELECT
        @MinDate = MIN(d),
        @MaxDate = MAX(d)
    FROM (
        SELECT TRY_CAST(OrderDate AS DATE) AS d FROM stg.CentralSuperstoreRaw WHERE TRY_CAST(OrderDate AS DATE) IS NOT NULL
        UNION ALL
        SELECT TRY_CAST(ShipDate AS DATE) AS d FROM stg.CentralSuperstoreRaw WHERE TRY_CAST(ShipDate AS DATE) IS NOT NULL
    ) AS AllDates;

    PRINT 'Derived date range: ' + CONVERT(VARCHAR(10), @MinDate, 120) + ' to ' + CONVERT(VARCHAR(10), @MaxDate, 120);

    ;WITH Numbers AS (
        SELECT TOP (DATEDIFF(DAY, @MinDate, @MaxDate) + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    Dates AS (
        SELECT DATEADD(DAY, n, @MinDate) AS FullDate
        FROM Numbers
    )
    INSERT INTO dw.DimDate
        (DateKey, FullDate, DayNumber, DayName, MonthNumber, MonthName,
         QuarterNumber, YearNumber, WeekNumber, IsWeekend)
    SELECT
        CONVERT(INT, FORMAT(FullDate, 'yyyyMMdd')),
        FullDate,
        DAY(FullDate),
        DATENAME(WEEKDAY, FullDate),
        MONTH(FullDate),
        DATENAME(MONTH, FullDate),
        DATEPART(QUARTER, FullDate),
        YEAR(FullDate),
        DATEPART(ISO_WEEK, FullDate),
        CASE WHEN DATENAME(WEEKDAY, FullDate) IN ('Saturday','Sunday') THEN 1 ELSE 0 END
    FROM Dates
    OPTION (MAXRECURSION 0);

    PRINT 'DimDate loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' calendar days.';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'DimDate load failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

-------------------------------------------------------------------------------
-- STEP 8: Load FactSales
-------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;
    TRUNCATE TABLE dw.FactSales;

    INSERT INTO dw.FactSales
        (SourceRowID, OrderID, OrderDateKey, ShipDateKey, CustomerKey,
         ProductKey, LocationKey, ShipModeKey, Quantity, Sales, Discount, Profit)
    SELECT
        CAST(s.RowID AS INT),
        s.OrderID,
        CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd')),
        CONVERT(INT, FORMAT(TRY_CAST(s.ShipDate  AS DATE), 'yyyyMMdd')),
        c.CustomerKey,
        p.ProductKey,
        l.LocationKey,
        sm.ShipModeKey,
        CAST(s.Quantity AS INT),
        CAST(s.Sales AS DECIMAL(12,4)),
        CAST(s.Discount AS DECIMAL(5,4)),
        CAST(s.Profit AS DECIMAL(12,4))
    FROM stg.CentralSuperstoreRaw s
    INNER JOIN dw.DimCustomer  c  ON c.CustomerID = s.CustomerID
    INNER JOIN dw.DimProduct   p  ON p.ProductID = s.ProductID
                                  AND p.ProductName = s.ProductName
                                  AND p.Category = s.Category
                                  AND p.SubCategory = s.SubCategory
    INNER JOIN dw.DimLocation  l  ON l.City = s.City
                                  AND l.State = s.State
                                  AND l.PostalCode = s.PostalCode
                                  AND l.Region = s.Region
    INNER JOIN dw.DimShipMode  sm ON sm.ShipMode = s.ShipMode
    WHERE TRY_CAST(s.OrderDate AS DATE) IS NOT NULL
      AND TRY_CAST(s.ShipDate AS DATE) IS NOT NULL
      AND TRY_CAST(s.Sales AS DECIMAL(12,4)) IS NOT NULL
      AND TRY_CAST(s.Quantity AS INT) IS NOT NULL
      AND TRY_CAST(s.Discount AS DECIMAL(5,4)) IS NOT NULL
      AND TRY_CAST(s.Profit AS DECIMAL(12,4)) IS NOT NULL;

    DECLARE @FactRows INT = @@ROWCOUNT;
    PRINT 'FactSales loaded: ' + CAST(@FactRows AS VARCHAR(10)) + ' rows.';

    DECLARE @ExpectedRows INT;
    SELECT @ExpectedRows = COUNT(*)
    FROM stg.CentralSuperstoreRaw
    WHERE TRY_CAST(OrderDate AS DATE) IS NOT NULL
      AND TRY_CAST(ShipDate AS DATE) IS NOT NULL
      AND TRY_CAST(Sales AS DECIMAL(12,4)) IS NOT NULL
      AND TRY_CAST(Quantity AS INT) IS NOT NULL
      AND TRY_CAST(Discount AS DECIMAL(5,4)) IS NOT NULL
      AND TRY_CAST(Profit AS DECIMAL(12,4)) IS NOT NULL;

    IF @FactRows <> @ExpectedRows
        PRINT 'WARNING: expected ' + CAST(@ExpectedRows AS VARCHAR(10)) + ' but loaded ' + CAST(@FactRows AS VARCHAR(10)) + '.';
    ELSE
        PRINT 'Row-count reconciliation passed: every valid staged row produced exactly one fact row.';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FactSales load failed and was rolled back: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

PRINT '04_Load_Data.sql completed. Run 05_Validation.sql next.';
GO