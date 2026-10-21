# Network reliability and GSL compliance analytics

A SQL Server and Power BI project that treats electricity outage data the way a network performance and compliance analyst would: validate it first, then calculate reliability measures, then reconcile the results against what the regulators and the network have published.

Everything here is built from **publicly published data**. This is an independent portfolio project and is not affiliated with, endorsed by, or produced for any distributor.

## What it does

1. **Data quality layer.** Loads 37,538 real outage events (NZ Commerce Commission information disclosure) into a layered SQL Server warehouse (`stg`, `clean`, `rpt`, `ref`). A rules catalogue and exception log flag problems before they reach any calculation: 870 exceptions across 868 events (V01, V03, V04, V05, V07, V08). Rules V02 and V06 are designed but not applied yet.
2. **Duplicate detection.** `ROW_NUMBER` based detection found 617 duplicated Westpower events that doubled its SAIDI (369.1 against 184.56 once cleaned). A clean view of 36,911 rows excludes 627 critical rows (36,911 + 627 = 37,538).
3. **Customer minutes trap.** Seven distributors report customer minutes per customer rather than per ICP, so a naive 5% mismatch rule raises about 12,900 alerts, roughly 99% of them false. The 89 events reporting more than is physically possible are the real errors.
4. **Major Event Day (MED) threshold.** Rebuilt the threshold, e^(alpha + 2.8 x beta) on the natural log of daily SAIDI, from 1,827 days of Powercor published daily data: alpha -2.0113, beta 1.4008, threshold 6.759 minutes, matching all 16 of 16 published MED days. Exclusions are applied before the day is tested (31 Jan 2020: raw 6.984, 3.950 after exclusions, so not a MED).
5. **STPIS targets.** Reproduced the AER reliability targets exactly: Urban 56.378, Short Rural 94.273, Long Rural 208.154 minutes (72.8, 150.9 and 376.5 if MED days were kept).
6. **GSL reconciliation.** Powercor's modelled Guaranteed Service Level payments against the ESC published figures: 10 of 10 comparable category rows match to the dollar for FY22 and FY23 actuals. Street lights ($750 FY22, $575 FY23) exist only in Powercor's model.
7. **Power BI report.** Import mode model with DAX measures, single direction relationships (Events to Exceptions on `load_row_id`, Rules to Exceptions on `rule_id`) and a custom theme.

## Repository layout

| Path | Contents |
|---|---|
| `sql/` | Numbered scripts, run in order: create database, load checks, profiling, rules catalogue, apply rules, cause mapping, clean view, MED threshold, GSL reconciliation |
| `powerbi/` | `Powercor_Reliability.pbix`, theme JSON and a PDF export of the report pages |
| `data/` | Source files as published, plus the CSV extracts loaded into SQL Server |

## Data sources

| Data | Publisher |
|---|---|
| Interruptions, worst feeders and data dictionary (`data/nz`) | New Zealand Commerce Commission, electricity distributor information disclosure |
| Powercor regulatory templates: STPIS targets and incentives, GSL, REFCL reliability, worst served customers (`data/powercor`) | Powercor Australia, published through the Australian Energy Regulator |
| GSL annual performance data for distributors (`data/esc_2024-25_gsl_annual_performance.docx`) | Essential Services Commission, Victoria |

Please check each publisher's terms before reusing the files.

## Honest limitations

* The outage events are New Zealand data, not Powercor's own. The Powercor files cover daily reliability, targets and GSL.
* Rules V02 and V06 are designed but not applied.
* The disclosure year rule is not built.
* Customer level data is not modelled, so the GSL eligibility engine is a next step.
* ESC and Powercor figures are likely not independent sources, so a match is a consistency check rather than proof.

## Running it

1. Create a SQL Server database with `sql/00_create_database.sql`.
2. Load the CSV files in `data/csv` into SQL Server, then run scripts `01` to `08` in order (`01_load_checks.sql` confirms the load).
3. Open `powerbi/Powercor_Reliability.pbix` and point the data source at your SQL Server instance.

## Glossary

SAIDI: average minutes off supply per customer. SAIFI: average interruptions per customer. CAIDI: SAIDI divided by SAIFI. MED: Major Event Day. STPIS: AER Service Target Performance Incentive Scheme. GSL: Guaranteed Service Level payments. REFCL: Rapid Earth Fault Current Limiter. AER: Australian Energy Regulator. ESC: Essential Services Commission (Victoria).
