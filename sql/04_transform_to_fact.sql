-- Phase 3 (ETL Job 3): Transform staging data into fact + dimension tables
USE RetailDW;
GO

-- Step 1: Populate dim_category from staging (insert only new combinations)
INSERT INTO dim_category (Category, SubCategory)
SELECT DISTINCT s.Category, s.SubCategory
FROM staging_sales s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_category dc
    WHERE dc.Category = s.Category AND dc.SubCategory = s.SubCategory
);
GO

-- Step 2: Update dim_time.IsHoliday flag from dim_holiday
UPDATE t
SET t.IsHoliday = 1
FROM dim_time t
INNER JOIN dim_holiday h ON t.FullDate = h.HolidayDate
WHERE t.IsHoliday = 0;
GO

-- Step 3: Insert into fact_sales from staging (avoid duplicates by RowID/OrderID check)
INSERT INTO fact_sales (OrderID, DateKey, CategoryKey, CustomerID, Segment, City, [State], Region, Sales, Quantity, Discount, Profit, IsHoliday)
SELECT
    s.OrderID,
    CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd'))  AS DateKey,
    dc.CategoryKey,
    s.CustomerID,
    s.Segment,
    s.City,
    s.[State],
    s.Region,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit,
    ISNULL(t.IsHoliday, 0) AS IsHoliday
FROM staging_sales s
INNER JOIN dim_category dc ON s.Category = dc.Category AND s.SubCategory = dc.SubCategory
LEFT JOIN dim_time t ON CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd')) = t.DateKey
WHERE NOT EXISTS (
    SELECT 1 FROM fact_sales f WHERE f.OrderID = s.OrderID
        AND f.DateKey = CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd'))
        AND f.Sales = s.Sales
        AND f.CustomerID = s.CustomerID
);
GO

-- Step 4: Clear staging after successful load
TRUNCATE TABLE staging_sales;
GO

PRINT 'Transform to fact complete.';
