-- ==============================================================================
-- Pipeline 02: Merchant 360 Performance Datamart
-- Description: Unifies 5 separate fragmented visual queries into an automated Kimball
--              master merchant profiling model with rolling time-intelligence windows,
--              multi-store portfolio aggregation, and operational health scoring.
-- Architecture: Config-Driven CTE + Unified Dimensional Master
-- Grain: 1 Row per shop_id
-- Engine: Amazon Redshift SQL / PostgreSQL Compatible
-- ==============================================================================

WITH merchant_health_config AS (
    -- Config-driven industry benchmarks for multi-tier e-commerce merchant monitoring
    SELECT
        0.85   AS cfg_disputed_order_ratio_critical,  -- Critical order dispute ratio
        0.40   AS cfg_payment_failure_ratio_high,     -- Payment failure rate anomaly threshold
        0.035  AS cfg_dispute_rate_benchmark,         -- Standard dispute rate ceiling (3.5%)
        0.15   AS cfg_disposable_email_ratio_high,    -- High disposable email customer concentration
        0.40   AS cfg_multi_store_repeat_buyer_rate,  -- Cross-store repeat buyer ratio
        100.0  AS cfg_rolling_gmv_surge_threshold,    -- High-velocity short-term GMV surge ($k)
        0.85   AS cfg_direct_traffic_dominance_ratio  -- Direct traffic dominance threshold
),

active_merchant_storefronts AS (
    SELECT 
        o.shop_id,
        o.merchant_id,
        MAX(u.email) AS merchant_email,
        MAX(o.order_created_at::DATE) AS latest_active_date
    FROM dwh_core.dim_order o
    LEFT JOIN dwh_core.dim_merchant u ON o.merchant_id = u.id
    WHERE o.order_created_at::DATE >= CURRENT_DATE - INTERVAL '14 DAYS'
      AND o.is_test = 0
    GROUP BY o.shop_id, o.merchant_id
),

restricted_disbursement_registry AS (
    SELECT 
        r.merchant_id,
        1 AS is_matched,
        LISTAGG(DISTINCT reg.restricted_email, ', ') WITHIN GROUP (ORDER BY reg.restricted_email) AS flagged_destination_emails
    FROM dwh_finance.fact_merchant_payout_setting r
    JOIN dwh_finance.ref_restricted_account_registry reg 
        ON LOWER(TRIM(r.payout_destination_email)) = LOWER(TRIM(reg.restricted_email))
    GROUP BY r.merchant_id
),

base_merchant_metrics AS (
    SELECT
        t1.shop_id,
        t1.merchant_id,
        active.merchant_email,
        active.latest_active_date,
        t1.disposable_email_rate,
        t1.invalid_email_rate,
        t1.multi_store_buyer_rate,
        t1.unique_ip_location_count,
        t1.merchant_country,
        t1.merchant_city,
        t1.total_order_count,
        t1.dispute_order_ratio,
        t1.payment_failure_rate_primary_gateway,
        t1.payment_failure_rate_secondary_gateway,
        t1.total_disputed_orders,
        t1.total_refunded_orders,
        
        -- Rolling Historical Financial Performance Windows
        t1.avg_profit_l3d,
        t1.avg_profit_l7d,
        t1.avg_profit_l30d,
        t1.avg_gmv_l3d,
        t1.avg_gmv_l7d,
        t1.avg_gmv_l30d,
        t1.max_lineitem_gmv_l3d,
        t1.max_lineitem_gmv_l7d,
        
        -- Conversion & Traffic Funnel Indicators
        t1.cr_view_to_purchase_l3d,
        t1.cr_view_to_purchase_l7d,
        t1.cr_view_to_purchase_l30d,
        t1.pct_direct_traffic_l3d,
        t1.pct_direct_traffic_l7d,
        t1.pct_direct_traffic_l30d,
        t1.pct_social_traffic_l30d,
        
        COALESCE(restr.is_matched, 0) AS is_disbursement_restricted,
        restr.flagged_destination_emails
    FROM dwh_core.fact_merchant_daily_metrics t1
    INNER JOIN active_merchant_storefronts active
        ON t1.shop_id = active.shop_id
    LEFT JOIN restricted_disbursement_registry restr
        ON t1.merchant_id = restr.merchant_id
),

evaluated_merchant_signals AS (
    SELECT
        b.*,
        cfg.*,
        
        -- Standardized Analytical Health Flags
        CASE WHEN b.dispute_order_ratio >= cfg.cfg_disputed_order_ratio_critical THEN 'CRITICAL_DISPUTE_SURGE ' ELSE '' END AS sig_critical_dispute,
        CASE WHEN b.payment_failure_rate_primary_gateway >= cfg.cfg_payment_failure_ratio_high THEN 'HIGH_GATEWAY_FAILURE ' ELSE '' END AS sig_gateway_failure,
        CASE WHEN b.avg_gmv_l3d >= cfg.cfg_rolling_gmv_surge_threshold THEN 'HIGH_GMV_SURGE ' ELSE '' END AS sig_gmv_surge,
        CASE WHEN b.disposable_email_rate >= cfg.cfg_disposable_email_ratio_high THEN 'DISPOSABLE_BUYER_EMAIL ' ELSE '' END AS sig_disposable_emails,
        CASE WHEN b.pct_direct_traffic_l3d >= cfg.cfg_direct_traffic_dominance_ratio THEN 'UNATTRIBUTED_DIRECT_TRAFFIC ' ELSE '' END AS sig_direct_traffic,
        CASE WHEN b.multi_store_buyer_rate >= cfg.cfg_multi_store_repeat_buyer_rate THEN 'MULTI_STORE_BUYER_CLUSTER ' ELSE '' END AS sig_multi_store_clustering,
        CASE WHEN b.is_disbursement_restricted = 1 THEN 'RESTRICTED_DISBURSEMENT_RECIPIENT ' ELSE '' END AS sig_restricted_disbursement
    FROM base_merchant_metrics b
    CROSS JOIN merchant_health_config cfg
)

SELECT
    TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') AS calculation_date,
    s.merchant_id,
    s.merchant_email,
    s.shop_id,
    EXTRACT(WEEK FROM CURRENT_DATE) AS reporting_week,

    -- Portfolio Tier Assignment
    CASE
        WHEN s.avg_gmv_l30d >= 50000 THEN 'Tier 1 - Enterprise Merchant'
        WHEN s.avg_gmv_l30d >= 10000 THEN 'Tier 2 - Growth Merchant'
        ELSE 'Tier 3 - Standard Merchant'
    END AS merchant_segment_tier,

    -- Synthesized Health Indicators
    TRIM(
        s.sig_critical_dispute ||
        s.sig_gateway_failure ||
        s.sig_gmv_surge ||
        s.sig_disposable_emails ||
        s.sig_direct_traffic ||
        s.sig_multi_store_clustering ||
        s.sig_restricted_disbursement
    ) AS aggregated_health_signals,

    -- Key Ratios Formatted for Executive BI Reporting
    TO_CHAR(s.disposable_email_rate * 100, '990.99') || '%' AS disposable_email_rate,
    TO_CHAR(s.invalid_email_rate * 100, '990.99') || '%' AS invalid_email_rate,
    TO_CHAR(s.multi_store_buyer_rate * 100, '990.99') || '%' AS multi_store_buyer_rate,
    s.unique_ip_location_count,
    s.merchant_country,
    s.merchant_city,
    s.total_order_count,
    TO_CHAR(s.dispute_order_ratio * 100, '990.99') || '%' AS dispute_order_ratio,
    TO_CHAR(s.payment_failure_rate_primary_gateway * 100, '990.99') || '%' AS primary_gateway_failure_rate,
    
    -- Rolling Historical GMV & Profit Windows
    s.avg_profit_l3d,
    s.avg_profit_l7d,
    s.avg_profit_l30d,
    s.avg_gmv_l3d,
    s.avg_gmv_l7d,
    s.avg_gmv_l30d,
    s.max_lineitem_gmv_l3d,
    s.max_lineitem_gmv_l7d,
    
    -- Traffic & Conversion Channels
    TO_CHAR(s.cr_view_to_purchase_l3d * 100, '990.99') || '%' AS conversion_rate_3d,
    TO_CHAR(s.pct_direct_traffic_l3d * 100, '990.99') || '%' AS direct_traffic_share_3d,
    s.is_disbursement_restricted,
    s.flagged_destination_emails

FROM evaluated_merchant_signals s
ORDER BY s.shop_id;
