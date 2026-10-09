-- ==============================================================================
-- Pipeline 03: Financial Settlement & Cashflow Reconciliation Datamart
-- Description: Reconciles daily merchant withdrawal disbursements against rolling
--              order fulfillment milestones, pending dispute exposure, and historical
--              merchant ledger balances using dynamic historical windowing.
-- Architecture: Config-Driven CTE + Parameterized Ledger Reconciliation Thresholds
-- Grain: 1 Row per settlement_id
-- Engine: Amazon Redshift SQL / PostgreSQL Compatible
-- ==============================================================================

WITH reconciliation_config AS (
    -- Config-driven policy thresholds for automated financial disbursements
    SELECT
        10000.0  AS cfg_large_disbursement_review_threshold, -- Threshold requiring second-tier finance signoff ($10k)
        0.035    AS cfg_max_permissible_dispute_ratio,       -- Allowable dispute rate threshold (3.5%)
        0.20     AS cfg_min_reserve_holdback_percentage      -- Mandatory rolling reserve holdback
),

base_settlement_requests AS (
    SELECT 
        r.settlement_id,
        r.merchant_id,
        r.store_segment,
        r.requested_amount,
        r.reserve_hold_amount,
        r.created_at AS settlement_requested_at
    FROM dwh_finance.fact_settlement_request r
    WHERE r.status = 'pending_reconciliation'
),

restricted_destination_check AS (
    SELECT 
        s.settlement_id,
        MAX(CASE WHEN reg.restricted_email IS NOT NULL THEN 1 ELSE 0 END) AS is_destination_restricted,
        LISTAGG(DISTINCT reg.restricted_email, ', ') WITHIN GROUP (ORDER BY reg.restricted_email) AS flagged_destination_emails
    FROM base_settlement_requests s
    LEFT JOIN dwh_finance.fact_merchant_payout_setting p ON s.merchant_id = p.merchant_id
    JOIN dwh_finance.ref_restricted_account_registry reg 
        ON LOWER(TRIM(p.payout_destination_email)) = LOWER(TRIM(reg.restricted_email))
    GROUP BY 1
),

fulfillment_sla_tracking AS (
    SELECT 
        order_id,
        MIN(first_carrier_scan_at) AS first_carrier_scan_at
    FROM dwh_fulfillment.fact_order_shipment
    GROUP BY 1
),

order_delivery_reconciliation AS (
    SELECT 
        f.shop_id,
        f.order_amount,
        CASE 
            WHEN DATEDIFF(day, f.order_created_at::DATE, CURRENT_DATE::DATE) <= 120 THEN 
                CASE 
                    WHEN f.dispute_id IS NOT NULL THEN 'disputed_transaction' 
                    WHEN f.order_amount = f.refund_amount THEN 'fully_refunded' 
                    WHEN (CASE WHEN f.tracking_number IS NULL THEN DATEDIFF(day, f.order_created_at, CURRENT_DATE::DATE) END) >= 14 THEN 'unfulfilled_exceeds_14d' 
                    WHEN f.tracking_number IS NOT NULL THEN 
                        CASE 
                            WHEN DATEDIFF(day, f.order_created_at, ft.first_carrier_scan_at) < 0 THEN 'carrier_scan_precedes_order' 
                            WHEN f.distinct_customers_same_tracking >= 2 THEN 'duplicate_tracking_number' 
                            WHEN f.tracking_dest_country IS NOT NULL AND f.tracking_dest_country != f.shipping_country_name THEN 'destination_country_mismatch' 
                        END 
                END 
        END AS shipment_reconciliation_flag
    FROM dwh_core.fact_order_daily f
    LEFT JOIN fulfillment_sla_tracking ft ON ft.order_id = f.order_id
),

pending_dispute_reserves AS (
    SELECT 
        m.merchant_id,
        SUM(COALESCE(d.dispute_amount_usd, 0)) AS total_pending_dispute_reserve_usd
    FROM dwh_core.dim_store m
    JOIN (
        SELECT shop_id, order_id, MAX(dispute_amount_usd) AS dispute_amount_usd
        FROM dwh_finance.fact_chargebacks
        WHERE LOWER(status) = 'pending_arbitration'
        GROUP BY 1, 2
    ) d ON m.shop_id = d.shop_id
    GROUP BY 1
),

shipment_variance_exposure AS (
    SELECT 
        s.settlement_id,
        (
            COALESCE(
                SUM(
                    CASE WHEN r.shipment_reconciliation_flag IN (
                        'destination_country_mismatch',
                        'unfulfilled_exceeds_14d',
                        'carrier_scan_precedes_order',
                        'duplicate_tracking_number'
                    ) THEN r.order_amount END
                ), 0
            ) 
            + COALESCE(MAX(pdr.total_pending_dispute_reserve_usd), 0)
        ) AS total_unfulfilled_or_disputed_exposure
    FROM base_settlement_requests s
    LEFT JOIN dwh_core.dim_store st ON s.merchant_id = st.merchant_id
    LEFT JOIN order_delivery_reconciliation r ON st.shop_id = r.shop_id
    LEFT JOIN pending_dispute_reserves pdr ON s.merchant_id = pdr.merchant_id
    GROUP BY 1
),

merchant_portfolio_summary AS (
    SELECT 
        s.settlement_id,
        s.merchant_id,
        MAX(st.store_segment) AS store_segment,
        SUM(st.total_order_count) AS total_orders,
        SUM(st.total_disputed_orders)::FLOAT / NULLIF(SUM(st.total_order_count), 0) AS portfolio_dispute_rate
    FROM base_settlement_requests s
    LEFT JOIN dwh_core.dim_store st ON s.merchant_id = st.merchant_id
    GROUP BY 1, 2
),

daily_merchant_ledger AS (
    SELECT 
        s.settlement_id,
        s.merchant_id,
        s.requested_amount,
        
        -- Dynamic Historical Windowing: Evaluates net ledger balance at request time
        (
            COALESCE(b.available_balance, 0)
            - COALESCE(s.requested_amount, 0)
            - COALESCE(p.pending_payout_hold, 0)
            - COALESCE(b.rolling_reserve_balance, 0)
        ) AS projected_remaining_balance
    FROM base_settlement_requests s
    LEFT JOIN dwh_finance.fact_merchant_account_balance b ON s.merchant_id = b.merchant_id
    LEFT JOIN (
        SELECT 
            merchant_id, 
            SUM(requested_amount) AS pending_payout_hold
        FROM base_settlement_requests
        GROUP BY 1
    ) p ON s.merchant_id = p.merchant_id
)

SELECT 
    s.settlement_id,
    s.merchant_id,
    s.store_segment,
    s.requested_amount,
    s.settlement_requested_at,
    
    -- Financial Reconciliation Flags
    COALESCE(rdc.is_destination_restricted, 0) AS is_destination_restricted,
    rdc.flagged_destination_emails,
    
    sve.total_unfulfilled_or_disputed_exposure,
    mps.portfolio_dispute_rate,
    dml.projected_remaining_balance,
    
    -- Calculated Eligible Disbursement Amount (Requested minus exposure holdbacks)
    GREATEST(0, s.requested_amount - sve.total_unfulfilled_or_disputed_exposure) AS net_eligible_disbursement_amount,

    -- Automated Reconciliation Decision Recommendation
    CASE 
        WHEN COALESCE(rdc.is_destination_restricted, 0) = 1 
            THEN 'HOLD_RESTRICTED_RECIPIENT'
        WHEN dml.projected_remaining_balance < 0 
            THEN 'HOLD_INSUFFICIENT_LEDGER_BALANCE'
        WHEN s.requested_amount >= cfg.cfg_large_disbursement_review_threshold 
            THEN 'ESCALATE_TIER2_FINANCE_SIGNOFF'
        WHEN sve.total_unfulfilled_or_disputed_exposure >= s.requested_amount 
            THEN 'HOLD_SHIPMENT_EXPOSURE_VARIANCE'
        WHEN mps.portfolio_dispute_rate >= cfg.cfg_max_permissible_dispute_ratio 
            THEN 'HOLD_ELEVATED_DISPUTE_RESERVE'
        ELSE 'AUTO_DISBURSE_APPROVED'
    END AS automated_reconciliation_status

FROM base_settlement_requests s
CROSS JOIN reconciliation_config cfg
LEFT JOIN restricted_destination_check rdc ON s.settlement_id = rdc.settlement_id
LEFT JOIN shipment_variance_exposure sve ON s.settlement_id = sve.settlement_id
LEFT JOIN merchant_portfolio_summary mps ON s.settlement_id = mps.settlement_id
LEFT JOIN daily_merchant_ledger dml ON s.settlement_id = dml.settlement_id
ORDER BY s.settlement_id DESC;
