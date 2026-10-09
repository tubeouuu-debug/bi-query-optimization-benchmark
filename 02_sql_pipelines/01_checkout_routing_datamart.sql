-- ==============================================================================
-- Pipeline 01: Checkout & Transaction Routing Datamart
-- Description: Aggregates multi-gateway checkout transactions, gateway decline codes,
--              latency metrics, geographic routing distance, and retry velocity
--              into a single-pass deterministic routing and exception engine.
-- Architecture: Config-Driven CTE + Multi-Gateway Response Normalization
-- Engine: Amazon Redshift SQL / PostgreSQL Compatible
-- ==============================================================================

WITH checkout_routing_config AS (
    -- Config-driven architecture: Industry-standard parameters for checkout routing & retry limits.
    SELECT
        12       AS cfg_critical_retry_threshold,      -- Max retry burst before automated fallback routing
        8        AS cfg_moderate_retry_threshold,      -- Moderate retry warning
        1000.0   AS cfg_high_order_value_threshold,    -- High-value transaction threshold for priority routing
        250.0    AS cfg_medium_order_value_bypass,     -- Baseline transaction threshold
        1000.0   AS cfg_max_geo_distance_miles,        -- Max allowed haul distance before geo anomaly
        75       AS cfg_processor_latency_ms_cutoff,   -- Latency threshold for gateway failover
        0.80     AS cfg_abnormal_margin_ratio_high,    -- Extreme product margin outlier
        0.10     AS cfg_near_zero_margin_floor,        -- Below-cost pricing anomaly
        10       AS cfg_bulk_quantity_threshold,       -- Single-order item quantity spike
        5        AS cfg_buyer_order_velocity_day       -- Max checkouts per buyer email per 24h
),

map_signals_gateway_a AS (
    SELECT
        i.checkout_id,
        LISTAGG(DISTINCT m.signal_code, ', ') AS gateway_a_signals
    FROM dwh_checkout.dim_gateway_a_transaction i
    LEFT JOIN dwh_reference.ref_gateway_a_response_mapping m
        ON LOWER(TRIM(i.response_reason)) = LOWER(TRIM(m.description))
    GROUP BY 1
),

map_signals_gateway_b AS (
    SELECT
        i.checkout_id,
        LISTAGG(m.signal_code, ',') AS gateway_b_signals
    FROM dwh_checkout.dim_gateway_b_transaction i
    LEFT JOIN dwh_reference.ref_gateway_b_response_mapping m
        ON LOWER(TRIM(i.response_reason)) = LOWER(TRIM(m.description))
    GROUP BY 1
),

map_signals_paypal AS (
    SELECT
        i.checkout_id,
        LISTAGG(m.signal_code, ',') AS paypal_signals
    FROM dwh_checkout.map_paypal_checkout i
    LEFT JOIN dwh_reference.ref_paypal_response_mapping m
        ON LOWER(TRIM(i.response_message)) = LOWER(TRIM(m.response_message))
    GROUP BY 1
),

map_signals_stripe AS (
    SELECT
        i.checkout_id,
        LISTAGG(DISTINCT m.signal_code, ',') AS stripe_signals
    FROM dwh_checkout.dim_stripe_payment_intent i
    LEFT JOIN dwh_reference.ref_stripe_response_mapping m
        ON LOWER(TRIM(i.failed_reason)) = LOWER(TRIM(m.error_message))
    GROUP BY 1
),

prep_checkout_data AS (
    SELECT
        o.shop_id,
        o.order_id,
        o.order_name,
        o.order_created_at,
        o.checkout_id,
        LOWER(o.buyer_email) AS buyer_email,
        o.payment_gateway,
        COALESCE(o.count_order_of_customer, 0) AS count_order_of_customer,
        COALESCE(o.no_order_customer_email_per_day, 0) AS no_order_customer_email_per_day,
        o.total_store_customer_buy,
        o.cvv_result,
        o.is_3d_secured_request,
        o.shipping_match_ip_country,
        NULLIF(o.shipping_match_card_country, '') AS shipping_match_card_country,
        NULLIF(o.billing_match_card_country, '') AS billing_match_card_country,
        NULLIF(o.ip_match_card_country, '') AS ip_match_card_country,
        o.billing_shipping_match,
        COALESCE(TRY_CAST(o.distance_billing_to_shipment AS FLOAT), 0) AS distance_billing_to_shipment,
        COALESCE(o.shipping_distance, 0) AS shipping_distance,
        COALESCE(o.billing_distance, 0) AS billing_distance,
        o.ip_proxy,
        COALESCE(o.gateway_latency_ms, 0) AS gateway_latency_ms,
        TRIM(LOWER(o.order_traffic_source)) AS order_traffic_source,
        TRIM(LOWER(ds.domain)) AS shop_domain,
        COALESCE(o.gmv, 0) AS gmv,
        COALESCE(o.merchant_profit, 0) AS merchant_profit,
        COALESCE(o.total_quantity, 0) AS total_quantity,
        COALESCE(o.line_item_count, 0) AS line_item_count,
        COALESCE(o.payment_attempt, 0) AS payment_attempt,
        LOWER(o.cvc_check) AS cvc_check,
        LOWER(o.address_line1_check) AS address_line1_check,
        LOWER(o.address_postal_code_check) AS address_postal_code_check,
        o.buyer_email_match_merchant_email,
        COALESCE(o.base_cost_margin, 0) AS base_cost_margin,
        COALESCE(o.avg_payment_intent_by_card_per_day, 0) AS avg_payment_intent_by_card_per_day,
        COALESCE(o.count_customer_by_card, 0) AS count_customer_by_card,
        o.is_same_ip_country_order_created,
        o.is_same_store_public_domain,
        COALESCE(o.count_order_cancel_refund_by_buyer_email, 0) AS count_order_cancel_refund_by_buyer_email,
        CASE
            WHEN o.merchant_profit IS NULL THEN 0
            ELSE COALESCE(ABS(o.merchant_profit) / NULLIF(o.gmv, 0), 0)
        END AS profit_margin,
        u.email AS merchant_email,
        
        -- Joined Gateway Telemetry
        ga.gateway_a_signals,
        gb.gateway_b_signals,
        pp.paypal_signals,
        st.stripe_signals
    FROM dwh_core.dim_order o
    LEFT JOIN dwh_core.dim_merchant u ON o.merchant_id = u.id
    LEFT JOIN dwh_core.dim_store ds ON o.shop_id = ds.id
    LEFT JOIN map_signals_gateway_a ga ON o.checkout_id = ga.checkout_id
    LEFT JOIN map_signals_gateway_b gb ON o.checkout_id = gb.checkout_id
    LEFT JOIN map_signals_paypal pp ON o.checkout_id = pp.checkout_id
    LEFT JOIN map_signals_stripe st ON o.checkout_id = st.checkout_id
    WHERE o.is_test = 0 
      AND o.order_created_at >= CURRENT_DATE - INTERVAL '8 DAYS'
),

define_routing_signals AS (
    SELECT
        p.*,
        cfg.*,
        
        -- 1. Gateway Response & Technical Failover Signals
        CASE 
            WHEN (stripe_signals LIKE '%DECLINE%' OR gateway_a_signals LIKE '%DECLINE%' 
               OR gateway_b_signals LIKE '%DECLINE%' OR paypal_signals LIKE '%DECLINE%') 
            THEN 1 ELSE 0 
        END AS sig_gateway_decline_received,
        
        CASE WHEN p.payment_attempt >= cfg.cfg_critical_retry_threshold THEN 1 ELSE 0 END AS sig_excessive_retry_burst,
        CASE WHEN p.gateway_latency_ms >= cfg.cfg_processor_latency_ms_cutoff THEN 1 ELSE 0 END AS sig_high_gateway_latency,
        CASE WHEN p.no_order_customer_email_per_day >= cfg.cfg_buyer_order_velocity_day THEN 1 ELSE 0 END AS sig_buyer_velocity_spike,
        CASE WHEN p.count_order_cancel_refund_by_buyer_email >= 8 THEN 1 ELSE 0 END AS sig_buyer_return_history,

        -- 2. Geographic & Routing Compatibility Signals
        CASE WHEN p.shipping_match_ip_country = 'not match' THEN 1 ELSE 0 END AS sig_shipping_ip_mismatch,
        CASE WHEN p.shipping_match_card_country = 'not match' THEN 1 ELSE 0 END AS sig_shipping_card_country_mismatch,
        CASE WHEN p.billing_match_card_country LIKE '%doesn''t match%' THEN 1 ELSE 0 END AS sig_billing_avs_mismatch,
        CASE WHEN p.billing_shipping_match = 'not match' THEN 1 ELSE 0 END AS sig_billing_shipping_mismatch,
        CASE WHEN p.distance_billing_to_shipment > cfg.cfg_max_geo_distance_miles THEN 1 ELSE 0 END AS sig_geo_distance_outlier,
        
        -- 3. Commercial Economics & Catalog Variance Signals
        CASE WHEN p.gmv >= cfg.cfg_high_order_value_threshold THEN 1 ELSE 0 END AS sig_high_value_order,
        CASE WHEN p.merchant_profit <= 0 THEN 1 ELSE 0 END AS sig_negative_profit_margin,
        CASE WHEN p.profit_margin >= cfg.cfg_abnormal_margin_ratio_high THEN 1 ELSE 0 END AS sig_abnormal_high_margin,
        CASE WHEN p.base_cost_margin <= cfg.cfg_near_zero_margin_floor THEN 1 ELSE 0 END AS sig_near_zero_base_cost_margin,
        CASE WHEN p.total_quantity >= cfg.cfg_bulk_quantity_threshold THEN 1 ELSE 0 END AS sig_bulk_item_quantity,
        CASE WHEN p.is_same_store_public_domain = 0 THEN 1 ELSE 0 END AS sig_non_public_domain_store,
        CASE WHEN p.order_traffic_source IN ('direct', '') THEN 1 ELSE 0 END AS sig_direct_traffic_origin

    FROM prep_checkout_data p
    CROSS JOIN checkout_routing_config cfg
),

routing_evaluation AS (
    SELECT
        *,
        -- Composite Routing Decision Rules
        CASE 
            WHEN sig_gateway_decline_received = 1 OR sig_excessive_retry_burst = 1 OR sig_high_gateway_latency = 1
            THEN 1 ELSE 0 
        END AS rule_trigger_fallback_gateway,

        CASE 
            WHEN sig_near_zero_base_cost_margin = 1 AND sig_non_public_domain_store = 1
            THEN 1 ELSE 0 
        END AS rule_unlisted_catalog_variance,

        CASE 
            WHEN sig_abnormal_high_margin = 1 OR (sig_near_zero_base_cost_margin = 1 AND gmv >= cfg_medium_order_value_bypass) 
            THEN 1 ELSE 0 
        END AS rule_pricing_reconciliation_hold,

        CASE 
            WHEN (sig_billing_shipping_mismatch = 1 AND sig_geo_distance_outlier = 1) OR sig_high_value_order = 1
            THEN 1 ELSE 0 
        END AS rule_secondary_validation_required
    FROM define_routing_signals
)

SELECT
    order_id,
    shop_id,
    order_name,
    order_created_at,
    merchant_email,
    buyer_email,
    gmv,
    merchant_profit,
    profit_margin,
    payment_gateway,
    order_traffic_source,

    -- String of matched routing telemetry codes for observability & monitoring
    TRIM(
        CASE WHEN sig_gateway_decline_received = 1 THEN 'GATEWAY_DECLINE ' ELSE '' END ||
        CASE WHEN sig_excessive_retry_burst = 1 THEN 'RETRY_BURST ' ELSE '' END ||
        CASE WHEN sig_high_gateway_latency = 1 THEN 'GATEWAY_LATENCY ' ELSE '' END ||
        CASE WHEN sig_geo_distance_outlier = 1 THEN 'GEO_DISTANCE_OUTLIER ' ELSE '' END ||
        CASE WHEN sig_direct_traffic_origin = 1 THEN 'DIRECT_TRAFFIC ' ELSE '' END ||
        CASE WHEN sig_high_value_order = 1 THEN 'HIGH_ORDER_VALUE ' ELSE '' END ||
        CASE WHEN sig_near_zero_base_cost_margin = 1 THEN 'LOW_UNIT_MARGIN ' ELSE '' END
    ) AS routing_telemetry_codes,

    -- Prescribed Automated Routing Action
    CASE
        WHEN rule_trigger_fallback_gateway = 1 THEN 'Route to Fallback Gateway'
        WHEN rule_unlisted_catalog_variance = 1 THEN 'Hold for Catalog Audit'
        WHEN rule_pricing_reconciliation_hold = 1 THEN 'Hold for Margin Reconciliation'
        WHEN rule_secondary_validation_required = 1 THEN 'Route to Secondary Validation'
        ELSE 'Auto-Route to Primary Gateway'
    END AS prescribed_routing_action

FROM routing_evaluation
ORDER BY order_created_at DESC;
