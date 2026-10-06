USE upi_fraud;

-- Rule 2: payment made from a device not registered to the payer
CREATE OR REPLACE VIEW v_rule_new_device AS
SELECT t.txn_id
FROM upi_transactions t
LEFT JOIN vpa_devices d
  ON d.vpa_id = t.payer_vpa_id AND d.device_id = t.device_id
WHERE d.vpa_id IS NULL;

-- Rule 3: payment from a device used by 5+ different payer accounts
CREATE OR REPLACE VIEW v_rule_shared_device AS
SELECT t.txn_id
FROM upi_transactions t
JOIN (
  SELECT device_id
  FROM upi_transactions
  GROUP BY device_id
  HAVING COUNT(DISTINCT payer_vpa_id) >= 5
) s ON s.device_id = t.device_id;

-- Everything flagged by any rule so far
CREATE OR REPLACE VIEW v_flagged_any AS
SELECT txn_id FROM v_rule_velocity
UNION
SELECT txn_id FROM v_rule_new_device
UNION
SELECT txn_id FROM v_rule_shared_device;

-- Scorecard: precision and recall for each rule and for all combined
SELECT 'velocity' AS rule, COUNT(*) AS flagged,
       SUM(l.txn_id IS NOT NULL) AS caught,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1) AS precision_pct,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1) AS recall_pct
FROM v_rule_velocity r LEFT JOIN fraud_labels l ON l.txn_id = r.txn_id
UNION ALL
SELECT 'new_device', COUNT(*), SUM(l.txn_id IS NOT NULL),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1)
FROM v_rule_new_device r LEFT JOIN fraud_labels l ON l.txn_id = r.txn_id
UNION ALL
SELECT 'shared_device', COUNT(*), SUM(l.txn_id IS NOT NULL),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1)
FROM v_rule_shared_device r LEFT JOIN fraud_labels l ON l.txn_id = r.txn_id
UNION ALL
SELECT 'ALL RULES', COUNT(*), SUM(l.txn_id IS NOT NULL),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1)
FROM v_flagged_any r LEFT JOIN fraud_labels l ON l.txn_id = r.txn_id;

-- What is still slipping through, by fraud type
SELECT l.fraud_type, COUNT(*) AS total,
       SUM(f.txn_id IS NOT NULL) AS caught,
       ROUND(100*SUM(f.txn_id IS NOT NULL)/COUNT(*),1) AS recall_pct
FROM fraud_labels l LEFT JOIN v_flagged_any f ON f.txn_id = l.txn_id
GROUP BY l.fraud_type;