-- Reset all data in RetailDW to start fresh
USE RetailDW;
GO

DELETE FROM fact_sales;
DELETE FROM agg_monthly_sales;
DELETE FROM agg_category_sales;
DELETE FROM dim_category;
DELETE FROM dim_holiday;
DELETE FROM dim_time;

-- Re-populate dim_time
;WITH DateRange AS (
    SELECT CAST('2014-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt)
    FROM DateRange
    WHERE dt < '2018-12-31'
)
INSERT INTO dim_time (DateKey, FullDate, [Year], [Month], [Week], [DayOfWeek], [DayName], [MonthName], IsHoliday)
SELECT
    CONVERT(INT, FORMAT(dt, 'yyyyMMdd')),
    dt,
    YEAR(dt),
    MONTH(dt),
    DATEPART(WEEK, dt),
    DATEPART(WEEKDAY, dt),
    DATENAME(WEEKDAY, dt),
    DATENAME(MONTH, dt),
    0
FROM DateRange
OPTION (MAXRECURSION 2000);
GO

PRINT 'Database reset complete.';
