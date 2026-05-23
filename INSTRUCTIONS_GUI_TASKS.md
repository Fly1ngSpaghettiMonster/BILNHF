# Remaining GUI Tasks — Step-by-Step Instructions

These tasks must be done in their respective GUIs (Visual Studio, PowerBI, Task Scheduler).

---

## Option A: SSIS Packages in Visual Studio (Recommended for full marks)

### Setup
1. Open Visual Studio → **New Project** → search "Integration Services" → **Integration Services Project**
2. Name: `RetailDW_ETL`, Location: `D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF\ssis`

### Package 1: `LoadSalesChunk.dtsx`
1. In Control Flow, drag a **Data Flow Task**
2. Double-click it → In Data Flow:
   - Add **Flat File Source** → New connection → browse to `data\split\sales_chunk_1.csv`
     - Set columns: check all columns match staging_sales table
   - Add **OLE DB Destination** → New connection → Server: `(localdb)\MSSQLLocalDB`, Database: `RetailDW`
     - Table: `staging_sales`
     - Map columns (Row ID→RowID, Order ID→OrderID, etc.)
   - Connect Source → Destination (green arrow)
3. To make it parameterized: create a **Project Parameter** called `ChunkFilePath`, set the Flat File connection's `ConnectionString` to an Expression using this parameter

### Package 2: `LoadHolidayDimension.dtsx`
1. Same pattern as Package 1 but:
   - Flat File Source → `data\holidays\us_holidays_clean.csv` with pipe `|` delimiter
   - OLE DB Destination → `dim_holiday` table
   - Add a **Precedence Constraint** with expression: check if dim_holiday is empty first
     - Or add an **Execute SQL Task** before the Data Flow that checks `SELECT COUNT(*) FROM dim_holiday` and skips if > 0

### Package 3: `TransformToFact.dtsx`
1. Add 4 **Execute SQL Task** items in sequence:
   - Task 1: Insert new categories → paste SQL from `sql\04_transform_to_fact.sql` (Step 1 section)
   - Task 2: Update IsHoliday flags → paste SQL (Step 2)
   - Task 3: Insert into fact_sales → paste SQL (Step 3)
   - Task 4: Truncate staging → `TRUNCATE TABLE staging_sales`
2. Connect them with green arrows in sequence

### Package 4: `AggregateMonthly.dtsx`
1. Single **Execute SQL Task**
2. Paste the SQL from `sql\05_aggregate_monthly.sql`

### Package 5: `AggregateCategory.dtsx`
1. Single **Execute SQL Task**
2. Paste the SQL from `sql\06_aggregate_category.sql`

### Master Package: `MasterETL.dtsx` (optional)
1. Add 5 **Execute Package Task** items in sequence, pointing to each of the 5 packages above

---

## Option B: Skip SSIS, Use Batch Script Only (Simpler)

The `run_etl.bat` + `sql\master_etl.sql` already implements the full ETL pipeline with all 5 jobs.
You can present this as your ETL solution with sqlcmd as the engine.
This is simpler but may score slightly lower on the "ETL motor" requirement.

---

## Windows Task Scheduler Setup

1. Open **Task Scheduler** (Win+R → `taskschd.msc`)
2. Click **Create Basic Task**
3. Name: `RetailDW Incremental ETL`
4. Trigger: **Daily** → set time, check "Repeat task every **1 minute** for a duration of **5 minutes**"
   (This runs 4 times = loads all 4 chunks, then stops)
5. Action: **Start a program**
   - Program: `cmd.exe`
   - Arguments: `/c "D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF\run_etl.bat"`
   - Start in: `D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF`
6. Finish

### Demo Flow
1. Reset DB: `sqlcmd -S "(localdb)\MSSQLLocalDB" -i "sql\reset_database.sql"`
2. Delete tracker: `del etl_tracker.txt`
3. Enable the scheduled task
4. Watch in SSMS as data grows: `SELECT COUNT(*) FROM fact_sales` after each minute
5. Refresh PowerBI to show updated reports

---

## PowerBI Reports

### Connect to Database
1. Open **PowerBI Desktop** → **Get Data** → **SQL Server**
2. Server: `(localdb)\MSSQLLocalDB`
3. Database: `RetailDW`
4. Select tables: `fact_sales`, `dim_time`, `dim_holiday`, `dim_category`, `agg_monthly_sales`, `agg_category_sales`
5. Click **Load**

### Set Up Relationships (Model View)
- `fact_sales.DateKey` → `dim_time.DateKey`
- `fact_sales.CategoryKey` → `dim_category.CategoryKey`
- (dim_holiday joins via date matching — create a calculated column or use DAX)

### Report 1: Értékesítési Áttekintés (Dashboard)
Page 1:
- **Card** visual × 4: Total Sales = `SUM(fact_sales[Sales])`, Total Profit, Order Count = `DISTINCTCOUNT(fact_sales[OrderID])`, Avg Order Value
- **Clustered Bar Chart**: Category (from dim_category) on axis, Sales on values
- **Pie Chart**: Segment on legend, Sales on values
- **Slicer**: dim_time[Year], dim_time[MonthName]
- **Slicer**: fact_sales[Segment]

### Report 2: Ünnepnapi Elemzés (Holiday Analysis)
Page 2:
- **Clustered Bar Chart**: IsHoliday (0/1) on axis, AVG of Sales on values → shows holiday vs non-holiday average
- **Table**: Filter IsHoliday=1, show dates and sales — or join with dim_holiday for holiday names
- **Drill-down**: Create hierarchy: Year → HolidayName → Date
- **Slicer**: dim_holiday[HolidayName]

### Report 3: Top Termékek (Top Products)
Page 3:
- **Table** visual: SubCategory, TotalSales, TotalProfit, TotalQuantity from `agg_category_sales`
  - Enable column sorting (click headers)
- **Bar Chart**: Top 10 SubCategories by TotalSales (use Top N filter)
- **Slicer** with search: Category

### Report 4: Havi Trendek (Monthly Trends)
Page 4:
- **Line Chart**: X = concat(Year, Month) or a proper date, Y = TotalSales + TotalProfit from `agg_monthly_sales`
- **Slicer**: Region, Category
- This report shows data growing after each ETL chunk load + refresh

### Save
Save as: `reports\RetailDW_Reports.pbix`

### Demonstrating ETL → Report Refresh
1. Reset DB, run 1 ETL batch → Open PowerBI → Refresh → show partial data
2. Run another ETL batch → Refresh again → show data growth
3. Screenshot both states for documentation
