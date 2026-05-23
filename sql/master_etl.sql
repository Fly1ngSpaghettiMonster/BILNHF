-- Master ETL Script: Runs all ETL steps in sequence
-- Designed to be called with a parameter for the chunk file path:
--   sqlcmd -S "(localdb)\MSSQLLocalDB" -i master_etl.sql -v ChunkFile="D:\...\sales_chunk_1.csv"
USE RetailDW;
GO

------------------------------------------------------
-- ETL JOB 1: Load Sales Chunk into staging
------------------------------------------------------
PRINT '=== ETL JOB 1: Loading sales chunk into staging ===';

TRUNCATE TABLE staging_sales;

DECLARE @sql NVARCHAR(MAX) = N'
BULK INSERT staging_sales
FROM ''' + N'$(ChunkFile)' + N'''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''\n'',
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;

DECLARE @stg_cnt INT;
SELECT @stg_cnt = COUNT(*) FROM staging_sales;
PRINT 'Staging loaded: ' + CAST(@stg_cnt AS NVARCHAR) + ' rows.';
GO

------------------------------------------------------
-- ETL JOB 2: Load Holiday Dimension (only if empty)
------------------------------------------------------
PRINT '=== ETL JOB 2: Loading holiday dimension ===';

IF NOT EXISTS (SELECT 1 FROM dim_holiday)
BEGIN
    IF OBJECT_ID('tempdb..#staging_holidays') IS NOT NULL DROP TABLE #staging_holidays;
    CREATE TABLE #staging_holidays (
        HolidayDate DATE, HolidayName NVARCHAR(100), WeekDay NVARCHAR(20),
        [Month] INT, [Day] INT, [Year] INT
    );

    BULK INSERT #staging_holidays
    FROM '$(HolidayFile)'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = '|',
        ROWTERMINATOR = '\n',
        CODEPAGE = '65001'
    );

    INSERT INTO dim_holiday (HolidayDate, HolidayName, WeekDay, [Month], [Day], [Year])
    SELECT HolidayDate, HolidayName, WeekDay, [Month], [Day], [Year]
    FROM #staging_holidays;

    DROP TABLE #staging_holidays;

    DECLARE @hol_cnt INT;
    SELECT @hol_cnt = COUNT(*) FROM dim_holiday;
    PRINT 'Holidays loaded: ' + CAST(@hol_cnt AS NVARCHAR) + ' rows.';
END
ELSE
    PRINT 'Holidays already loaded, skipping.';
GO

------------------------------------------------------
-- ETL JOB 3: Transform staging -> fact table
------------------------------------------------------
PRINT '=== ETL JOB 3: Transforming staging to fact ===';

-- Populate dim_category (new values only)
INSERT INTO dim_category (Category, SubCategory)
SELECT DISTINCT s.Category, s.SubCategory
FROM staging_sales s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_category dc
    WHERE dc.Category = s.Category AND dc.SubCategory = s.SubCategory
);

-- Update IsHoliday flag in dim_time
UPDATE t
SET t.IsHoliday = 1
FROM dim_time t
INNER JOIN dim_holiday h ON t.FullDate = h.HolidayDate
WHERE t.IsHoliday = 0;

-- Insert into fact_sales
INSERT INTO fact_sales (OrderID, DateKey, CategoryKey, CustomerID, Segment, City, [State], Region, Sales, Quantity, Discount, Profit, IsHoliday)
SELECT
    s.OrderID,
    CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd')),
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
    ISNULL(t.IsHoliday, 0)
FROM staging_sales s
INNER JOIN dim_category dc ON s.Category = dc.Category AND s.SubCategory = dc.SubCategory
LEFT JOIN dim_time t ON CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd')) = t.DateKey
WHERE NOT EXISTS (
    SELECT 1 FROM fact_sales f
    WHERE f.OrderID = s.OrderID
      AND f.DateKey = CONVERT(INT, FORMAT(TRY_CAST(s.OrderDate AS DATE), 'yyyyMMdd'))
      AND f.Sales = s.Sales
      AND f.CustomerID = s.CustomerID
);

DECLARE @fact_cnt INT;
SELECT @fact_cnt = COUNT(*) FROM fact_sales;
PRINT 'Fact table total: ' + CAST(@fact_cnt AS NVARCHAR) + ' rows.';

-- Clear staging
TRUNCATE TABLE staging_sales;
GO

------------------------------------------------------
-- ETL JOB 4: Aggregate Monthly
------------------------------------------------------
PRINT '=== ETL JOB 4: Monthly aggregation ===';

TRUNCATE TABLE agg_monthly_sales;
INSERT INTO agg_monthly_sales ([Year], [Month], Region, Category, TotalSales, TotalProfit, OrderCount)
SELECT t.[Year], t.[Month], f.Region, c.Category,
       SUM(f.Sales), SUM(f.Profit), COUNT(DISTINCT f.OrderID)
FROM fact_sales f
INNER JOIN dim_time t ON f.DateKey = t.DateKey
INNER JOIN dim_category c ON f.CategoryKey = c.CategoryKey
GROUP BY t.[Year], t.[Month], f.Region, c.Category;

DECLARE @agg_m INT;
SELECT @agg_m = COUNT(*) FROM agg_monthly_sales;
PRINT 'Monthly aggregation: ' + CAST(@agg_m AS NVARCHAR) + ' rows.';
GO

------------------------------------------------------
-- ETL JOB 5: Aggregate Category
------------------------------------------------------
PRINT '=== ETL JOB 5: Category aggregation ===';

TRUNCATE TABLE agg_category_sales;
INSERT INTO agg_category_sales (Category, SubCategory, TotalSales, TotalProfit, AvgDiscount, TotalQuantity)
SELECT c.Category, c.SubCategory,
       SUM(f.Sales), SUM(f.Profit), AVG(f.Discount), SUM(f.Quantity)
FROM fact_sales f
INNER JOIN dim_category c ON f.CategoryKey = c.CategoryKey
GROUP BY c.Category, c.SubCategory;

DECLARE @agg_c INT;
SELECT @agg_c = COUNT(*) FROM agg_category_sales;
PRINT 'Category aggregation: ' + CAST(@agg_c AS NVARCHAR) + ' rows.';
GO

PRINT '=== ETL RUN COMPLETE ===';
