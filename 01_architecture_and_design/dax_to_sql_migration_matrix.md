# PowerBI DAX to Amazon Redshift SQL Migration Matrix

A core technical challenge of this initiative was translating complex, fragmented DAX measures across 5 distinct visual tables into clean, deterministic SQL calculations executed directly within the Data Warehouse.

Below is the architectural reference mapping showing how critical PowerBI measures were refactored into high-performance SQL CTEs and Window Functions.

---

## 1. Visual 1: Store Profile & Order Ratios

| Metric Name | PowerBI DAX Formula | Optimized Redshift SQL Formulation | Technical Rationale |
| :--- | :--- | :--- | :--- |
| **% Orders Flagged Disputed** | `DIVIDE(SUM(store_profile[count_disputed_order_total]), SUM(store_profile[total_order]))` | `SUM(count_disputed_order_total) * 1.0 / NULLIF(SUM(total_order), 0)` | Replaced DAX `DIVIDE()` with `NULLIF()` to guard against zero-division errors natively in SQL. |
| **% Secondary Gateway Payment Failures** | `DIVIDE(SUM(store_profile[count_failed_gateway_secondary]), SUM(store_profile[total_order]))` | `SUM(count_failed_gateway_secondary) * 1.0 / NULLIF(SUM(total_order), 0)` | Multiplied by `1.0` to prevent integer truncation during division. |
| **% Buyer Requested Cancel** | `DIVIDE([Total Cancel Order], SUM(store_profile[total_order]))` where `[Total Cancel Order] = CALCULATE(DISTINCTCOUNT(cancel_order[order_id]), CONTAINSSTRING(LOWER(cancel_order[ticket_type]), "cancel order"), USERELATIONSHIP(...))` | Joined `cs_cancel_orders` CTE with `LOWER(ticket_type) LIKE '%cancel order%'` and aggregated using `COUNT(DISTINCT c.order_id) * 1.0 / NULLIF(SUM(s.total_order), 0)` | Eliminated expensive runtime inactive relationship activation (`USERELATIONSHIP`) in DAX. |

---

## 2. Visual 2: Rolling Time-Intelligence & GMV Metrics

| Metric Name | PowerBI DAX Formula | Optimized Redshift SQL Formulation | Technical Rationale |
| :--- | :--- | :--- | :--- |
| **Avg Profit Last 3 Days** | `CALCULATE(AVERAGE(dim_order[merchant_profit]), dim_order[order_created_at] >= TODAY() - 4 && dim_order[order_created_at] < TODAY())` | `AVG(CASE WHEN o.order_created_at >= CURRENT_DATE - INTERVAL '4 day' AND o.order_created_at < CURRENT_DATE THEN o.merchant_profit END)` | Replaced DAX filter context evaluation with a clean conditional aggregation (`AVG(CASE WHEN ...)`). |
| **Max Lineitem GMV Last 3 Days** | `CALCULATE(MAX(dim_order[max_raw_price_lineitem]), dim_order[order_created_at] >= COALESCE(dim_order[account_tier_updated_at], TODAY()) - 4 && dim_order[order_created_at] < COALESCE(dim_order[account_tier_updated_at], TODAY()))` | `MAX(CASE WHEN d.order_created_at >= COALESCE(d.account_tier_updated_at, CURRENT_DATE) - INTERVAL '4 day' THEN d.max_raw_price_lineitem END)` | Avoids iterative row-by-row scanning across the entire orders fact table. |
| **Direct Traffic Order Ratio** | `DIVIDE(CALCULATE(AVERAGE(dim_order[total_direct_order_by_shop])), CALCULATE(AVERAGE(dim_order[total_order_by_shop])))` | `COUNT(DISTINCT CASE WHEN d.referring_site_label IN ('direct', '') THEN d.order_id END) * 1.0 / NULLIF(COUNT(DISTINCT d.order_id), 0)` | Direct order-level aggregation rather than nested averages, improving mathematical accuracy. |

---

## 3. Visual 3: User Profiling & String Manipulation

| Metric Name | PowerBI DAX Formula | Optimized Redshift SQL Formulation | Technical Rationale |
| :--- | :--- | :--- | :--- |
| **Count IP Locations** | `VAR commaCount = LEN(user_profile[ip_location]) - LEN(SUBSTITUTE(user_profile[ip_location], ",", "")) RETURN SWITCH(TRUE(), commaCount = 0, "1", commaCount = 1, "2", commaCount = 2, "3", ">=4")` | `CASE WHEN (LEN(ip_location) - LEN(REPLACE(ip_location, ',', ''))) = 0 THEN '1' WHEN (LEN(ip_location) - LEN(REPLACE(ip_location, ',', ''))) = 1 THEN '2' WHEN (LEN(ip_location) - LEN(REPLACE(ip_location, ',', ''))) = 2 THEN '3' ELSE '>=4' END` | Direct character length subtraction translated natively from DAX `SUBSTITUTE()` to SQL `REPLACE()`. |

---

## 4. Visual 4 & 5: Traffic Conversions & Dispute Keywords

| Metric Name | PowerBI DAX Formula | Optimized Redshift SQL Formulation | Technical Rationale |
| :--- | :--- | :--- | :--- |
| **CR View-to-Purchase (3 Days)** | `DIVIDE(SUM(event_product[total_session_purchase_l3d]), SUM(event_product[total_session_view_content_l3d]))` | `SUM(total_session_purchase_l3d) * 1.0 / NULLIF(SUM(total_session_view_content_l3d), 0)` | Streamlined session event aggregation. |
| **% Disputes Contain Restricted Keywords** | `DIVIDE(SUM(store_profile[dispute_contain_restricted_keywords_count]), SUM(store_profile[total_order]))` | `SUM(dispute_contain_restricted_keywords_count) * 1.0 / NULLIF(SUM(total_order), 0)` | Grouped by store and pre-calculated directly inside the ETL datamart. |
