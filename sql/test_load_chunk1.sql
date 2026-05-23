-- Test: Load chunk 1 into staging via BULK INSERT
USE RetailDW;
GO

BULK INSERT staging_sales
FROM 'D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF\data\split\sales_chunk_1.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV'
);
GO

DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM staging_sales;
PRINT 'Staging loaded: ' + CAST(@cnt AS NVARCHAR) + ' rows.';
