-- Test: Load holidays into dim_holiday via temp staging table
USE RetailDW;
GO

-- Temp staging table matching the CSV layout exactly
IF OBJECT_ID('tempdb..#staging_holidays') IS NOT NULL DROP TABLE #staging_holidays;
CREATE TABLE #staging_holidays (
    HolidayDate     DATE,
    HolidayName     NVARCHAR(100),
    WeekDay         NVARCHAR(20),
    [Month]         INT,
    [Day]           INT,
    [Year]          INT
);

BULK INSERT #staging_holidays
FROM 'D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF\data\holidays\us_holidays_clean.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

DELETE FROM dim_holiday;

INSERT INTO dim_holiday (HolidayDate, HolidayName, WeekDay, [Month], [Day], [Year])
SELECT HolidayDate, HolidayName, WeekDay, [Month], [Day], [Year]
FROM #staging_holidays;

DROP TABLE #staging_holidays;
GO

DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM dim_holiday;
PRINT 'Holidays loaded: ' + CAST(@cnt AS NVARCHAR) + ' rows.';
SELECT TOP 5 * FROM dim_holiday;
