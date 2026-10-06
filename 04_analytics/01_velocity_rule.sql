USE upi_fraud;

-- Rule 1: velocity. 6+ payments from one sender within 10 minutes
CREATE OR REPLACE VIEW v_rule_velocity AS
SELECT txn_id
FROM (
  SELECT txn_id,
         COUNT(*) OVER (
           PARTITION BY payer_vpa_id
           ORDER BY txn_ts
           RANGE BETWEEN INTERVAL 10 MINUTE PRECEDING AND CURRENT ROW
         ) AS txns_10m
  FROM upi_transactions
) x
WHERE txns_10m >= 6;

-- Score it against the hidden answer key
SELECT COUNT(*) AS flagged,
       SUM(l.txn_id IS NOT NULL) AS real_fraud_caught,
       ROUND(100 * SUM(l.txn_id IS NOT NULL) / COUNT(*), 1) AS precision_pct,
       ROUND(100 * SUM(l.txn_id IS NOT NULL) /
             (SELECT COUNT(*) FROM fraud_labels), 1) AS recall_pct
FROM v_rule_velocity r
LEFT JOIN fraud_labels l ON l.txn_id = r.txn_id;

-- Which fraud types did it catch?
SELECT l.fraud_type, COUNT(*) AS caught
FROM v_rule_velocity r
JOIN fraud_labels l ON l.txn_id = r.txn_id
GROUP BY l.fraud_type;