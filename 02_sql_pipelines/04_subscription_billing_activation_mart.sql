-- ==============================================================================
-- Pipeline 04: Subscription Billing & Account Activation Datamart
-- Description: Resolves upstream merchant billing metadata latency by embedding an
--              in-engine ISO-3166 3-letter country normalization dictionary, reconciles
--              SaaS recurring invoice sequences, and evaluates enterprise VIP account tiers.
-- Architecture: Config-Driven CTE + In-Engine ISO-3166 BIN Normalization Matrix
-- Grain: 1 Row per billing_event_id
-- Engine: Amazon Redshift SQL / PostgreSQL Compatible
-- ==============================================================================

WITH subscription_activation_config AS (
    -- Config-driven policy parameters for SaaS subscription activations
    SELECT
        200.0  AS cfg_max_pending_invoice_amount, -- Maximum pending billing balance before manual confirmation
        30     AS cfg_tenured_merchant_days,       -- Minimum tenure in days to qualify as seasoned account
        100    AS cfg_tenured_order_volume         -- Minimum historical orders for seasoned account
),

enterprise_managed_accounts AS (
    -- Enterprise VIP merchant account manager mapping
    SELECT 10000001 AS enterprise_merchant_id, 'Enterprise_CSM_NorthAmerica' AS csm_owner UNION ALL
    SELECT 10000002, 'Enterprise_CSM_NorthAmerica' UNION ALL
    SELECT 10000003, 'Enterprise_CSM_EMEA' UNION ALL
    SELECT 10000004, 'Enterprise_CSM_APAC'
),

managed_accounts_lookup AS (
    SELECT enterprise_merchant_id, MAX(csm_owner) AS csm_owner
    FROM enterprise_managed_accounts
    GROUP BY enterprise_merchant_id
),

merchant_lifetime_orders AS (
    SELECT  
        merchant_id,  
        MAX(order_created_at) AS latest_order_date,
        COUNT(order_id) AS total_lifetime_orders
    FROM dwh_core.dim_order  
    WHERE is_test = 0
    GROUP BY 1  
),

pending_invoices_by_merchant AS (
    SELECT  
        merchant_id,  
        COUNT(invoice_id) AS count_pending_invoices,  
        SUM(invoice_amount) AS total_pending_invoice_amount  
    FROM dwh_billing.fact_subscription_invoice  
    WHERE payment_status = 'pending'  
    GROUP BY 1  
),

invoice_sequence_context AS (
    SELECT
        i.invoice_id,
        LEAD(i.plan_type) OVER (
            PARTITION BY i.merchant_id
            ORDER BY i.created_at ASC, i.invoice_id ASC 
        ) AS subsequent_plan_type,
        LAG(i.plan_type) OVER (
            PARTITION BY i.merchant_id
            ORDER BY i.created_at ASC, i.invoice_id ASC 
        ) AS previous_plan_type
    FROM dwh_billing.fact_subscription_invoice i
),

staged_billing_events AS (
    SELECT
        b.billing_event_id,
        b.merchant_id,
        b.payment_instrument_id,
        b.invoice_id,
        b.billing_event_timestamp,
        b.merchant_country,
        b.instrument_last4,
        b.billing_amount,
        b.card_holder_name,
        b.card_issuing_country_code,
        b.gateway_response_code,
        b.gateway_error_message,
        mlo.latest_order_date,
        mlo.total_lifetime_orders,
        COALESCE(pib.count_pending_invoices, 0) AS count_pending_invoices,
        COALESCE(pib.total_pending_invoice_amount, 0) AS total_pending_invoice_amount,
        DATEDIFF(day, dm.created_at, CURRENT_DATE) AS merchant_tenure_days,
        dm.email AS merchant_email,
        seq.subsequent_plan_type,
        seq.previous_plan_type,
        ROW_NUMBER() OVER (
            PARTITION BY b.payment_instrument_id 
            ORDER BY b.billing_event_timestamp ASC
        ) AS instrument_attempt_rank
    FROM dwh_billing.fact_billing_charge_event b
    LEFT JOIN dwh_core.dim_merchant dm ON b.merchant_id = dm.id
    LEFT JOIN merchant_lifetime_orders mlo ON b.merchant_id = mlo.merchant_id
    LEFT JOIN pending_invoices_by_merchant pib ON b.merchant_id = pib.merchant_id
    LEFT JOIN invoice_sequence_context seq ON b.invoice_id = seq.invoice_id
    WHERE dm.email NOT LIKE '%@internal-testing.com%'
),

normalized_billing_entities AS (
    SELECT
        s.*,
        cfg.*,
        COALESCE(ma.csm_owner, '') AS enterprise_csm_owner,
        
        -- In-Engine ISO-3166 3-Letter Country Normalization
        -- Eliminates external lookup latency and handles asynchronous ETL NULLs natively
        CASE  
            WHEN s.card_issuing_country_code = 'USA' THEN 'United States'  
            WHEN s.card_issuing_country_code = 'VNM' THEN 'Vietnam'  
            WHEN s.card_issuing_country_code = 'GBR' THEN 'United Kingdom'  
            WHEN s.card_issuing_country_code = 'CAN' THEN 'Canada'  
            WHEN s.card_issuing_country_code = 'AUS' THEN 'Australia'  
            WHEN s.card_issuing_country_code = 'DEU' THEN 'Germany'  
            WHEN s.card_issuing_country_code = 'FRA' THEN 'France'  
            WHEN s.card_issuing_country_code = 'SGP' THEN 'Singapore'  
            WHEN s.card_issuing_country_code = 'HKG' THEN 'Hong Kong'  
            WHEN s.card_issuing_country_code = 'KOR' THEN 'South Korea'  
            WHEN s.card_issuing_country_code = 'JPN' THEN 'Japan'  
            ELSE COALESCE(s.card_issuing_country_code, 'UNKNOWN')  
        END AS normalized_card_issuing_country,

        -- Account Seasoning Evaluation
        CASE 
            WHEN s.merchant_tenure_days >= cfg.cfg_tenured_merchant_days  
             AND s.total_lifetime_orders >= cfg.cfg_tenured_order_volume 
            THEN 1 ELSE 0 
        END AS is_seasoned_merchant

    FROM staged_billing_events s
    CROSS JOIN subscription_activation_config cfg
    LEFT JOIN managed_accounts_lookup ma ON s.merchant_id = ma.enterprise_merchant_id
    WHERE s.instrument_attempt_rank = 1
),

activation_decision_matrix AS (
    SELECT
        n.*,
        COALESCE(n.merchant_country, '') || '-' || COALESCE(n.normalized_card_issuing_country, '') AS country_affinity_pair,
        
        -- High-Priority Technical & Policy Flags
        CASE 
            WHEN REGEXP_COUNT(n.gateway_error_message, 'stolen_card|unauthorized_card|pickup_card') >= 1 
            THEN 1 ELSE 0 
        END AS flag_critical_processor_reject,

        CASE 
            WHEN REGEXP_COUNT(n.gateway_error_message, 'insufficient_funds|card_declined|expired_card') >= 1 
            THEN 1 ELSE 0 
        END AS flag_temporary_billing_failure,

        CASE 
            WHEN n.total_pending_invoice_amount >= n.cfg_max_pending_invoice_amount 
            THEN 1 ELSE 0 
        END AS flag_pending_invoice_balance_high
    FROM normalized_billing_entities n
)

SELECT
    m.billing_event_id,
    m.merchant_id,
    m.merchant_email,
    m.merchant_country,
    m.normalized_card_issuing_country,
    m.country_affinity_pair,
    m.billing_amount,
    m.enterprise_csm_owner,
    m.total_pending_invoice_amount,
    m.is_seasoned_merchant,

    -- Automated Account Activation Recommendation
    CASE
        WHEN m.flag_critical_processor_reject = 1 
            THEN 'SUSPEND_UNAUTHORIZED_INSTRUMENT'
        WHEN m.enterprise_csm_owner <> '' 
            THEN 'ACTIVATE_ENTERPRISE_VIP'
        WHEN m.flag_temporary_billing_failure = 1 
            THEN 'RETRY_ALTERNATIVE_PAYMENT_METHOD'
        WHEN m.flag_pending_invoice_balance_high = 1 
            THEN 'HOLD_FOR_BILLING_RECONCILIATION'
        WHEN m.country_affinity_pair NOT IN ('United States-United States', 'Vietnam-Vietnam', 'United Kingdom-United Kingdom', 'Canada-Canada')
          AND m.is_seasoned_merchant = 0
            THEN 'FLAG_CROSS_BORDER_VALIDATION'
        ELSE 'ACTIVATE_FULL_SERVICE'
    END AS automated_activation_status

FROM activation_decision_matrix m
ORDER BY m.billing_event_id DESC;
