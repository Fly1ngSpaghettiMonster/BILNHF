-- Phase 3 (ETL Job 4): Aggregate monthly sales
USE RetailDW;
GO

TRUNCATE TABLE agg_monthly_sales;

INSERT INTO agg_monthly_sales ([Year], [Month], Region, Category, TotalSales, TotalProfit, OrderCount)
SELECT
    t.[Year],
    t.[Month],
    f.Region,
    c.Category,
    SUM(f.Sales)                AS TotalSales,
    SUM(f.Profit)               AS TotalProfit,
    COUNT(DISTINCT f.OrderID)   AS OrderCount
FROM fact_sales f
INNER JOIN dim_time t ON f.DateKey = t.DateKey
INNER JOIN dim_category c ON f.CategoryKey = c.CategoryKey
GROUP BY t.[Year], t.[Month], f.Region, c.Category;
GO

DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM agg_monthly_sales;
PRINT 'Monthly aggregation complete: ' + CAST(@cnt AS NVARCHAR) + ' rows.';
