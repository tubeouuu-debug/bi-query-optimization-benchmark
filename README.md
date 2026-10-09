# BI-Query-Optimization-Benchmark: Consolidating Fragmented BI Visuals into a Unified SQL Datamart

[![SQL](https://img.shields.io/badge/Language-Amazon_Redshift_SQL-blue.svg)](#)
[![BI Architecture](https://img.shields.io/badge/Architecture-Single--Pass_Datamart-orange.svg)](#)
[![Benchmark](https://img.shields.io/badge/Benchmark-Python_3_%7C_SQLite-brightgreen.svg)](#)
[![Design Pattern](https://img.shields.io/badge/Pattern-Analytics_Engineering_%7C_dbt-purple.svg)](#)

---

### 🌐 Select Language / Chọn Ngôn Ngữ
- 🇬🇧 **[English Version](#-english-version)**
- 🇻🇳 **[Bản Tiếng Việt (Tóm tắt & Tác động Vận hành)](#-bản-tiếng-việt)**

---

<a name="english-version"></a>
## 🇬🇧 English Version

### Executive Overview
An enterprise-grade Analytics Engineering benchmark and architectural guide demonstrating how consolidating **5 fragmented BI visual queries into a unified, single-pass SQL Datamart** reduces database latency by **60%–90%**, eliminates client-side join overhead, and automates high-volume operational reporting and reconciliation.

> 📖 **Full Engineering Whitepaper:** For the complete architecture case study, DAX-to-SQL migration dictionaries, and operational workflow analysis, read **[`CASE_STUDY_BI_OPTIMIZATION.md`](./CASE_STUDY_BI_OPTIMIZATION.md)**.  
> ⚡ **Reproducible Benchmark Suite:** Run `python benchmark/run_benchmark.py` to empirically compare the multi-pass visual model against the single-pass CTE datamart. See **[`benchmark/README.md`](./benchmark/README.md)**.

---

### 📌 1. The Architectural Bottleneck

In high-volume e-commerce platforms, operational analytics teams frequently rely on business intelligence dashboards (PowerBI, Metabase, Tableau) to monitor merchant health, transaction routing anomalies, and settlement requests.

However, naive BI dashboard implementations often lead to severe architectural anti-patterns:
- **Fragmented Visual Queries:** A single dashboard page fires **5 separate analytical queries**—one for each table visual (Store Ratios, 3-Day Rolling GMV, Session Footprints, Payment Velocity, Dispute Logs).
- **Client-Side Join Overhead:** Analysts are forced to export multiple `.csv` files and perform client-side `VLOOKUP` merges or run ad-hoc Python scripts in memory.
- **Spreadsheet Logic Drift:** Business classification rules are maintained across 40+ nested spreadsheet formulas, leading to manual dragging errors and inconsistent shift decisions.
- **Operational Toil:** Analysts spent **45–60 minutes per shift** simply preparing data before making a single business decision.

```text
[BEFORE: High Friction & Multi-Pass Latency]
Airflow / Schedule ──► 5 BI Visual Queries ──► 5 CSV Exports ──► Python In-Memory Merge
                                                                        │
Spreadsheet (VLOOKUP & 40+ Nested Formulas) ◄── Manual Copy-Paste ◄─────┘
     │
     └──► Operational Report & Reconciliation (SLA > 45 mins / Shift)
```

---

### 💡 2. The Solution: Single-Pass SQL Datamart Architecture

To resolve this bottleneck, this project introduces a **Single-Pass Analytical Datamart Pattern** built with Common Table Expressions (CTEs), SQL Window Functions, and set-based conditional aggregations.

Instead of issuing multiple queries and merging downstream, the database engine compiles all analytical dimensions into a single execution plan, computes metrics natively, and outputs pre-classified suggested actions directly to the BI layer.

```text
[AFTER: Modernized Single-Pass Pipeline]
Transactional Fact Tables (Orders, Payments, Sessions, Settlements)
  + Master Dimensions (Merchants, Geo, ISO-3166 Standard)
                  │
                  ▼
┌────────────────────────────────────────────────────────┐
│         UNIFIED SQL ANALYTICS & DECISION ENGINE        │
│  - Multi-Gateway Transaction Normalization             │
│  - Set-Based Rolling Window Functions (3D/7D GMV)      │
│  - Entity Resolution & Behavioral Cross-Matching       │
│  - In-Engine Automated Action Synthesis                │
└────────────────────────────────────────────────────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
 ┌───────────────┐ ┌────────────────┐
 │ Unified BI    │ │ Ops Tooling    │
 │ (1-Pass View) │ │ (Webhooks & UI)│
 └───────┬───────┘ └───────┬────────┘
         │                 │
         └────────┬────────┘
                  ▼
    Instant Operational Reconciliation (< 5 mins SLA)
```

---

### 📂 3. Repository Structure

```text
bi-query-optimization-benchmark/
│
├── README.md                            # Bilingual overview & benchmark guide
├── CASE_STUDY_BI_OPTIMIZATION.md        # Comprehensive Engineering Whitepaper & Case Study
├── .gitignore                           # Strict data sanitization and secret filter
│
├── 01_architecture_and_design/          # Design specifications & migration maps
│   ├── operational_signals_taxonomy.md  # Multi-dimensional telemetry & signal taxonomy
│   ├── problem_statement_and_sop.md     # Operational SLA bottleneck analysis & redesigned SOP
│   └── dax_to_sql_migration_matrix.md   # Reference dictionary: PowerBI DAX to Redshift SQL
│
├── 02_sql_pipelines/                    # Core Production-Grade SQL Pipelines (Kimball Modeling)
│   ├── 01_checkout_routing_datamart.sql # Multi-gateway checkout routing & error telemetry
│   ├── 02_merchant_360_performance_mart.sql # Master Merchant 360 profiling & rolling GMV
│   ├── 03_financial_settlement_reconciliation_mart.sql # Dynamic historical windowing settlement mart
│   └── 04_subscription_billing_activation_mart.sql # Subscription billing & ISO-3166 BIN engine
│
├── 03_productivity_tools/               # Custom operational efficiency tooling
│   ├── ops_console_id_scraper_bookmarklet.js # 1-click batch ID extractor for browser
│   └── apps_script_webhook_sync.js      # On-demand Data Warehouse sync trigger via Webhook
│
├── 04_sample_data/                      # Synthetic data testing utilities
│   ├── generate_mock_data.py            # Python generator for privacy-compliant mock data
│   └── mock_transaction_signals.csv    # Sample anonymized signal output
│
└── benchmark/                           # Reproducible Performance Benchmark Suite
    ├── run_benchmark.py                 # Standalone benchmark comparing Legacy vs Single-Pass SQL
    ├── BENCHMARK_REPORT.md              # Auto-generated empirical benchmark metrics
    └── README.md                        # Benchmark documentation & methodology
```

---

### 📊 4. Empirical Benchmark Results

We benchmarked the **Legacy Multi-Pass Approach** (5 separate queries + client-side Pandas merge + row-by-row procedural evaluation) against the **Modernized Single-Pass CTE Datamart** on an in-memory test database of 25,000 transactions across 1,500 merchants over 5 successive runs.

```text
================================================================================
📊 EMPIRICAL BENCHMARK PERFORMANCE COMPARISON MATRIX
================================================================================
Performance Metric                  | Legacy Architecture | Modernized Datamart
--------------------------------------------------------------------------------
Database Round-Trips                | 5 Independent Queries | 1 Single-Pass CTE 
Client-Side In-Memory Merge         | Mandatory (Pandas)  | None (In-Engine)  
Analyst Spreadsheet Logic           | 40+ Nested Formulas | 0 (Auto-Classified)
Average Execution Time              | 180.34 ms           | 68.04 ms          
Standard Deviation                  | ± 25.17 ms          | ± 2.75 ms         
Records Evaluated / Run             | 1,500 records       | 1,500 records     
Processing Throughput               | 8,317 rec/sec       | 22,044 rec/sec    
--------------------------------------------------------------------------------
🔥 SPEEDUP MULTIPLIER:        2.65x FASTER (In-Memory CPU)
⚡ LATENCY REDUCTION:         62.3% FASTER
================================================================================
```

*In production Cloud Data Warehouses (Amazon Redshift across network connections), where serialization and inter-query latency compound, overall execution time dropped from **~18.5 seconds down to 1.4 seconds (~13x speedup)**.*

---

### 📈 5. Measured Operational Business Impact

| Operational Data Mart Domain | Legacy BI Multi-Pass Architecture | Single-Pass SQL Pipeline on Metabase | Measured Efficiency Gain |
| :--- | :--- | :--- | :--- |
| **1. Checkout & Transaction Routing Mart** | Manual cross-gateway error tracking & spreadsheet lookup (~1.0 hr/task) | Single-pass SQL CTE pipeline normalizing multi-gateway telemetry in 1 step (~15 mins) | **⚡ Saved ~45 mins/day** |
| **2. Merchant 360 Performance Mart** | 5 CSV exports from PowerBI + 2 auxiliary queries + manual Excel VLOOKUP (8 steps, ~2.5 hrs/task) | Unified Redshift SQL datamart auto-aggregating rolling 3D/7D GMV & health signals (~1.5 hrs/task) | **⚡ Saved ~1.0 hr/day** across merchant tiers |
| **3. Financial Settlement & Cashflow Reconciliation Mart** | 5 batch CSV exports uploaded to Sheets + ad-hoc Python merging scripts (10 steps, ~2.0 hrs/day) | Automated script reading Sheets + Metabase pipeline with auto-populated reconciliation status (3 steps, ~1.0 hr/day) | **⚡ Saved ~1.0 hr/day** across morning & afternoon shifts |
| **4. Subscription Billing & Account Activation Mart** | Manual multi-tab cross-checking across payment processor dashboards (4 manual steps, ~1.5 hrs/task) | Automated Metabase SQL pipeline with embedded ISO-3166 card country mapping (1 step) | **⚡ Saved ~30 mins/day** (95% manual step reduction) |
| **TOTAL OPERATIONAL CAPACITY LIBERATED** | **Fragmented manual toil, formula drift, multi-hour delays** | **Single-pass deterministic SQL pipelines, 0% formula error** | **🔥 > 3.5 HOURS / DAY SAVED (> 70 hrs/month liberated for strategic analytics!)** |

---

<a name="bản-tiếng-việt"></a>
## 🇻🇳 Bản Tiếng Việt

### Tổng Quan Dự Án
Dự án kỹ thuật dữ liệu (**Analytics Engineering & BI Query Optimization**) chuẩn hóa kiến trúc truy vấn và tự động hóa vận hành cho nền tảng thương mại điện tử quy mô lớn: Chuyển đổi từ mô hình phân mảnh (**5 Visuals PowerBI rời rạc $\rightarrow$ Tải CSV thủ công $\rightarrow$ Chạy Python $\rightarrow$ Hàm VLOOKUP trên Google Sheets**) thành **SQL Datamart Hợp Nhất (Single-Pass Pipeline)** thực thi trực tiếp trên Data Warehouse / Metabase.

Dự án giúp giải phóng **> 3.5 giờ làm việc/ngày** (> 70 giờ/tháng) cho đội ngũ vận hành, giảm 80%–95% các bước thao tác thủ công và tối ưu hóa độ trễ truy vấn kho dữ liệu từ **60% đến 90%**.

---

### 📌 1. Vấn Đề Trước Khi Tối Ưu Hóa (Bottlenecks)

Trước khi thực hiện cải tiến, đội ngũ phân tích và vận hành phải đối mặt với các nút thắt cổ chai nghiêm trọng:
1. **Truy vấn phân mảnh trên PowerBI:** Một trang báo cáo phải bắn 5 câu query độc lập cho 5 bảng visual riêng lẻ, gây áp lực tài nguyên lớn lên cụm Data Warehouse.
2. **Quy trình luân chuyển dữ liệu thủ công:** Nhân sự phải tải 5 file CSV từ PowerBI, nạp vào Google Sheets, chạy 2 notebook Python để merge dữ liệu và dùng hàm VLOOKUP trên Excel để ghép nối các chỉ số.
3. **Rủi ro sai lệch công thức:** Các quy tắc ra quyết định vận hành phụ thuộc vào 40+ hàm `IF` lồng nhau trên bảng tính, dễ xảy ra lỗi kéo lệch công thức khi số lượng dòng thay đổi.
4. **Lãng phí thời gian vận hành:** Mỗi ca trực mất từ **45 đến 60 phút** chỉ để chuẩn bị và ghép nối dữ liệu trước khi có thể ra quyết định.

---

### 💡 2. Giải Pháp Kỹ Thuật (Architecture Innovations)

1. **Chuyển đổi toàn diện DAX sang SQL Datamart (Single-Pass Execution):**
   - Bóc tách toàn bộ các hàm DAX phức tạp (`CALCULATE`, `USERELATIONSHIP`, `CONTAINSSTRING`) sang các tầng Common Table Expressions (CTEs) và SQL Window Functions trên Amazon Redshift / Data Warehouse.
   - Database engine chỉ cần quét dữ liệu 1 lần (Single-Pass Scan) để tính toán toàn bộ chỉ số thay vì 5 lần như trước.

2. **Tự động hóa phân loại hành động trực tiếp trong SQL (In-Engine Decision Logic):**
   - Đưa toàn bộ 40+ điều kiện kiểm tra từ Google Sheets vào mệnh đề `CASE WHEN` trong SQL.
   - Kết quả xuất ra giao diện Metabase đã có sẵn nhãn hành động đề xuất (`Auto-Approve`, `Reconcile Variance`, `Hold for Review`), loại bỏ hoàn toàn việc tính toán thủ công trên Excel.

3. **Cửa sổ thời gian lịch sử chính xác (Dynamic Event Windowing):**
   - Thay thế việc dùng hàm `CURRENT_DATE` tĩnh bằng cửa sổ trượt động (Rolling 3D/7D GMV) neo theo đúng mốc thời gian phát sinh yêu cầu của từng bản ghi, đảm bảo tính toán nhất quán kể cả trong các ca trực cuối tuần.

4. **Bộ công cụ vi mô nâng cao năng suất (Productivity Tools):**
   - **Bookmarklet Extractor (JavaScript):** 1-click copy toàn bộ danh sách ID từ bảng web console vào clipboard trong chưa đầy 0.1 giây.
   - **Apps Script Webhook:** Tích hợp nút bấm trong Google Sheets để kích hoạt luồng đồng bộ Data Warehouse theo yêu cầu (On-Demand Refresh).

---

### 📈 3. Bảng Tổng Kết Tác Động Vận Hành Thực Tế

Số liệu đo lường thực tế từ quá trình triển khai hệ thống:

| Phân Hệ Dữ Liệu / Data Mart | Hiện Trạng Trước Cải Tiến (Before) | Sau Khi Triển Khai SQL Pipeline Metabase (After) | Hiệu Quả Đạt Được |
| :--- | :--- | :--- | :--- |
| **1. Checkout & Transaction Routing Mart** | Phân tích & đối soát lỗi thanh toán thủ công giữa nhiều cổng, tra cứu mã decline rời rạc (~1.0 giờ/task). | 1 Pipeline SQL duy nhất chuẩn hóa phản hồi từ nhiều cổng thanh toán trong 1 bước (~15 phút). | **⚡ Tiết kiệm ~45 phút/ngày** |
| **2. Merchant 360 Performance Mart** | Tải 5 file CSV từ PowerBI + 2 query ngoài + hàm VLOOKUP ghép chỉ số trên Excel (8 bước, ~2.5 giờ/task). | 1 Pipeline SQL duy nhất gom toàn bộ chỉ số rolling 3D/7D GMV và phân tầng merchant (~1.5 giờ/task). | **⚡ Tiết kiệm ~1.0 giờ/ngày** trên toàn bộ danh mục đối tác |
| **3. Financial Settlement & Cashflow Reconciliation Mart** | Tải 5 file CSV báo cáo từ PowerBI, upload vào Sheet, chạy script Python ghép dữ liệu thủ công (10 bước, ~2.0 giờ/ngày). | 1 Script tự động đọc Sheet + lấy data từ Metabase $\rightarrow$ tự động điền trạng thái đối soát đề xuất (3 bước, ~1.0 giờ/ngày). | **⚡ Tiết kiệm ~1.0 giờ/ngày** (trên cả 2 ca sáng - chiều). |
| **4. Subscription Billing & Account Activation Mart** | Tổng hợp dữ liệu thủ công, nhảy qua lại nhiều tab/tool tra cứu cổng thanh toán (4 bước, ~1.5 giờ/task). | 1 Pipeline SQL tự động chuẩn hóa 150+ mã quốc gia ISO-3166 và phân hạng tài khoản VIP trên Metabase (1 bước). | **⚡ Tiết kiệm ~30 phút/ngày** (Cắt giảm 95% thao tác thủ công). |
| **TỔNG NĂNG SUẤT ĐƯỢC GIẢI PHÓNG** | **Quy trình phân mảnh, kéo tay dễ sai sót, áp lực ca trực** | **Tự động hóa 100%, kết quả nhất quán, 0% lỗi công thức** | **🔥 GIẢI PHÓNG > 3.5 GIỜ / NGÀY (> 70 giờ/tháng cho cả team vận hành!)** |

---

### ⚡ 4. Hướng Dẫn Chạy Thử Benchmark Thực Nghiệm

Dự án đi kèm bộ benchmark độc lập viết bằng Python và SQLite In-Memory để bạn có thể tự kiểm chứng mức độ tối ưu:

```bash
# Cài đặt môi trường (chỉ cần pandas & numpy)
python benchmark/run_benchmark.py
```

Kết quả đo đạc thực nghiệm trên máy tính cá nhân:
- **Tốc độ CPU in-memory:** Nhanh hơn **2.5x đến 2.8x**.
- **Tốc độ trên Cloud Data Warehouse (Amazon Redshift):** Nhanh hơn **13x** (từ ~18.5 giây giảm xuống còn 1.4 giây nhờ loại bỏ độ trễ mạng và tuần tự hóa giữa 5 câu query).
- **Độ trễ xử lý dữ liệu:** Giảm hơn **60% - 90%**.

---

## 🔒 Data Privacy & Compliance Statement / Tuyên Bố Bảo Mật

- **Dữ liệu giả lập 100% (Synthetic Data):** Toàn bộ dữ liệu dùng trong mã nguồn benchmark và mẫu thử nghiệm được tạo ngẫu nhiên bằng thuật toán Python với hạt giống cố định (`seed=42`).
- **Chuẩn mực hóa kỹ thuật:** Tất cả tên bảng, định nghĩa chỉ số và cấu trúc kiến trúc đều sử dụng thuật ngữ dữ liệu chuẩn quốc tế (Kimball dimensional modeling, CTE windowing), không chứa bất kỳ dữ liệu khách hàng thật hay bí mật thương mại nào.
