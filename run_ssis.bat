@echo off
REM ============================================================
REM  RetailDW ETL – Run Master SSIS Package
REM ============================================================

SET BASE_DIR=D:\Egyetem\Msc_3\Uzleti_inteligencia_labor\NHF
SET "ISPAC=%BASE_DIR%\ssis\RetailDW_ETL\RetailDW_ETL\bin\Development\RetailDW_ETL.ispac"
SET LOG=%BASE_DIR%\etl_log.txt

echo Running Master.dtsx...

dtexec /Project "%ISPAC%" /Package "Master.dtsx"

IF %ERRORLEVEL% EQU 0 (
    echo %date% %time% - Master ETL completed successfully >> "%LOG%"
    echo SUCCESS
) ELSE (
    echo %date% %time% - Master ETL FAILED >> "%LOG%"
    echo FAILED: Check etl_log.txt for details.
    exit /b 1
)
