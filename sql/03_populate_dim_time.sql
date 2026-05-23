-- Phase 2: Populate dim_time with all dates from 2014-01-01 to 2018-12-31
-- Covers the Superstore dataset date range
USE RetailDW;
GO

DELETE FROM dim_time;

;WITH DateRange AS (
    SELECT CAST('2014-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt)
    FROM DateRange
    WHERE dt < '2018-12-31'
)
INSERT INTO dim_time (DateKey, FullDate, [Year], [Month], [Week], [DayOfWeek], [DayName], [MonthName], IsHoliday)
SELECT
    CONVERT(INT, FORMAT(dt, 'yyyyMMdd'))    AS DateKey,
    dt                                       AS FullDate,
    YEAR(dt)                                 AS [Year],
    MONTH(dt)                                AS [Month],
    DATEPART(WEEK, dt)                       AS [Week],
    DATEPART(WEEKDAY, dt)                    AS [DayOfWeek],
    DATENAME(WEEKDAY, dt)                    AS [DayName],
    DATENAME(MONTH, dt)                      AS [MonthName],
    0                                        AS IsHoliday
FROM DateRange
OPTION (MAXRECURSION 2000);
GO

DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM dim_time;
PRINT 'dim_time populated with ' + CAST(@cnt AS NVARCHAR) + ' rows.';
