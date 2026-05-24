USE RetailDW;
GO

------------------------------------------------------
-- STAGING TABLE (raw CSV data lands here)
------------------------------------------------------
IF OBJECT_ID('staging_sales', 'U') IS NOT NULL DROP TABLE staging_sales;
CREATE TABLE staging_sales (
    RowID           INT,
    OrderID         NVARCHAR(50),
    OrderDate       NVARCHAR(20),
    ShipDate        NVARCHAR(20),
    ShipMode        NVARCHAR(50),
    CustomerID      NVARCHAR(50),
    CustomerName    NVARCHAR(100),
    Segment         NVARCHAR(50),
    Country         NVARCHAR(50),
    City            NVARCHAR(100),
    [State]         NVARCHAR(50),
    PostalCode      NVARCHAR(20),
    Region          NVARCHAR(50),
    ProductID       NVARCHAR(50),
    Category        NVARCHAR(50),
    SubCategory     NVARCHAR(50),
    ProductName     NVARCHAR(300),
    Sales           DECIMAL(10,2),
    Quantity        INT,
    Discount        DECIMAL(5,2),
    Profit          DECIMAL(10,2)
);
GO

------------------------------------------------------
-- DIMENSION: Holiday
------------------------------------------------------
IF OBJECT_ID('dim_holiday', 'U') IS NOT NULL DROP TABLE dim_holiday;
CREATE TABLE dim_holiday (
    HolidayKey      INT IDENTITY(1,1) PRIMARY KEY,
    HolidayDate     DATE,
    HolidayName     NVARCHAR(100),
    WeekDay         NVARCHAR(20),
    [Month]         INT,
    [Day]           INT,
    [Year]          INT
);
GO

------------------------------------------------------
-- DIMENSION: Category
------------------------------------------------------
IF OBJECT_ID('dim_category', 'U') IS NOT NULL DROP TABLE dim_category;
CREATE TABLE dim_category (
    CategoryKey     INT IDENTITY(1,1) PRIMARY KEY,
    Category        NVARCHAR(50),
    SubCategory     NVARCHAR(50)
);
GO

------------------------------------------------------
-- DIMENSION: Time
------------------------------------------------------
IF OBJECT_ID('dim_time', 'U') IS NOT NULL DROP TABLE dim_time;
CREATE TABLE dim_time (
    DateKey         INT PRIMARY KEY,        -- YYYYMMDD format
    FullDate        DATE,
    [Year]          INT,
    [Month]         INT,
    [Week]          INT,
    [DayOfWeek]     INT,
    [DayName]       NVARCHAR(20),
    [MonthName]     NVARCHAR(20),
    IsHoliday       BIT DEFAULT 0
);
GO

------------------------------------------------------
-- FACT TABLE: Sales
------------------------------------------------------
IF OBJECT_ID('fact_sales', 'U') IS NOT NULL DROP TABLE fact_sales;
CREATE TABLE fact_sales (
    SalesKey        INT IDENTITY(1,1) PRIMARY KEY,
    OrderID         NVARCHAR(50),
    DateKey         INT,
    CategoryKey     INT,
    CustomerID      NVARCHAR(50),
    Segment         NVARCHAR(50),
    City            NVARCHAR(100),
    [State]         NVARCHAR(50),
    Region          NVARCHAR(50),
    Sales           DECIMAL(10,2),
    Quantity        INT,
    Discount        DECIMAL(5,2),
    Profit          DECIMAL(10,2),
    IsHoliday       BIT DEFAULT 0,
    CONSTRAINT FK_fact_sales_time FOREIGN KEY (DateKey) REFERENCES dim_time(DateKey),
    CONSTRAINT FK_fact_sales_category FOREIGN KEY (CategoryKey) REFERENCES dim_category(CategoryKey)
);
GO

------------------------------------------------------
-- AGGREGATED: Monthly Sales
------------------------------------------------------
IF OBJECT_ID('agg_monthly_sales', 'U') IS NOT NULL DROP TABLE agg_monthly_sales;
CREATE TABLE agg_monthly_sales (
    [Year]          INT,
    [Month]         INT,
    Region          NVARCHAR(50),
    Category        NVARCHAR(50),
    TotalSales      DECIMAL(12,2),
    TotalProfit     DECIMAL(12,2),
    OrderCount      INT
);
GO

------------------------------------------------------
-- AGGREGATED: Category Sales
------------------------------------------------------
IF OBJECT_ID('agg_category_sales', 'U') IS NOT NULL DROP TABLE agg_category_sales;
CREATE TABLE agg_category_sales (
    Category        NVARCHAR(50),
    SubCategory     NVARCHAR(50),
    TotalSales      DECIMAL(12,2),
    TotalProfit     DECIMAL(12,2),
    AvgDiscount     DECIMAL(5,2),
    TotalQuantity   INT
);
GO

PRINT 'All tables created successfully.';
