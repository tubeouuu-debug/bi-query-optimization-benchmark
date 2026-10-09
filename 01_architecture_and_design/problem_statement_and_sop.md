# Operational Analytics Bottleneck Analysis & Modern SOP Specification

## 1. Context & Operational Baseline

The E-Commerce Operations & Financial Analytics teams are responsible for monitoring checkout transaction throughput, seller portfolio health, daily disbursement settlements, and recurring subscription billing across high-velocity multi-tier e-commerce platforms.

### The Problem: Fragmented Operations (The "Pre-Automation" Era)
Before this optimization project was initiated, generating daily operational reports and resolving exceptions required an unsustainable sequence of manual interventions across 4 disconnected operational domains:

1. **Checkout & Transaction Routing Analysis:**
   - Analysts had to extract separate transaction dumps from multiple payment processors (Stripe, PayPal, regional gateways).
   - Manually aligned decline codes and latency metrics across spreadsheets to diagnose checkout conversion drops.
   - Lacked unified gateway failover rules, causing checkout friction during processor downtime.

2. **Merchant 360 & Storefront Performance:**
   - Analysts opened 5 different visual tables on PowerBI every morning.
   - Downloaded CSV files from Visual 1 (Store Profile), Visual 2 (Order Volumes), Visual 3 (Merchant Attributes), Visual 4 (Traffic & Conversion Rates), and Visual 5 (Dispute & Return Metrics).
   - Ran 2 auxiliary SQL queries in Metabase to calculate disposable email ratios and multi-store customer percentages.
   - Manually merged all tables into a master Google Spreadsheet using `=VLOOKUP()`.
   - Applied a concatenated 40+ condition `=IF(...)` formula string across 50 columns to determine merchant health tiers and review flags.

3. **Financial Settlement & Cashflow Reconciliation:**
   - Required downloading 5 separate PowerBI visual exports into distinct staging sheets.
   - Ran ad-hoc Python merging scripts that pulled the staging sheets, computed unfulfilled order exposures, and pushed outputs back to a monthly Google Sheet.
   - When Finance added ad-hoc manual settlement requests, data split across BigQuery and Redshift caused sync delays of 2–3 hours.

4. **Subscription Billing & Account Activation:**
   - Whenever a merchant submitted their initial subscription billing transaction, credit card issuing country (`card_issuing_country_code`) frequently returned `NULL` due to downstream datamart sync delays.
   - For every `NULL` instance, the analyst had to open a separate browser tab, log into the external payment processor dashboard, search the transaction ID, manually check the issuing bank country, and update the spreadsheet.

---

## 2. Redesigned SOP (The Modern Pipeline Era)

With the deployment of the unified Data Pipeline and Decision Engine, the operational Standard Operating Procedure (SOP) was condensed into a frictionless 3-step routine:

### Step 1: Automated Queue Ingestion
- **For Batch Parameter Lookups:** Analyst navigates to the operational admin console, clicks the **[Copy IDs]** Bookmarklet utility. The script instantly copies clean comma-separated IDs to the clipboard.
- **For Ledger & Settlement Reconciliation:** Analyst opens the centralized Metabase dashboard. If off-cycle settlement adjustments were posted by Finance, the analyst clicks the **[Sync to Data Warehouse]** menu button in Google Sheets to trigger an on-demand refresh webhook.

### Step 2: Single-Point Parameter Execution
- Analyst pastes the target IDs into the filter box of the corresponding Metabase question:
  - `Metabase Datamart: Checkout & Transaction Routing Mart`
  - `Metabase Datamart: Merchant 360 Performance Mart`
  - `Metabase Datamart: Financial Settlement & Cashflow Reconciliation Mart`
  - `Metabase Datamart: Subscription Billing & Account Activation Mart`
- The unified SQL pipeline runs in seconds on Amazon Redshift, joining core tables, computing rolling historical metrics, evaluating composite rule sets, and pre-populating suggested routing/reconciliation statuses.

### Step 3: Action Execution & Closed-Loop Reporting
- Analyst exports the formatted dataset via **Excel (`.xlsx`)** with formatting preserved.
- Analyst verifies the auto-generated `automated_reconciliation_status` or `prescribed_routing_action` column:
  - **Auto-Disburse / Route Primary:** Instant release with zero manual latency.
  - **Reconcile / Tier-2 Signoff:** Analyst verifies specific flagged indicators in the telemetry column (e.g. `Volume >= $10k`, `High Fulfillment Lag`, `Dispute Reserve Exposure`).
  - **Hold / Retry:** Analyst applies standardized operational codes.
- The outcome is synced back to core operational tables, fully closing the loop.
