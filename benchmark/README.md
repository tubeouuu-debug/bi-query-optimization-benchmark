# BI Query Optimization Benchmark Suite

Empirical performance evaluation suite comparing **Legacy Fragmented Multi-Pass BI Architecture** vs. **Modernized Single-Pass CTE Datamart Architecture**.

---

## 🎯 Purpose

When explaining analytics engineering and query optimization transformations, claims of *"we optimized the process"* are often met with skepticism unless backed by reproducible evidence.

This benchmark provides **verifiable, deterministic, code-level proof** comparing the computational efficiency, network round-trips, and algorithmic complexity between:
1. **The Legacy BI Approach:** 5 fragmented visual queries, mandatory client-side data merging, and row-by-row procedural evaluation.
2. **The Modernized Datamart Approach:** Single-pass SQL execution using Common Table Expressions (CTEs), vectorized aggregations, window functions, and in-engine decision synthesis.

---

## ⚡ Quick Start

### 1. Requirements
- Python 3.9+
- Standard Library (`sqlite3`, `json`, `time`)
- `pandas` and `numpy` (for client-side DataFrame merge simulation)

### 2. Run Benchmark
Run with default parameters (1,500 merchants, 25,000 transactions, 5 iterations):

```bash
python benchmark/run_benchmark.py
```

### 3. Custom Scale Parameters
Test higher volume loads (e.g., 5,000 merchants and 100,000 transactions):

```bash
python benchmark/run_benchmark.py --merchants 5000 --orders 100000 --iterations 5
```

---

## 🔬 Benchmark Methodology

### Architecture A: Legacy Simulation
- **Query 1:** Store Profile & Core Volume Aggregation
- **Query 2:** Rolling 3-Day GMV & Profit Window
- **Query 3:** Unique Session IP & Browse Footprint
- **Query 4:** Multi-Gateway Velocity & Card Testing Retries
- **Query 5:** Historical Dispute & Loss Records
- **Client-Side Merge:** Memory-bound multi-way DataFrame join in Pandas
- **Procedural Logic:** Iterative row-by-row threshold scoring (simulating spreadsheet formulas)

### Architecture B: Modernized Single-Pass Pipeline
- **Single SQL Statement:** Evaluates all metrics in a single compilation plan.
- **CTEs & Window Functions:** Computes rolling time windows and grouped metrics natively in SQLite/Redshift.
- **Set-Based Vectorization:** Vectorized conditional aggregation (`AVG(CASE WHEN...)`, `NULLIF()`).
- **In-Engine Action Tagging:** Computes suggested routing status (`Auto-Route`, `Reconcile Variance`, `Hold for Review`) directly in the SELECT projection.

---

## 📊 Benchmark Output

Running the suite produces:
1. **Real-time Terminal Dashboard:** ASCII table displaying round timings, standard deviation, throughput, and speedup factor.
2. **`benchmark_results.json`:** Machine-readable latency and throughput metrics for CI/CD or reporting.
3. **`BENCHMARK_REPORT.md`:** Auto-generated markdown documentation for technical reviews.

---

## 🛡️ Privacy & Confidentiality Guarantee

- **100% Synthetic Data:** All merchant IDs, buyer records, IP addresses, and GMV amounts are generated algorithmically using fixed seeds (`numpy.random`).
- **Standard Industry Taxonomy:** Evaluates universal e-commerce risk patterns (velocity bursts, geo-distance mismatches, dispute rates) without exposing proprietary company algorithms or sensitive business data.
