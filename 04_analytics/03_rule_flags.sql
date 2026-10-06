USE upi_fraud;

CREATE TABLE IF NOT EXISTS rule_flags (
  txn_id    BIGINT,
  rule_name VARCHAR(30),
  PRIMARY KEY (txn_id, rule_name)
);
TRUNCATE TABLE rule_flags;

INSERT INTO rule_flags SELECT txn_id, 'velocity'      FROM v_rule_velocity;
INSERT INTO rule_flags SELECT txn_id, 'new_device'    FROM v_rule_new_device;
INSERT INTO rule_flags SELECT txn_id, 'shared_device' FROM v_rule_shared_device;

-- Scorecard (fast now: it only reads the small flags table)
SELECT f.rule_name,
       COUNT(*) AS flagged,
       SUM(l.txn_id IS NOT NULL) AS caught,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1) AS precision_pct,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1) AS recall_pct
FROM rule_flags f
LEFT JOIN fraud_labels l ON l.txn_id = f.txn_id
GROUP BY f.rule_name
UNION ALL
SELECT 'ALL RULES',
       COUNT(*),
       SUM(l.txn_id IS NOT NULL),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1)
FROM (SELECT DISTINCT txn_id FROM rule_flags) d
LEFT JOIN fraud_labels l ON l.txn_id = d.txn_id;