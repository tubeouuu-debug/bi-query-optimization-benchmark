# Multi-Dimensional E-Commerce Operational Health & Routing Signals Taxonomy

This document outlines the multi-dimensional analytical taxonomy implemented across the **E-Commerce Single-Pass Analytical Datamarts**. It details the analytical metrics designed to evaluate transaction routing health, seller portfolio scale, and settlement ledger reconciliation while maintaining high throughput across enterprise storefronts.

---

## 📊 1. Taxonomy of Operational Analytical Dimensions

The unified data marts evaluate **64 transaction telemetry attributes**, **45 merchant performance indicators**, and **73 financial ledger attributes**, categorizing analytical signals across four primary dimensions:

```text
┌────────────────────────────────────────────────────────────────────────┐
│            MULTI-DIMENSIONAL OPERATIONAL SIGNALS TAXONOMY              │
├─────────────────┬─────────────────┬──────────────────┬─────────────────┤
│ 1. VELOCITY     │ 2. GEO & NETWORK│ 3. ENTITY LINKAGE│ 4. UNIT MARGIN  │
│ - Retry Spikes  │ - BIN Mismatch  │ - Identity Match │ - Margin Floors │
│ - Burst Orders  │ - Distance Leap │ - Multi-Store    │ - GMV Outliers  │
│ - Volume Shifts │ - Latency Drops │ - Account Groups │ - SKU Cost Gaps │
└─────────────────┴─────────────────┴──────────────────┴─────────────────┘
```

---

### Dimension A: Payment Attempt Velocity & Routing Telemetry
Monitors transaction attempt patterns across temporal windows to optimize gateway routing:

- **`sig_excessive_retry_burst`:** Identifies checkout sessions where retry attempts on a single transaction exceed operational limits within a tight window.
- **`sig_high_gateway_latency`:** Detects processor response latency spikes exceeding baseline SLA, triggering automated failover routing.
- **`sig_buyer_velocity_spike`:** Identifies checkout concentration where a single buyer identifier initiates abnormal transaction volume across multiple stores.

---

### Dimension B: Geographic Routing & Network Topology
Cross-border e-commerce platforms process transactions globally, requiring multi-point geographic validation:

- **`sig_shipping_ip_mismatch`:** Tracks transactions where customer shipping destination country diverges from session browsing IP origin.
- **`sig_billing_avs_mismatch`:** Identifies AVS (Address Verification System) response discrepancies between billing postal code and card issuing bank.
- **`sig_geo_distance_outlier`:** Computes the geographic haul distance between billing coordinates and physical delivery coordinates.
- **`sig_order_session_ip_mismatch`:** Highlights session shifts between browsing, cart addition, and final checkout completion.

---

### Dimension C: Entity Relationship & Portfolio Linkages
Monitors relationship ties between merchant accounts, storefront hierarchies, and buyer transactions:

- **`sig_multi_store_clustering`:** Evaluates customer concentration across multiple independent storefronts within the same merchant portfolio.
- **`sig_cross_account_linkage`:** Identifies shared payment instruments, business addresses, or operational subnets across merchant accounts.
- **`sig_restricted_disbursement_recipient`:** Correlates settlement payout recipient accounts against restricted compliance directories.

---

### Dimension D: Commercial Economics & Catalog Variance
- **`sig_near_zero_base_cost_margin`:** Flags product pricing where retail prices fall below baseline supplier and fulfillment cost thresholds.
- **`sig_abnormal_high_margin`:** Identifies pricing anomalies with extreme margin multipliers requiring catalog review.
- **`sig_non_public_domain_store`:** Flags storefronts operating on temporary or unverified subdomains before catalog validation.

---

## ⚙️ 2. In-Engine Decision Synthesis & Routing Actions

Signals are synthesized into composite decision rules directly within the SQL projection layer:

| Rule Identifier | Composite Evaluation Formula | Prescribed Action | Operational Objective |
| :--- | :--- | :--- | :--- |
| **`RULE_TRIGGER_FALLBACK_GATEWAY`** | `Gateway Decline = 1` OR `Retry Burst = 1` OR `High Latency = 1` | **Route to Fallback Gateway** | Preserves checkout conversion by routing around processor downtime. |
| **`RULE_CATALOG_MARGIN_VARIANCE`** | `Near Zero Base Margin` + `Non-Public Domain` | **Hold for Margin Reconciliation** | Prevents fulfillment losses due to supplier cost mismatch or pricing errors. |
| **`RULE_PRICING_OUTLIER_HOLD`** | `Abnormal Margin` OR (`Low Margin` + `High GMV Outlier`) | **Hold for Catalog Audit** | Halts fulfillment to verify unit price configuration and supplier catalog. |
| **`RULE_SECONDARY_VALIDATION`** | `Billing-Shipping Mismatch` + `Geo Distance Outlier` + `High GMV` | **Route to Secondary Validation** | Triggers automated tier-2 verification before dispatching high-value items. |
| **`RULE_AUTO_ROUTE_PRIMARY`** | No exception triggers matched | **Auto-Route to Primary Gateway** | Zero-latency automated pass-through for standard transactions. |
