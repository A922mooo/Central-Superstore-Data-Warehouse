/*
================================================================================
 02_Create_Dimensions.sql
 Central Superstore Data Warehouse Project
 Purpose : Create the five dimension tables of the star schema.
 Design decisions (see documentation/Project_Report for full rationale):
   - Surrogate keys (IDENTITY) are used for every dimension so the warehouse
     is insulated from any quirks in the source's natural keys.
   - PostalCode is stored as NVARCHAR because it is an identifier, not a
     quantity (leading zeros and non-arithmetic use).
   - DimProduct is keyed on the SURROGATE key, not on Product ID alone,
     because profiling found 16 Product IDs in the source that map to more
     than one Product Name (a known data-quality quirk of this dataset).
     ProductID is kept as a descriptive attribute, not a unique constraint.
   - No FLOAT is used anywhere financial figures are involved.
 Safe to re-run: YES.
================================================================================
*/

USE CentralSuperstoreDW;
GO
SET NOCOUNT ON;
GO

-------------------------------------------------------------------------------
-- DimCustomer
-------------------------------------------------------------------------------
IF OBJECT_ID(N'dw.DimCustomer', N'U') IS NOT NULL DROP TABLE dw.DimCustomer;
GO
CREATE TABLE dw.DimCustomer
(
    CustomerKey     INT IDENTITY(1,1)   NOT NULL,
    CustomerID      NVARCHAR(20)        NOT NULL,
    CustomerName    NVARCHAR(100)       NOT NULL,
    Segment         NVARCHAR(30)        NOT NULL,
    CONSTRAINT PK_DimCustomer PRIMARY KEY CLUSTERED (CustomerKey),
    CONSTRAINT UQ_DimCustomer_CustomerID UNIQUE (CustomerID)
);
GO

-------------------------------------------------------------------------------
-- DimProduct
-------------------------------------------------------------------------------
IF OBJECT_ID(N'dw.DimProduct', N'U') IS NOT NULL DROP TABLE dw.DimProduct;
GO
CREATE TABLE dw.DimProduct
(
    ProductKey      INT IDENTITY(1,1)   NOT NULL,
    ProductID       NVARCHAR(30)        NOT NULL,
    ProductName     NVARCHAR(300)       NOT NULL,
    Category        NVARCHAR(30)        NOT NULL,
    SubCategory     NVARCHAR(30)        NOT NULL,
    CONSTRAINT PK_DimProduct PRIMARY KEY CLUSTERED (ProductKey),
    -- Composite natural key: source data shows ProductID is not always
    -- unique to a single ProductName, so uniqueness is enforced on the
    -- combination actually observed in the data.
    CONSTRAINT UQ_DimProduct_Natural UNIQUE (ProductID, ProductName, Category, SubCategory)
);
GO

-------------------------------------------------------------------------------
-- DimLocation
-------------------------------------------------------------------------------
IF OBJECT_ID(N'dw.DimLocation', N'U') IS NOT NULL DROP TABLE dw.DimLocation;
GO
CREATE TABLE dw.DimLocation
(
    LocationKey     INT IDENTITY(1,1)   NOT NULL,
    Country         NVARCHAR(60)        NOT NULL,
    City            NVARCHAR(60)        NOT NULL,
    State           NVARCHAR(60)        NOT NULL,
    PostalCode      NVARCHAR(10)        NOT NULL,
    Region          NVARCHAR(30)        NOT NULL,
    CONSTRAINT PK_DimLocation PRIMARY KEY CLUSTERED (LocationKey),
    CONSTRAINT UQ_DimLocation_Natural UNIQUE (City, State, PostalCode, Region)
);
GO

-------------------------------------------------------------------------------
-- DimShipMode
-------------------------------------------------------------------------------
IF OBJECT_ID(N'dw.DimShipMode', N'U') IS NOT NULL DROP TABLE dw.DimShipMode;
GO
CREATE TABLE dw.DimShipMode
(
    ShipModeKey     INT IDENTITY(1,1)   NOT NULL,
    ShipMode        NVARCHAR(30)        NOT NULL,
    CONSTRAINT PK_DimShipMode PRIMARY KEY CLUSTERED (ShipModeKey),
    CONSTRAINT UQ_DimShipMode_ShipMode UNIQUE (ShipMode)
);
GO

-------------------------------------------------------------------------------
-- DimDate
-- Populated dynamically in 04_Load_Data.sql from MIN/MAX(OrderDate,ShipDate)
-- found in the staging table -- the range is NOT hardcoded here.
-------------------------------------------------------------------------------
IF OBJECT_ID(N'dw.DimDate', N'U') IS NOT NULL DROP TABLE dw.DimDate;
GO
CREATE TABLE dw.DimDate
(
    DateKey         INT             NOT NULL,   -- format YYYYMMDD
    FullDate        DATE            NOT NULL,
    DayNumber       TINYINT         NOT NULL,
    DayName         NVARCHAR(10)    NOT NULL,
    MonthNumber     TINYINT         NOT NULL,
    MonthName       NVARCHAR(10)    NOT NULL,
    QuarterNumber   TINYINT         NOT NULL,
    YearNumber      SMALLINT        NOT NULL,
    WeekNumber      TINYINT         NOT NULL,
    IsWeekend       BIT             NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateKey),
    CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate)
);
GO

PRINT 'All dimension tables created successfully.';
PRINT '02_Create_Dimensions.sql completed.';
GO

/*
[SSMS SCREENSHOT PLACEHOLDER:
 Object Explorer -> CentralSuperstoreDW -> Tables, showing
 dw.DimCustomer, dw.DimProduct, dw.DimLocation, dw.DimShipMode, dw.DimDate]
*/
