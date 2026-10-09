"""
Utility: Synthetic Operational Settlement Data Generator
Author: Serena Nguyen
Description: Generates sanitized, statistically plausible mock data for testing the
             E-Commerce Operational Transaction pipelines without exposing any proprietary production records.
"""

import pandas as pd
import numpy as np

def generate_mock_settlement_dataset(num_records=50, random_seed=42):
    np.random.seed(random_seed)
    
    settlement_ids = [f"SET_{200000 + i}" for i in range(num_records)]
    merchant_ids = [f"MCH_{10000 + (i % 25)}" for i in range(num_records)]
    shop_ids = [f"SHP_{50000 + (i % 30)}" for i in range(num_records)]
    
    amounts = np.round(np.random.exponential(scale=1200, size=num_records) + 50, 2)
    dispute_rates = np.round(np.random.beta(a=0.5, b=25, size=num_records), 4)
    direct_traffic = np.round(np.random.beta(a=3, b=4, size=num_records), 4)
    cr_rates = np.round(np.random.beta(a=1, b=30, size=num_records), 4)
    
    countries = ['United States', 'Vietnam', 'United Kingdom', 'Canada', 'Australia', 'Germany', 'France']
    merchant_countries = np.random.choice(countries, size=num_records, p=[0.4, 0.2, 0.15, 0.1, 0.05, 0.05, 0.05])
    
    automated_actions = []
    reconciliation_rules = []
    
    for amt, dr, dt in zip(amounts, dispute_rates, direct_traffic):
        if dr > 0.035 or dt > 0.85:
            automated_actions.append('HOLD_ELEVATED_DISPUTE_RESERVE')
            reconciliation_rules.append('Elevated Dispute Ratio / Traffic Anomaly')
        elif amt >= 10000 or dr > 0.015:
            automated_actions.append('ESCALATE_TIER2_FINANCE_SIGNOFF')
            reconciliation_rules.append('Large Disbursement Request (>= $10,000)')
        else:
            automated_actions.append('AUTO_DISBURSE_APPROVED')
            reconciliation_rules.append('Passed Standard Financial Reconciliation')
            
    df = pd.DataFrame({
        'settlement_id': settlement_ids,
        'merchant_id': merchant_ids,
        'shop_id': shop_ids,
        'merchant_country': merchant_countries,
        'requested_amount': amounts,
        'dispute_rate': dispute_rates,
        'direct_traffic_ratio': direct_traffic,
        'conversion_rate_3d': cr_rates,
        'automated_reconciliation_status': automated_actions,
        'reconciliation_rule_summary': reconciliation_rules
    })
    
    return df

if __name__ == '__main__':
    df = generate_mock_settlement_dataset(50)
    output_path = 'mock_transaction_signals.csv'
    df.to_csv(output_path, index=False)
    print(f"Generated {len(df)} sanitized records successfully at {output_path}!")
