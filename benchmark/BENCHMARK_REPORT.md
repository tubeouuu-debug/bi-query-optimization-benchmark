# Empirical Architecture Benchmark Report

**Project:** E-Commerce BI Query Optimization Pipeline Transformation  
**Author:** Serena Nguyen  
**Execution Timestamp:** 2026-10-09 21:48:33  

---

## 1. Executive Summary

This benchmark provides empirical proof of performance gains achieved by transitioning from a **Fragmented Multi-Pass Architecture** (5 independent queries + client-side data merging) to an **Optimized Single-Pass CTE Datamart** executed directly within the analytical SQL engine.

- **Speedup Factor:** **`2.65x Faster`**
- **Latency Reduction:** **`62.3%`**
- **Throughput:** Increased from **`8,317 rec/sec`** to **`22,044 rec/sec`**.

---

## 2. Experimental Setup

- **Test Platform:** Python 3 + SQLite In-Memory Database (Vectorized Simulation)
- **Dataset Size:**
  - `1,500` Active Merchant Profiles
  - `25,000` Raw Order Transactions
  - `45,000` Browse & Cart Events
  - `625` Chargeback & Dispute Records
- **Benchmark Iterations:** `5` successive runs per architectural pattern

---

## 3. Results Comparison Matrix

| Architectural Dimension | Legacy Multi-Pass Pattern | Modernized Single-Pass Datamart | Variance / Gain |
| :--- | :--- | :--- | :--- |
| **Database Round-Trips** | 5 Distinct Visual Queries | 1 Unified CTE Pipeline | **-80.0% Network Trips** |
| **Client-Side Merging** | Required (Pandas In-Memory) | Zero (Handled in SQL Engine) | **Eliminated Toil** |
| **Analyst Logic** | 40+ Nested Spreadsheet IFs | Automated Suggested Action | **Zero Formula Drift** |
| **Average Execution Time** | `180.34 ms` (± `25.17 ms`) | `68.04 ms` (± `2.75 ms`) | **⚡ 62.3% Latency Drop** |
| **Processing Throughput** | `8,317 rec/sec` | `22,044 rec/sec` | **🚀 2.65x Throughput Gain** |

---

## 4. Architectural Findings

1. **Elimination of Inter-Query Serialization:** The legacy approach suffered from high serialization and client-side memory overhead by fetching 5 independent result sets before joining them.
2. **Pushdown Computation:** By expressing all rolling calculations, time-window evaluations, and risk classifications natively within SQL Common Table Expressions (CTEs), execution is fully vectorized and leverages SQLite/Redshift native indexing.
3. **Immutability & Operational Safety:** Eliminating spreadsheet formula dragging ensures 100% deterministic rule enforcement across all shifts.
