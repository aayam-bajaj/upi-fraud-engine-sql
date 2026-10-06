USE upi_fraud;

-- How much evidence each rule is worth
DROP TABLE IF EXISTS rule_weights;
CREATE TABLE rule_weights (
  rule_name VARCHAR(30) PRIMARY KEY,
  weight    INT
);
INSERT INTO rule_weights VALUES
  ('shared_device', 20),   -- weak signal on its own
  ('velocity',      40),
  ('new_device',    50),
  ('collect_scam',  60),
  ('mule_chain',    70);

-- One risk score per payment: add up the weights of every rule it triggered
CREATE OR REPLACE VIEW v_risk_scores AS
SELECT f.txn_id,
       SUM(w.weight) AS risk_score,
       GROUP_CONCAT(f.rule_name ORDER BY f.rule_name) AS rules_hit
FROM rule_flags f
JOIN rule_weights w ON w.rule_name = f.rule_name
GROUP BY f.txn_id;

-- Precision vs recall at different alert thresholds
SELECT th.threshold,
       COUNT(*) AS flagged,
       SUM(l.txn_id IS NOT NULL) AS caught,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1) AS precision_pct,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1) AS recall_pct
FROM (SELECT 20 AS threshold UNION ALL SELECT 40 UNION ALL
      SELECT 60 UNION ALL SELECT 80) th
JOIN v_risk_scores s ON s.risk_score >= th.threshold
LEFT JOIN fraud_labels l ON l.txn_id = s.txn_id
GROUP BY th.threshold
ORDER BY th.threshold;