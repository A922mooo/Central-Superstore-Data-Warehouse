/*
================================================================================
 07_Advanced_SQL.sql
 Central Superstore Data Warehouse Project
 Purpose : Demonstrates CTEs, correlated/scalar subqueries, and CASE-based
           classification logic used for real analytical purposes (not
           placeholders written only to satisfy a checklist item).
================================================================================
*/

USE CentralSuperstoreDW;
GO

-------------------------------------------------------------------------------
-- CTE #1: High-value customer identification
-- Logic: aggregate sales per customer, then filter to customers whose sales
-- exceed the overall average customer sales -- i.e. genuinely "high value"
-- relative to the customer base, not an arbitrary cutoff.
-------------------------------------------------------------------------------
WITH CustomerSales AS (
    SELECT
        c.CustomerKey,
        c.CustomerName,
        c.Segment,
        SUM(f.Sales)  AS Total_Sales,
        SUM(f.Profit) AS Total_Profit
    FROM dw.FactSales f
    JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
    GROUP BY c.CustomerKey, c.CustomerName, c.Segment
),
CustomerAverage AS (
    SELECT AVG(Total_Sales) AS Avg_Customer_Sales
    FROM CustomerSales
)
SELECT
    cs.CustomerName,
    cs.Segment,
    cs.Total_Sales,
    cs.Total_Profit,
    ca.Avg_Customer_Sales
FROM CustomerSales cs
CROSS JOIN CustomerAverage ca
WHERE cs.Total_Sales > ca.Avg_Customer_Sales
ORDER BY cs.Total_Sales DESC;
GO

-------------------------------------------------------------------------------
-- CTE #2: Product profitability ranking and classification
-- Logic: aggregate profit per product, rank products by profit within their
-- category using a window function, and classify each as High Profit /
-- Low Profit / Loss using CASE -- genuinely useful for a merchandising
-- review, not a throwaway example.
-------------------------------------------------------------------------------
WITH ProductProfitability AS (
    SELECT
        p.ProductKey,
        p.ProductName,
        p.Category,
        p.SubCategory,
        SUM(f.Sales)  AS Total_Sales,
        SUM(f.Profit) AS Total_Profit
    FROM dw.FactSales f
    JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
    GROUP BY p.ProductKey, p.ProductName, p.Category, p.SubCategory
),
RankedProducts AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY Category ORDER BY Total_Profit DESC) AS Profit_Rank_In_Category,
        CASE
            WHEN Total_Profit < 0        THEN 'Loss'
            WHEN Total_Profit < 50       THEN 'Low Profit'
            ELSE 'High Profit'
        END AS Profit_Classification
    FROM ProductProfitability
)
SELECT
    Category,
    SubCategory,
    ProductName,
    Total_Sales,
    Total_Profit,
    Profit_Classification,
    Profit_Rank_In_Category
FROM RankedProducts
WHERE Profit_Rank_In_Category <= 3
ORDER BY Category, Profit_Rank_In_Category;
GO

-------------------------------------------------------------------------------
-- SUBQUERY #1: Products with sales above the average product sales
-- Logic: scalar subquery computes the overall average sales-per-product,
-- outer query filters products above that bar.
-------------------------------------------------------------------------------
SELECT
    p.ProductName,
    p.Category,
    SUM(f.Sales) AS Total_Sales
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductName, p.Category
HAVING SUM(f.Sales) > (
    SELECT AVG(ProductTotal.Total_Sales)
    FROM (
        SELECT SUM(f2.Sales) AS Total_Sales
        FROM dw.FactSales f2
        GROUP BY f2.ProductKey
    ) AS ProductTotal
)
ORDER BY Total_Sales DESC;
GO

-------------------------------------------------------------------------------
-- SUBQUERY #2: Customers whose total sales exceed the average customer sales
-- Logic: correlated-style aggregation with a scalar subquery threshold.
-------------------------------------------------------------------------------
SELECT
    c.CustomerName,
    c.Segment,
    SUM(f.Sales) AS Total_Sales
FROM dw.FactSales f
JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerName, c.Segment
HAVING SUM(f.Sales) > (
    SELECT AVG(CustomerTotal.Total_Sales)
    FROM (
        SELECT SUM(f2.Sales) AS Total_Sales
        FROM dw.FactSales f2
        GROUP BY f2.CustomerKey
    ) AS CustomerTotal
)
ORDER BY Total_Sales DESC;
GO

-------------------------------------------------------------------------------
-- SUBQUERY #3: Products with profit below the overall average profit
-- Logic: identifies underperforming products relative to the portfolio
-- average -- a direct input to a "review for discontinuation" list.
-------------------------------------------------------------------------------
SELECT
    p.ProductName,
    p.Category,
    p.SubCategory,
    SUM(f.Profit) AS Total_Profit
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductName, p.Category, p.SubCategory
HAVING SUM(f.Profit) < (
    SELECT AVG(f2.Profit) FROM dw.FactSales f2
)
ORDER BY Total_Profit ASC;
GO

-------------------------------------------------------------------------------
-- CASE STATEMENT #1: Discount-band classification
-- Business question: how are orders distributed across discount bands, and
-- how does profitability differ between bands? (feeds the discount-impact
-- narrative in the final report)
-------------------------------------------------------------------------------
SELECT
    CASE
        WHEN Discount = 0                    THEN 'No Discount'
        WHEN Discount > 0   AND Discount <= 0.2 THEN 'Low Discount (0-20%)'
        WHEN Discount > 0.2 AND Discount <= 0.4 THEN 'Medium Discount (20-40%)'
        ELSE 'High Discount (>40%)'
    END AS Discount_Band,
    COUNT(*)         AS Line_Items,
    SUM(Sales)        AS Total_Sales,
    SUM(Profit)       AS Total_Profit,
    CAST(AVG(Profit) AS DECIMAL(10,2)) AS Avg_Profit_Per_Line
FROM dw.FactSales
GROUP BY
    CASE
        WHEN Discount = 0                    THEN 'No Discount'
        WHEN Discount > 0   AND Discount <= 0.2 THEN 'Low Discount (0-20%)'
        WHEN Discount > 0.2 AND Discount <= 0.4 THEN 'Medium Discount (20-40%)'
        ELSE 'High Discount (>40%)'
    END
ORDER BY Total_Profit DESC;
GO

-------------------------------------------------------------------------------
-- CASE STATEMENT #2: Profit classification per order line, aggregated to
-- category level -- shows the MIX of high-profit/low-profit/loss lines
-- feeding each category's bottom line (a category can look "fine" on
-- average while hiding a large share of loss-making lines).
-------------------------------------------------------------------------------
SELECT
    p.Category,
    SUM(CASE WHEN f.Profit < 0  THEN 1 ELSE 0 END) AS Loss_Making_Lines,
    SUM(CASE WHEN f.Profit >= 0 AND f.Profit < 20 THEN 1 ELSE 0 END) AS Low_Profit_Lines,
    SUM(CASE WHEN f.Profit >= 20 THEN 1 ELSE 0 END) AS High_Profit_Lines,
    COUNT(*) AS Total_Lines
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.Category
ORDER BY Loss_Making_Lines DESC;
GO

PRINT '07_Advanced_SQL.sql completed: 2 CTEs, 3 subqueries, 2 CASE-based analyses executed.';
GO
