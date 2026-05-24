# RetailDW – Retail Sales Data Warehouse

A Business Intelligence project that loads US retail sales data into a star-schema SQL Server data warehouse via an SSIS ETL pipeline, visualises results in Power BI, and performs time-series sales forecasting with LSTM/GRU neural networks in a Jupyter notebook.

---

## Requirements

| Software | Purpose | Notes |
|----------|---------|-------|
| **SQL Server** (LocalDB or Express) | Database engine | Instance: `(localdb)\MSSQLLocalDB` |
| **SSMS** (SQL Server Management Studio) | Run SQL scripts | Free download from Microsoft |
| **Visual Studio 2019+** with SSIS extension | Edit/build SSIS packages | Requires *SQL Server Integration Services Projects* extension |
| **dtexec** (SQL Server 2016+) | Run SSIS packages from command line | Installed with SQL Server client tools |
| **Power BI Desktop** | Open `.pbix` report | Free download from Microsoft |
| **Python 3.x** | Jupyter notebook | Packages: `pandas`, `numpy`, `matplotlib`, `scikit-learn`, `tensorflow` |

---

## Project Structure

```
NHF/
│
├── run_ssis.bat                   ← Run the full ETL pipeline
├── reset_database.sql             ← Reset DB to empty state (keeps dim_time)
├── etl_log.txt                    ← ETL run log (auto-generated)
│
├── data/
│   ├── raw/
│   │   ├── Sample - Superstore.csv          ← Original source data (~10 000 rows)
│   │   └── US Holiday Dates (2004-2021).csv ← US public holidays reference data
│   ├── split/
│   │   ├── sales_chunk_1.csv      ← Sales data split into 4 equal parts
│   │   ├── sales_chunk_2.csv
│   │   ├── sales_chunk_3.csv
│   │   └── sales_chunk_4.csv
│   └── split.py                   ← Script that created the 4 chunk files
│
├── ssis/
│   └── RetailDW_ETL/
│       ├── RetailDW_ETL.slnx      ← Visual Studio solution file (open this in VS)
│       └── RetailDW_ETL/
│           ├── Master.dtsx                ← Orchestrates the full pipeline
│           ├── LoadHolidayDimension.dtsx  ← Loads dim_holiday from CSV
│           ├── LoadSalesChunk.dtsx        ← Loads one CSV chunk into staging
│           ├── TransformToFact.dtsx       ← Staging → fact_sales + aggregates
│           ├── AggregateMonthly.dtsx      ← Rebuilds agg_monthly_sales
│           ├── AggregateCategory.dtsx     ← Rebuilds agg_category_sales
│           └── bin/Development/
│               └── RetailDW_ETL.ispac     ← Compiled package (used by run_ssis.bat)
│
├── reports/
│   └── RetailDW_reports.pbix      ← Power BI report (4 pages)
│
├── notebooks/
│   └── sales_forecasting.ipynb    ← EDA + LSTM/GRU sales forecasting
│
└── docs/
    ├── demo_speech_script.md      ← Demo video script
    └── project_description.md     ← Extended project description
```

---

## Database Schema

Database name: **RetailDW** on `(localdb)\MSSQLLocalDB`

```
                  dim_time
                 (2 557 rows)
                     │  DateKey
                     │
dim_holiday ────── fact_sales ────── dim_category
(342 rows)        (9 994 rows)        (17 rows)
                     │
          ┌──────────┴──────────┐
   agg_monthly_sales      agg_category_sales
      (573 rows)               (17 rows)
```

### Tables

| Table | Type | Key columns |
|-------|------|-------------|
| `dim_time` | Dimension | `DateKey` (INT yyyyMMdd), `FullDate`, `Year`, `Month`, `Week`, `DayOfWeek`, `DayName`, `MonthName`, `IsHoliday` |
| `dim_holiday` | Dimension | `HolidayKey`, `HolidayDate`, `HolidayName`, `WeekDay`, `Month`, `Day`, `Year` |
| `dim_category` | Dimension | `CategoryKey`, `Category`, `SubCategory` |
| `fact_sales` | Fact | `OrderID`, `DateKey`, `CategoryKey`, `CustomerID`, `Segment`, `City`, `State`, `Region`, `Sales`, `Quantity`, `Discount`, `Profit`, `IsHoliday` |
| `agg_monthly_sales` | Aggregate | `Year`, `Month`, `Region`, `Category`, `TotalSales`, `TotalProfit`, `OrderCount` |
| `agg_category_sales` | Aggregate | `Category`, `SubCategory`, `TotalSales`, `TotalProfit`, `AvgDiscount`, `TotalQuantity` |
| `staging_sales` | Staging | Raw CSV columns — always empty after ETL completes |

---

## ETL Pipeline

The pipeline is implemented as 6 SSIS packages. `Master.dtsx` runs them all in sequence:

```
Clear Staging (TRUNCATE staging_sales)
       ↓
Load Holiday Dimension
  → Reads:  data/raw/US Holiday Dates (2004-2021).csv  (comma-delimited, quoted fields)
  → Writes: dim_holiday  (TRUNCATE + full reload each run)
       ↓
Foreach Loop  ← iterates over data/split/sales_chunk_*.csv
  ├── Load Sales Chunk
  │     → Reads:  sales_chunk_N.csv
  │     → Writes: staging_sales
  └── Transform To Fact
        → Inserts new categories into dim_category
        → Updates IsHoliday flags in dim_time
        → Inserts rows into fact_sales  (WHERE NOT EXISTS — no duplicates)
        → Clears staging_sales
       ↓
Aggregate Monthly   → TRUNCATE + rebuild agg_monthly_sales
       ↓
Aggregate Category  → TRUNCATE + rebuild agg_category_sales
```

**All packages are idempotent** — safe to re-run multiple times without corrupting data.

---

## How to Run

### 1. First-time database setup

Open SSMS, connect to `(localdb)\MSSQLLocalDB`, and create the database and tables.  
If the database already exists and you want a clean slate:

```sql
-- In SSMS: open and run reset_database.sql
```

This deletes all data, then re-populates `dim_time` with dates 2014-01-01 → 2018-12-31.

### 2. Run the ETL

**Double-click** `run_ssis.bat` in File Explorer.

### 3. Verify in SSMS

```sql
USE RetailDW;
SELECT COUNT(*) FROM fact_sales;        -- 9 994
SELECT COUNT(*) FROM dim_holiday;       -- 342
SELECT COUNT(*) FROM dim_category;      -- 17
SELECT COUNT(*) FROM agg_monthly_sales; -- 573
```

### 4. Open Power BI report

Open `reports/RetailDW_reports.pbix` in **Power BI Desktop**.

The report has 4 pages:
| Page | Content |
|------|---------|
| Sales Overview | KPI cards (revenue, profit, order count), category breakdown |
| Holiday Analysis | Holiday vs. non-holiday sales comparison |
| Top Products | Sub-category ranking by sales and profit |
| Monthly Trends | Time-series of monthly sales with seasonal pattern |

> **Note:** LocalDB uses a dynamic named pipe. If the default connection fails, use:
> `np:\\.\pipe\LOCALDB#XXXXXXXX\tsql\query`  
> (find the pipe name by running `sqllocaldb info MSSQLLocalDB` in a terminal)

### 5. Run the Jupyter notebook

```bash
cd \NHF\notebooks
jupyter notebook sales_forecasting.ipynb
```

The notebook dynamically loads all `sales_chunk_*.csv` files present in `data/split/` — so it works whether 1 or 4 chunks have been loaded.

**Sections:**
1. Data Loading & EDA (distribution, trends, day-of-week patterns)
2. Feature Extraction (cyclical sin/cos encoding of day-of-week, day-of-year)
3. Data Scaling (StandardScaler, fitted on train only)
4. Train / Validation / Test split (2014–2015 / 2016 / 2017, time-based)
5. LSTM model (weekly + 7-day rolling average)
6. GRU model (weekly + 7-day rolling average)
7. Results comparison (MSE, RMSE, MAE) — **GRU Rolling wins** (~255 785 MSE)

---

## Reset & Re-run

To demo the full pipeline from scratch:

1. Run `reset_database.sql` in SSMS
2. Run `run_ssis.bat`
3. Refresh Power BI (`Home → Refresh`)

---

## Data Sources

| Dataset | Source | Rows | Date range |
|---------|--------|------|------------|
| Superstore Sales | [Kaggle](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final) | ~10 000 orders | 2014–2018 |
| US Public Holidays | [Kaggle](https://www.kaggle.com/datasets/donnetew/us-holiday-dates-2004-2021) | 342 holidays | 2004–2021 |
