-- Phase 3 (ETL Job 5): Aggregate category sales
USE RetailDW;
GO

TRUNCATE TABLE agg_category_sales;

INSERT INTO agg_category_sales (Category, SubCategory, TotalSales, TotalProfit, AvgDiscount, TotalQuantity)
SELECT
    c.Category,
    c.SubCategory,
    SUM(f.Sales)        AS TotalSales,
    SUM(f.Profit)       AS TotalProfit,
    AVG(f.Discount)     AS AvgDiscount,
    SUM(f.Quantity)     AS TotalQuantity
FROM fact_sales f
INNER JOIN dim_category c ON f.CategoryKey = c.CategoryKey
GROUP BY c.Category, c.SubCategory;
GO

DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM agg_category_sales;
PRINT 'Category aggregation complete: ' + CAST(@cnt AS NVARCHAR) + ' rows.';
