# Performance benchmarks (2,008,179-row transactions table, MySQL 8.0.46, laptop)

Indexes added: (payer_vpa_id, txn_ts), (device_id, payer_vpa_id),
(txn_type, payee_vpa_id, payer_vpa_id)

| Rule | Before | After | Change |
|---|---|---|---|
| velocity (window function) | 18.5s | 9.6s | ~2x faster |
| new_device | 3.9s | 1.0s | ~4x faster |
| shared_device | 3.9s | 0.19s | ~20x faster |
| collect_scam | 2.3s | 0.05s | ~48x faster |
| mule_chain (recursive CTE) | 7.7s | 4.0s | ~2x faster |

Notes
- shared_device was answered entirely from the covering index (EXPLAIN ANALYZE).
- velocity improves only modestly: the window function still has to work through all 2M rows.
- The first mule_chain run right after the index builds took 57s (cold buffer pool);
  warm reruns took ~4s. Timings are single runs on one laptop, not rigorous benchmarks.