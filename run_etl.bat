@echo off
REM ============================================================
REM  RetailDW Incremental ETL Runner
REM  Loads the next unprocessed sales chunk on each run.
REM  Schedule this with Windows Task Scheduler.
REM ============================================================

SET BASE_DIR=D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF
SET SQL_DIR=%BASE_DIR%\sql
SET DATA_DIR=%BASE_DIR%\data
SET HOLIDAY_FILE=%DATA_DIR%\holidays\us_holidays_clean.csv
SET SERVER=(localdb)\MSSQLLocalDB
SET TRACKER=%BASE_DIR%\etl_tracker.txt

REM Initialize tracker file if it doesn't exist
IF NOT EXIST "%TRACKER%" (
    echo 0 > "%TRACKER%"
)

REM Read current chunk number
SET /P CURRENT_CHUNK=<"%TRACKER%"

REM Determine next chunk
SET /A NEXT_CHUNK=%CURRENT_CHUNK%+1

IF %NEXT_CHUNK% GTR 4 (
    echo All 4 chunks already loaded. ETL complete.
    echo %date% %time% - All chunks loaded >> "%BASE_DIR%\etl_log.txt"
    exit /b 0
)

SET CHUNK_FILE=%DATA_DIR%\split\sales_chunk_%NEXT_CHUNK%.csv

echo ============================================================
echo  Loading chunk %NEXT_CHUNK% of 4: %CHUNK_FILE%
echo  %date% %time%
echo ============================================================

REM Run the master ETL script with the chunk file path
sqlcmd -S "%SERVER%" -i "%SQL_DIR%\master_etl.sql" -v ChunkFile="%CHUNK_FILE%" HolidayFile="%HOLIDAY_FILE%"

IF %ERRORLEVEL% EQU 0 (
    echo %NEXT_CHUNK% > "%TRACKER%"
    echo %date% %time% - Chunk %NEXT_CHUNK% loaded successfully >> "%BASE_DIR%\etl_log.txt"
    echo SUCCESS: Chunk %NEXT_CHUNK% loaded.
) ELSE (
    echo %date% %time% - FAILED to load chunk %NEXT_CHUNK% >> "%BASE_DIR%\etl_log.txt"
    echo FAILED: Check etl_log.txt for details.
)
