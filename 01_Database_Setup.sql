/*
================================================================================
 01_Database_Setup.sql
 Central Superstore Data Warehouse Project
 Purpose : Create the database, the warehouse schema, and the staging table
           that will receive the raw Excel export before it is transformed
           into the star schema.
 Scope   : This warehouse models the CENTRAL REGION subset of the Superstore
           dataset only (2,323 order-line rows). It is NOT a company-wide
           or global sales warehouse.
 Safe to re-run: YES. All object creation is guarded with existence checks.
================================================================================
*/

SET NOCOUNT ON;
GO

-------------------------------------------------------------------------------
-- 1. Create the database if it does not already exist
-------------------------------------------------------------------------------
IF DB_ID(N'CentralSuperstoreDW') IS NULL
BEGIN
    PRINT 'Creating database CentralSuperstoreDW...';
    CREATE DATABASE CentralSuperstoreDW;
END
ELSE
BEGIN
    PRINT 'Database CentralSuperstoreDW already exists. Skipping creation.';
END
GO

USE CentralSuperstoreDW;
GO

-------------------------------------------------------------------------------
-- 2. Create the warehouse schema
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dw')
BEGIN
    EXEC('CREATE SCHEMA dw AUTHORIZATION dbo;');
    PRINT 'Schema [dw] created.';
END
ELSE
BEGIN
    PRINT 'Schema [dw] already exists. Skipping creation.';
END
GO

-------------------------------------------------------------------------------
-- 3. Create a staging schema, kept separate from the warehouse tables
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg')
BEGIN
    EXEC('CREATE SCHEMA stg AUTHORIZATION dbo;');
    PRINT 'Schema [stg] created.';
END
ELSE
BEGIN
    PRINT 'Schema [stg] already exists. Skipping creation.';
END
GO

-------------------------------------------------------------------------------
-- 4. Staging table: raw, (almost) untyped landing zone for the Excel export
--    Every column is intentionally kept close to the source so that the
--    BULK INSERT step below cannot fail on type coercion. All cleaning /
--    casting happens later, in 04_Load_Data.sql, where we control it
--    explicitly and can log rejected rows.
-------------------------------------------------------------------------------
IF OBJECT_ID(N'stg.CentralSuperstoreRaw', N'U') IS NOT NULL
BEGIN
    PRINT 'Dropping existing stg.CentralSuperstoreRaw to reload cleanly...';
    DROP TABLE stg.CentralSuperstoreRaw;
END
GO

CREATE TABLE stg.CentralSuperstoreRaw
(
    RowID           INT             NULL,
    OrderID         NVARCHAR(20)    NULL,
    OrderDate       NVARCHAR(20)    NULL,   -- text on purpose: cast/validated in load step
    ShipDate        NVARCHAR(20)    NULL,
    ShipMode        NVARCHAR(30)    NULL,
    CustomerID      NVARCHAR(20)    NULL,
    CustomerName    NVARCHAR(100)   NULL,
    Segment         NVARCHAR(30)    NULL,
    Country         NVARCHAR(60)    NULL,
    City            NVARCHAR(60)    NULL,
    State           NVARCHAR(60)    NULL,
    PostalCode      NVARCHAR(10)    NULL,   -- identifier, NOT a number (see design notes)
    Region          NVARCHAR(30)    NULL,
    ProductID       NVARCHAR(30)    NULL,
    Category        NVARCHAR(30)    NULL,
    SubCategory     NVARCHAR(30)    NULL,
    ProductName     NVARCHAR(300)   NULL,
    Sales           NVARCHAR(30)    NULL,
    Quantity        NVARCHAR(10)    NULL,
    Discount        NVARCHAR(10)    NULL,
    Profit          NVARCHAR(30)    NULL
);
GO

PRINT 'stg.CentralSuperstoreRaw created successfully.';
PRINT '01_Database_Setup.sql completed.';
GO

/*
[SSMS SCREENSHOT PLACEHOLDER:
 Object Explorer showing CentralSuperstoreDW database with dw and stg schemas]
*/
