/*
================================================================================
 06_Analytical_Queries.sql
 Central Superstore Data Warehouse Project
 Scope   : All results below describe the CENTRAL REGION only.
 Purpose : 20 core analytical queries covering KPIs, sales trends, product
           analysis, customer analysis, geographic analysis, and shipping
           analysis. Each query is numbered and documented with its
           business question and purpose.
================================================================================
*/

USE CentralSuperstoreDW;
GO

-------------------------------------------------------------------------------
-- CATEGORY A: OVERALL SALES KPIs
-------------------------------------------------------------------------------

-- Query 1: Total Sales
-- Business question: What is total revenue generated in the Central Region?
SELECT SUM(Sales) AS Total_Sales
FROM dw.FactSales;

-- Query 2: Total Profit
-- Business question: What is the total profit generated in the Central Region?
SELECT SUM(Profit) AS Total_Profit
FROM dw.FactSales;

-- Query 3: Total Quantity Sold
-- Business question: How many total units were sold?
SELECT SUM(Quantity) AS Total_Quantity
FROM dw.FactSales;

-- Query 4: Average Discount
-- Business question: What discount level is typically applied?
SELECT AVG(Discount) AS Average_Discount
FROM dw.FactSales;

-- Query 5: Number of Distinct Orders and Overall Profit Margin
-- Business question: How many orders were placed, and what is the
-- blended profit margin (Profit / Sales) across all order lines?
-- Purpose: headline KPI card values for the dashboard.
SELECT
    COUNT(DISTINCT OrderID)                AS Total_Orders,
    SUM(Sales)                             AS Total_Sales,
    SUM(Profit)                            AS Total_Profit,
    CAST(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0) AS DECIMAL(6,2)) AS Profit_Margin_Pct
FROM dw.FactSales;
GO

-------------------------------------------------------------------------------
-- CATEGORY B: SALES TRENDS
-------------------------------------------------------------------------------

-- Query 6: Sales and Profit by Year
-- Business question: How has revenue and profit evolved year over year?
SELECT
    d.YearNumber,
    SUM(f.Sales)    AS Total_Sales,
    SUM(f.Profit)   AS Total_Profit,
    SUM(f.Quantity) AS Total_Quantity
FROM dw.FactSales f
JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
GROUP BY d.YearNumber
ORDER BY d.YearNumber;

-- Query 7: Monthly Sales Trend (chronological, across all years)
-- Business question: What does the month-by-month sales trajectory look like?
-- Purpose: feeds the "Sales Trend" line chart.
SELECT
    d.YearNumber,
    d.MonthNumber,
    d.MonthName,
    SUM(f.Sales)  AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
GROUP BY d.YearNumber, d.MonthNumber, d.MonthName
ORDER BY d.YearNumber, d.MonthNumber;

-- Query 8: Sales by Quarter
-- Business question: Is there a seasonal / quarterly pattern in sales?
SELECT
    d.YearNumber,
    d.QuarterNumber,
    SUM(f.Sales)  AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
GROUP BY d.YearNumber, d.QuarterNumber
ORDER BY d.YearNumber, d.QuarterNumber;

-- Query 9: Year-over-Year Sales Growth (%)
-- Business question: What was the percentage growth in sales each year
-- versus the prior year?
-- Purpose: demonstrates window functions (LAG) for trend analysis.
SELECT
    YearNumber,
    Total_Sales,
    LAG(Total_Sales) OVER (ORDER BY YearNumber)               AS Prior_Year_Sales,
    CAST((Total_Sales - LAG(Total_Sales) OVER (ORDER BY YearNumber))
        * 100.0 / NULLIF(LAG(Total_Sales) OVER (ORDER BY YearNumber), 0) AS DECIMAL(6,2)) AS YoY_Growth_Pct
FROM (
    SELECT d.YearNumber, SUM(f.Sales) AS Total_Sales
    FROM dw.FactSales f
    JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
    GROUP BY d.YearNumber
) AS YearlySales;

-- Query 10: Average Order Value by Year
-- Business question: Is the average order growing or shrinking over time?
SELECT
    d.YearNumber,
    CAST(SUM(f.Sales) * 1.0 / COUNT(DISTINCT f.OrderID) AS DECIMAL(10,2)) AS Avg_Order_Value
FROM dw.FactSales f
JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
GROUP BY d.YearNumber
ORDER BY d.YearNumber;
GO

-------------------------------------------------------------------------------
-- CATEGORY C: PRODUCT ANALYSIS
-------------------------------------------------------------------------------

-- Query 11: Top 10 Products by Sales
-- Business question: Which products generate the most revenue?
-- JOIN: FactSales + DimProduct
SELECT TOP 10
    p.ProductName,
    p.Category,
    p.SubCategory,
    SUM(f.Sales) AS Total_Sales
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductName, p.Category, p.SubCategory
ORDER BY Total_Sales DESC;

-- Query 12: Top 10 Products by Profit
-- Business question: Which products contribute the most profit?
-- JOIN: FactSales + DimProduct
SELECT TOP 10
    p.ProductName,
    p.Category,
    p.SubCategory,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductName, p.Category, p.SubCategory
ORDER BY Total_Profit DESC;

-- Query 13: Loss-Making Products (bottom 10 by profit)
-- Business question: Which products are actively losing money and by how much?
SELECT TOP 10
    p.ProductName,
    p.Category,
    p.SubCategory,
    SUM(f.Sales)  AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductName, p.Category, p.SubCategory
HAVING SUM(f.Profit) < 0
ORDER BY Total_Profit ASC;

-- Query 14: Sales and Profit by Category
-- Business question: Which product categories perform best overall?
SELECT
    p.Category,
    SUM(f.Sales)    AS Total_Sales,
    SUM(f.Profit)   AS Total_Profit,
    CAST(SUM(f.Profit) * 100.0 / NULLIF(SUM(f.Sales), 0) AS DECIMAL(6,2)) AS Profit_Margin_Pct
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.Category
ORDER BY Total_Sales DESC;

-- Query 15: Profit by Sub-Category
-- Business question: Within each category, which sub-categories drive
-- or drag profitability?
SELECT
    p.Category,
    p.SubCategory,
    SUM(f.Sales)  AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.Category, p.SubCategory
ORDER BY Total_Profit ASC;
GO

-------------------------------------------------------------------------------
-- CATEGORY D: CUSTOMER ANALYSIS
-------------------------------------------------------------------------------

-- Query 16: Top 10 Customers by Sales
-- Business question: Who are the highest-revenue customers?
-- JOIN: FactSales + DimCustomer
SELECT TOP 10
    c.CustomerName,
    c.Segment,
    SUM(f.Sales) AS Total_Sales
FROM dw.FactSales f
JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerName, c.Segment
ORDER BY Total_Sales DESC;

-- Query 17: Top 10 Customers by Profit
-- Business question: Who are the most profitable customers to serve?
SELECT TOP 10
    c.CustomerName,
    c.Segment,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerName, c.Segment
ORDER BY Total_Profit DESC;

-- Query 18: Sales and Profit by Customer Segment
-- Business question: Which customer segment (Consumer / Corporate / Home
-- Office) is most valuable?
SELECT
    c.Segment,
    COUNT(DISTINCT f.OrderID)  AS Orders,
    SUM(f.Sales)               AS Total_Sales,
    SUM(f.Profit)              AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.Segment
ORDER BY Total_Sales DESC;
GO

-------------------------------------------------------------------------------
-- CATEGORY E: GEOGRAPHIC ANALYSIS
-------------------------------------------------------------------------------

-- Query 19: Sales and Profit by State
-- Business question: Which states within the Central Region drive the
-- most revenue and profit?
-- JOIN: FactSales + DimLocation
SELECT
    l.State,
    SUM(f.Sales)  AS Total_Sales,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimLocation l ON f.LocationKey = l.LocationKey
GROUP BY l.State
ORDER BY Total_Sales DESC;

-- Query 20: Top 10 Cities by Sales
-- Business question: Which cities are the biggest local markets?
SELECT TOP 10
    l.City,
    l.State,
    SUM(f.Sales) AS Total_Sales
FROM dw.FactSales f
JOIN dw.DimLocation l ON f.LocationKey = l.LocationKey
GROUP BY l.City, l.State
ORDER BY Total_Sales DESC;
GO

-------------------------------------------------------------------------------
-- CATEGORY F: SHIPPING ANALYSIS
-------------------------------------------------------------------------------

-- Query 21: Sales and Order Count by Ship Mode
-- Business question: Which shipping method is used most, and how does it
-- relate to revenue?
-- JOIN: FactSales + DimShipMode
SELECT
    sm.ShipMode,
    COUNT(DISTINCT f.OrderID) AS Orders,
    SUM(f.Sales)              AS Total_Sales,
    SUM(f.Profit)             AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimShipMode sm ON f.ShipModeKey = sm.ShipModeKey
GROUP BY sm.ShipMode
ORDER BY Total_Sales DESC;

-- Query 22: Average Shipping Duration (days) by Ship Mode
-- Business question: How many days, on average, does each shipping method
-- actually take, measured from the two date dimensions?
-- JOIN: FactSales + DimDate (twice, once per role: order date and ship date)
SELECT
    sm.ShipMode,
    AVG(DATEDIFF(DAY, od.FullDate, sd.FullDate) * 1.0) AS Avg_Shipping_Days
FROM dw.FactSales f
JOIN dw.DimShipMode sm ON f.ShipModeKey = sm.ShipModeKey
JOIN dw.DimDate od ON f.OrderDateKey = od.DateKey
JOIN dw.DimDate sd ON f.ShipDateKey = sd.DateKey
GROUP BY sm.ShipMode
ORDER BY Avg_Shipping_Days;
GO

PRINT '06_Analytical_Queries.sql completed: 22 analytical queries executed above.';
GO
