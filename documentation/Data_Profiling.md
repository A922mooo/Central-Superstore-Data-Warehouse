# Data Profiling Report — Central_Superstore.xlsx

**Sheet analyzed:** `Central_Region`
**Method:** Direct inspection with `pandas` against the actual uploaded workbook. No figures below are assumed, estimated, or invented — every number was recomputed from the file.

---

## 1. Structural profile

| Property | Value |
|---|---|
| Rows | 2,323 |
| Columns | 21 |
| Fully duplicated rows | 0 |
| Duplicate `Row ID` values | 0 (Row ID is a valid natural primary key for the source sheet) |
| Missing values (any column) | 0 |

Column data types as read from the workbook:

| Column | Type |
|---|---|
| Row ID | Integer |
| Order ID | Text |
| Order Date | Date |
| Ship Date | Date |
| Ship Mode | Text (4 distinct values) |
| Customer ID | Text |
| Customer Name | Text |
| Segment | Text (3 distinct values) |
| Country | Text (1 distinct value: United States) |
| City | Text (181 distinct values) |
| State | Text (13 distinct values) |
| Postal Code | Integer in source; **treated as text/identifier** in the warehouse |
| Region | Text (1 distinct value: Central) |
| Product ID | Text |
| Category | Text (3 distinct values) |
| Sub-Category | Text (17 distinct values) |
| Product Name | Text |
| Sales | Decimal |
| Quantity | Integer |
| Discount | Decimal (fraction, e.g. 0.20 = 20%) |
| Profit | Decimal (can be negative) |

---

## 2. Baseline validation — recalculated vs. brief

| Metric | Brief's stated baseline | Recalculated from Excel | Match? |
|---|---|---|---|
| Total Sales | 501,239.89 | **501,239.8908** | ✅ Exact match |
| Total Profit | 39,706.36 | **39,706.3625** | ✅ Exact match |
| Total Quantity | 8,780 | **8,780** | ✅ Exact match |
| Average Discount | 24.04% | **24.0353%** | ✅ Exact match |
| Orders (distinct Order ID) | 1,175 | **1,175** | ✅ Exact match |
| Customers (distinct Customer ID) | 629 | **629** | ✅ Exact match |
| Products (distinct Product ID) | 1,310 | **1,310** | ✅ Exact match |

**Conclusion:** the baseline figures supplied in the project brief are confirmed exactly against the actual workbook. No discrepancy was found.

---

## 3. Duplicates and key analysis

- **Row ID**: unique across all 2,323 rows — valid natural key for the source.
- **Order ID**: repeats, as expected — 1,175 distinct orders across 2,323 order lines (avg. ~1.98 lines/order). This is normal multi-line-order behavior and **must not be collapsed** when loading the fact table.
- **Customer ID → Customer Name**: every Customer ID maps to exactly one Customer Name (0 conflicts). Clean 1:1 relationship.
- **Product ID → Product Name/Category/Sub-Category**: **16 Product IDs map to more than one Product Name** (e.g. `FUR-CH-10001146` appears as both *"Global Value Mid-Back Manager's Chair, Gray"* and *"Global Task Chair, Black"*). This is a known quirk in this dataset (the same SKU code has been reused for genuinely different catalog items). It is **not a load error** — the warehouse handles it by keying `DimProduct` on the full natural-key combination `(ProductID, ProductName, Category, SubCategory)`, which correctly separates these into distinct product records while still allowing analysis by raw Product ID if needed. Because of this, `DimProduct` will contain slightly more rows (1,326) than the count of distinct Product IDs (1,310) — this is expected, not an error.
- **(Order ID, Product ID) combination**: 0 duplicates — no order contains the same product twice as a separate line, confirming the fact grain (one row = one order line) is well-formed.

---

## 4. Date range (used to size `DimDate` dynamically — not hardcoded)

| Field | Min | Max |
|---|---|---|
| Order Date | 2013-01-03 | 2016-12-30 |
| Ship Date | 2013-01-07 | 2017-01-05 |

- Combined range spans **2013-01-03 to 2017-01-05** (1,464 calendar days) — this is exactly the range `DimDate` is generated for.
- **Ship Date is never earlier than Order Date** for any of the 2,323 rows (0 violations) — a good data-integrity sign.
- Average shipping duration: **4.06 days** (min 0, max 7).

---

## 5. Distinct values by dimension

| Dimension | Distinct values |
|---|---|
| Category | 3 — Office Supplies, Furniture, Technology |
| Sub-Category | 17 |
| Region | 1 — Central (confirms this file is region-scoped, not company-wide) |
| Country | 1 — United States |
| State | 13 — Texas, Illinois, Michigan, Indiana, South Dakota, Wisconsin, Missouri, Minnesota, Iowa, Oklahoma, Nebraska, Kansas, North Dakota |
| City | 181 |
| Ship Mode | 4 — Standard Class (1,439 rows), Second Class (465), First Class (299), Same Day (120) |
| Segment | 3 — Consumer, Corporate, Home Office |

State row counts are heavily concentrated: Texas (985 rows) and Illinois (492 rows) together account for over 63% of all order lines — a useful fact for the geographic-concentration narrative in the final report.

---

## 6. Descriptive statistics

| Field | Min | 25% | Median | 75% | Max | Mean | Std Dev |
|---|---|---|---|---|---|---|---|
| Sales | 0.444 | 14.62 | 45.98 | 200.01 | 17,499.95 | 215.77 | 632.78 |
| Profit | −3,701.89 | −5.66 | 5.18 | 22.46 | 8,399.98 | 17.09 | 291.49 |
| Quantity | 1 | 2 | 3 | 5 | 14 | 3.78 | 2.16 |
| Discount | 0.00 | 0.00 | 0.20 | 0.30 | 0.80 | 0.240 | 0.265 |

- Sales and Profit are both right-skewed with heavy tails (a small number of large-ticket transactions), which is typical of retail transaction data and is reflected in the "Top 10 Products/Customers" style of analysis used throughout the project rather than simple averages.
- Profit's minimum (−$3,701.89) and the existence of 25th-percentile profit already negative (−$5.66) foreshadow the loss-making-products and discount-impact analysis in the final report.

---

## 7. Data-quality issues identified and how they were handled

| Issue | Found? | Resolution |
|---|---|---|
| Missing values | None | No action needed |
| Fully duplicated rows | None | No action needed |
| Negative/zero Sales | None | No action needed |
| Non-positive Quantity | None | No action needed |
| Discount outside [0, 1] | None | No action needed |
| Ship Date before Order Date | None | No action needed |
| Product ID mapping to >1 Product Name | **16 cases** | `DimProduct` natural key expanded to (ProductID, ProductName, Category, SubCategory); documented above and in the Star Schema design notes |
| Postal Code stored as a number in source | Yes | Cast to `NVARCHAR(10)` throughout the warehouse — it is an identifier, not a quantity, and this avoids losing meaning if any postal code ever has a leading zero |

No rows were discarded from the Central Region dataset. All 2,323 rows load into `FactSales`.
