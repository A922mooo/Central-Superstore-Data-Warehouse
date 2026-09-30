/*
================================================================================
 03_Create_Fact.sql
 Central Superstore Data Warehouse Project
 Purpose : Create the FactSales table.

 GRAIN DECLARATION (read this before touching the table):
   One row in FactSales = one PRODUCT LINE within one ORDER
   (i.e. one row of the source Excel sheet / one Row ID).
   Order ID is therefore expected to repeat across multiple fact rows
   whenever an order contains more than one product line. Do not aggregate
   this away when loading -- 2,323 source rows must yield 2,323 fact rows.

 Financial columns use DECIMAL, never FLOAT, to avoid floating-point drift
 in Sales/Profit aggregations.
 Safe to re-run: YES.
================================================================================
*/

USE CentralSuperstoreDW;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dw.FactSales', N'U') IS NOT NULL DROP TABLE dw.FactSales;
GO

CREATE TABLE dw.FactSales
(
    SalesKey        BIGINT IDENTITY(1,1)   NOT NULL,
    SourceRowID     INT                    NOT NULL,   -- Row ID from the Excel source (traceability)
    OrderID         NVARCHAR(20)           NOT NULL,   -- intentionally repeats across order-line rows
    OrderDateKey    INT                    NOT NULL,
    ShipDateKey     INT                    NOT NULL,
    CustomerKey     INT                    NOT NULL,
    ProductKey      INT                    NOT NULL,
    LocationKey     INT                    NOT NULL,
    ShipModeKey     INT                    NOT NULL,
    Quantity        INT                    NOT NULL,
    Sales           DECIMAL(12,4)          NOT NULL,
    Discount        DECIMAL(5,4)           NOT NULL,
    Profit          DECIMAL(12,4)          NOT NULL,

    CONSTRAINT PK_FactSales PRIMARY KEY CLUSTERED (SalesKey),
    CONSTRAINT UQ_FactSales_SourceRowID UNIQUE (SourceRowID),

    CONSTRAINT FK_FactSales_OrderDate  FOREIGN KEY (OrderDateKey) REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FactSales_ShipDate   FOREIGN KEY (ShipDateKey)  REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FactSales_Customer   FOREIGN KEY (CustomerKey)  REFERENCES dw.DimCustomer (CustomerKey),
    CONSTRAINT FK_FactSales_Product    FOREIGN KEY (ProductKey)   REFERENCES dw.DimProduct (ProductKey),
    CONSTRAINT FK_FactSales_Location   FOREIGN KEY (LocationKey)  REFERENCES dw.DimLocation (LocationKey),
    CONSTRAINT FK_FactSales_ShipMode   FOREIGN KEY (ShipModeKey)  REFERENCES dw.DimShipMode (ShipModeKey),

    -- Basic data-integrity guards (business rules confirmed against the
    -- actual source data during profiling: Quantity > 0 and 0 <= Discount <= 1
    -- held for all 2,323 rows).
    CONSTRAINT CK_FactSales_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_FactSales_Discount CHECK (Discount >= 0 AND Discount <= 1),
    CONSTRAINT CK_FactSales_Sales    CHECK (Sales >= 0)
);
GO

PRINT 'dw.FactSales created successfully with all foreign keys and check constraints.';
PRINT '03_Create_Fact.sql completed.';
GO

/*
[SSMS SCREENSHOT PLACEHOLDER:
 Object Explorer -> dw.FactSales -> Keys, showing all 6 foreign keys]
*/
