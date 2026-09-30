"""
================================================================================
load_central_superstore.py
Central Superstore Data Warehouse Project - Python ETL loader

Purpose
-------
Alternative, fully automated loader that reads Central_Superstore.xlsx
directly and loads dw.DimCustomer, dw.DimProduct, dw.DimLocation,
dw.DimShipMode, dw.DimDate, and dw.FactSales in SQL Server.

Use this instead of 04_Load_Data.sql (BULK INSERT) when:
  - BULK INSERT / xp_cmdshell is disabled on your SQL Server instance, or
  - the SQL Server service account cannot read the CSV file path, or
  - you simply prefer a one-command Python workflow.

Prerequisites
-------------
    pip install pandas openpyxl sqlalchemy pyodbc

You also need the "ODBC Driver 17 for SQL Server" (or 18) installed.
Download: https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server

IMPORTANT: The database and all tables must already exist. Run, in this
exact order, before this script:
    01_Database_Setup.sql
    02_Create_Dimensions.sql
    03_Create_Fact.sql
(11_Master_Deploy.sql runs all three of these for you, plus the view,
stored procedures, and indexes.)

Configuration
-------------
Edit the CONFIG block below, or set the equivalent environment variables:
    SQL_SERVER, SQL_DATABASE, SQL_AUTH (windows|sql), SQL_USERNAME,
    SQL_PASSWORD, EXCEL_PATH

Usage
-----
    python load_central_superstore.py

The script:
  1. EXTRACTS Central_Superstore.xlsx (sheet "Central_Region").
  2. TRANSFORMS: validates required columns, casts data types, flags/rejects
     malformed rows, derives the Date dimension range dynamically, and
     builds surrogate-key lookups for every dimension.
  3. LOADS dimensions first, then FactSales, using explicit surrogate-key
     joins -- mirroring the logic in 04_Load_Data.sql exactly so that
     either loading path produces an identical warehouse.
  4. Prints a row-count and total-sales/profit reconciliation at the end,
     matching the checks in 05_Validation.sql.

No data is invented. Rows that fail validation are reported, not silently
discarded.
================================================================================
"""

import os
import sys
import logging
from datetime import datetime, timedelta

import pandas as pd

try:
    from sqlalchemy import create_engine, text
except ImportError:
    print("Missing dependency. Run: pip install sqlalchemy pyodbc pandas openpyxl")
    sys.exit(1)

# ------------------------------------------------------------------------
# CONFIG -- edit these, or set as environment variables of the same name
# ------------------------------------------------------------------------
CONFIG = {
    "SQL_SERVER":   os.environ.get("SQL_SERVER", "localhost"),
    "SQL_DATABASE": os.environ.get("SQL_DATABASE", "CentralSuperstoreDW"),
    "SQL_AUTH":     os.environ.get("SQL_AUTH", "windows"),   # "windows" or "sql"
    "SQL_USERNAME": os.environ.get("SQL_USERNAME", ""),
    "SQL_PASSWORD": os.environ.get("SQL_PASSWORD", ""),
    "EXCEL_PATH":   os.environ.get("EXCEL_PATH", os.path.join(
                        os.path.dirname(__file__), "..", "data", "Central_Superstore.xlsx")),
    "SHEET_NAME":   "Central_Region",
    "ODBC_DRIVER":  os.environ.get("ODBC_DRIVER", "ODBC Driver 17 for SQL Server"),
}

REQUIRED_COLUMNS = [
    "Row ID", "Order ID", "Order Date", "Ship Date", "Ship Mode",
    "Customer ID", "Customer Name", "Segment", "Country", "City", "State",
    "Postal Code", "Region", "Product ID", "Category", "Sub-Category",
    "Product Name", "Sales", "Quantity", "Discount", "Profit",
]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("central_superstore_etl")


def build_connection_string() -> str:
    driver = CONFIG["ODBC_DRIVER"].replace(" ", "+")
    server = CONFIG["SQL_SERVER"]
    database = CONFIG["SQL_DATABASE"]
    if CONFIG["SQL_AUTH"].lower() == "windows":
        return (f"mssql+pyodbc://@{server}/{database}"
                f"?driver={driver}&trusted_connection=yes")
    else:
        user = CONFIG["SQL_USERNAME"]
        pwd = CONFIG["SQL_PASSWORD"]
        return f"mssql+pyodbc://{user}:{pwd}@{server}/{database}?driver={driver}"


def extract() -> pd.DataFrame:
    path = CONFIG["EXCEL_PATH"]
    log.info(f"EXTRACT: reading {path} (sheet '{CONFIG['SHEET_NAME']}')")
    if not os.path.exists(path):
        raise FileNotFoundError(f"Excel source not found at: {path}")

    df = pd.read_excel(path, sheet_name=CONFIG["SHEET_NAME"])

    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"Source file is missing required columns: {missing}")

    log.info(f"EXTRACT complete: {len(df)} rows, {len(df.columns)} columns.")
    return df


def transform(df: pd.DataFrame) -> pd.DataFrame:
    log.info("TRANSFORM: validating and casting types...")
    original_count = len(df)

    df = df.rename(columns={
        "Row ID": "RowID", "Order ID": "OrderID", "Order Date": "OrderDate",
        "Ship Date": "ShipDate", "Ship Mode": "ShipMode", "Customer ID": "CustomerID",
        "Customer Name": "CustomerName", "Postal Code": "PostalCode",
        "Product ID": "ProductID", "Sub-Category": "SubCategory",
        "Product Name": "ProductName",
    })

    # Type casting with explicit error tracking (no silent discards)
    df["OrderDate"] = pd.to_datetime(df["OrderDate"], errors="coerce")
    df["ShipDate"] = pd.to_datetime(df["ShipDate"], errors="coerce")
    df["Sales"] = pd.to_numeric(df["Sales"], errors="coerce")
    df["Quantity"] = pd.to_numeric(df["Quantity"], errors="coerce")
    df["Discount"] = pd.to_numeric(df["Discount"], errors="coerce")
    df["Profit"] = pd.to_numeric(df["Profit"], errors="coerce")
    df["PostalCode"] = df["PostalCode"].astype(str).str.strip()

    bad_mask = (
        df["OrderDate"].isna() | df["ShipDate"].isna() | df["Sales"].isna()
        | df["Quantity"].isna() | df["Discount"].isna() | df["Profit"].isna()
    )
    rejected = df[bad_mask]
    if len(rejected) > 0:
        log.warning(f"{len(rejected)} row(s) rejected during TRANSFORM (bad dates/numerics):")
        log.warning(rejected[["RowID", "OrderID"]].to_string(index=False))
    else:
        log.info("All rows passed type validation.")

    clean = df[~bad_mask].copy()

    # Business-rule checks (report, don't silently drop, unless truly invalid)
    invalid_qty = clean[clean["Quantity"] <= 0]
    invalid_discount = clean[(clean["Discount"] < 0) | (clean["Discount"] > 1)]
    if len(invalid_qty) > 0:
        log.warning(f"{len(invalid_qty)} row(s) have non-positive Quantity.")
    if len(invalid_discount) > 0:
        log.warning(f"{len(invalid_discount)} row(s) have Discount outside [0,1].")

    log.info(f"TRANSFORM complete: {len(clean)}/{original_count} rows retained.")
    return clean


def load(engine, df: pd.DataFrame):
    log.info("LOAD: writing dimensions and fact table...")

    with engine.begin() as conn:
        # ---- DimCustomer ----
        conn.execute(text("TRUNCATE TABLE dw.DimCustomer"))
        dim_customer = df[["CustomerID", "CustomerName", "Segment"]].drop_duplicates()
        dim_customer.to_sql("DimCustomer", conn, schema="dw", if_exists="append", index=False)
        log.info(f"  DimCustomer: {len(dim_customer)} rows")

        # ---- DimProduct (natural key = ProductID+ProductName+Category+SubCategory) ----
        conn.execute(text("TRUNCATE TABLE dw.DimProduct"))
        dim_product = df[["ProductID", "ProductName", "Category", "SubCategory"]].drop_duplicates()
        dim_product.to_sql("DimProduct", conn, schema="dw", if_exists="append", index=False)
        log.info(f"  DimProduct: {len(dim_product)} rows")

        # ---- DimLocation ----
        conn.execute(text("TRUNCATE TABLE dw.DimLocation"))
        dim_location = df[["Country", "City", "State", "PostalCode", "Region"]].drop_duplicates()
        dim_location.to_sql("DimLocation", conn, schema="dw", if_exists="append", index=False)
        log.info(f"  DimLocation: {len(dim_location)} rows")

        # ---- DimShipMode ----
        conn.execute(text("TRUNCATE TABLE dw.DimShipMode"))
        dim_shipmode = df[["ShipMode"]].drop_duplicates()
        dim_shipmode.to_sql("DimShipMode", conn, schema="dw", if_exists="append", index=False)
        log.info(f"  DimShipMode: {len(dim_shipmode)} rows")

        # ---- DimDate (range derived dynamically from the data) ----
        conn.execute(text("TRUNCATE TABLE dw.DimDate"))
        min_date = min(df["OrderDate"].min(), df["ShipDate"].min())
        max_date = max(df["OrderDate"].max(), df["ShipDate"].max())
        log.info(f"  DimDate range derived from data: {min_date.date()} to {max_date.date()}")

        dates = []
        d = min_date
        while d <= max_date:
            dates.append({
                "DateKey": int(d.strftime("%Y%m%d")),
                "FullDate": d.date(),
                "DayNumber": d.day,
                "DayName": d.strftime("%A"),
                "MonthNumber": d.month,
                "MonthName": d.strftime("%B"),
                "QuarterNumber": (d.month - 1) // 3 + 1,
                "YearNumber": d.year,
                "WeekNumber": int(d.strftime("%V")),
                "IsWeekend": 1 if d.weekday() >= 5 else 0,
            })
            d += timedelta(days=1)
        dim_date = pd.DataFrame(dates)
        dim_date.to_sql("DimDate", conn, schema="dw", if_exists="append", index=False)
        log.info(f"  DimDate: {len(dim_date)} rows")

        # ---- Re-read generated surrogate keys for lookups ----
        dim_customer_keys = pd.read_sql("SELECT CustomerKey, CustomerID FROM dw.DimCustomer", conn)
        dim_product_keys = pd.read_sql(
            "SELECT ProductKey, ProductID, ProductName, Category, SubCategory FROM dw.DimProduct", conn)
        dim_location_keys = pd.read_sql(
            "SELECT LocationKey, City, State, PostalCode, Region FROM dw.DimLocation", conn)
        dim_shipmode_keys = pd.read_sql("SELECT ShipModeKey, ShipMode FROM dw.DimShipMode", conn)

        # ---- Build FactSales via surrogate-key merges ----
        fact = df.merge(dim_customer_keys, on="CustomerID", how="inner")
        fact = fact.merge(dim_product_keys, on=["ProductID", "ProductName", "Category", "SubCategory"], how="inner")
        fact = fact.merge(dim_location_keys, on=["City", "State", "PostalCode", "Region"], how="inner")
        fact = fact.merge(dim_shipmode_keys, on="ShipMode", how="inner")

        fact["OrderDateKey"] = fact["OrderDate"].dt.strftime("%Y%m%d").astype(int)
        fact["ShipDateKey"] = fact["ShipDate"].dt.strftime("%Y%m%d").astype(int)

        fact_final = fact[[
            "RowID", "OrderID", "OrderDateKey", "ShipDateKey", "CustomerKey",
            "ProductKey", "LocationKey", "ShipModeKey", "Quantity", "Sales",
            "Discount", "Profit",
        ]].rename(columns={"RowID": "SourceRowID"})

        conn.execute(text("TRUNCATE TABLE dw.FactSales"))
        fact_final.to_sql("FactSales", conn, schema="dw", if_exists="append", index=False)
        log.info(f"  FactSales: {len(fact_final)} rows")

        if len(fact_final) != len(df):
            log.warning(
                f"Row-count mismatch: {len(df)} clean source rows but "
                f"{len(fact_final)} fact rows were produced. Check for "
                f"dimension merge failures (orphaned natural keys)."
            )
        else:
            log.info("Row-count reconciliation passed: every clean row produced exactly one fact row.")

    return fact_final


def reconcile(fact_final: pd.DataFrame):
    log.info("VALIDATION (matches 05_Validation.sql):")
    log.info(f"  Total Sales    = {fact_final['Sales'].sum():,.4f}")
    log.info(f"  Total Profit   = {fact_final['Profit'].sum():,.4f}")
    log.info(f"  Total Quantity = {fact_final['Quantity'].sum():,}")
    log.info(f"  Avg Discount   = {fact_final['Discount'].mean():.6f}")
    log.info(f"  Distinct Orders = {fact_final['OrderID'].nunique():,}")


def main():
    log.info("=== Central Superstore ETL: START ===")
    engine = create_engine(build_connection_string(), fast_executemany=True)

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as e:
        log.error(f"Could not connect to SQL Server. Check CONFIG at the top of this "
                  f"script (server/database/auth) and that the ODBC driver is installed. "
                  f"Error: {e}")
        sys.exit(1)

    raw = extract()
    clean = transform(raw)
    fact_final = load(engine, clean)
    reconcile(fact_final)

    log.info("=== Central Superstore ETL: COMPLETE ===")
    log.info("Next: run 05_Validation.sql in SSMS to cross-check against the recalculated source figures.")


if __name__ == "__main__":
    main()
