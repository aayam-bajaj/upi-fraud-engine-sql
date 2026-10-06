USE upi_fraud;

CREATE TABLE IF NOT EXISTS fraud_alerts (
  txn_id     BIGINT PRIMARY KEY,
  risk_score INT,
  rules_hit  VARCHAR(200),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pipeline_runs (
  run_id        INT AUTO_INCREMENT PRIMARY KEY,
  started_at    DATETIME,
  finished_at   DATETIME,
  threshold     INT,
  rule_flags    INT,
  alerts_raised INT
);

DROP PROCEDURE IF EXISTS sp_refresh_fraud_alerts;
DELIMITER $$
CREATE PROCEDURE sp_refresh_fraud_alerts(IN p_threshold INT)
BEGIN
  DECLARE v_start DATETIME DEFAULT NOW();
  DECLARE v_flags INT;
  DECLARE v_alerts INT;

  -- 1. rebuild rule flags
  TRUNCATE TABLE rule_flags;
  INSERT INTO rule_flags SELECT txn_id, 'velocity'      FROM v_rule_velocity;
  INSERT INTO rule_flags SELECT txn_id, 'new_device'    FROM v_rule_new_device;
  INSERT INTO rule_flags SELECT txn_id, 'shared_device' FROM v_rule_shared_device;
  INSERT INTO rule_flags SELECT txn_id, 'collect_scam'  FROM v_rule_collect_scam;

  INSERT INTO rule_flags (txn_id, rule_name)
  WITH RECURSIVE chain AS (
    SELECT txn_id AS seed_txn, txn_id, payee_vpa_id AS next_payer,
           txn_ts, amount, 1 AS hop
    FROM upi_transactions
    WHERE txn_type = 'P2P' AND status = 'SUCCESS' AND amount >= 20000
    UNION ALL
    SELECT c.seed_txn, t.txn_id, t.payee_vpa_id, t.txn_ts, t.amount, c.hop + 1
    FROM chain c
    JOIN upi_transactions t
      ON t.payer_vpa_id = c.next_payer
     AND t.txn_ts >  c.txn_ts
     AND t.txn_ts <= c.txn_ts + INTERVAL 10 MINUTE
     AND t.amount BETWEEN c.amount * 0.90 AND c.amount
     AND t.txn_type = 'P2P' AND t.status = 'SUCCESS'
    WHERE c.hop < 6
  ),
  long_chains AS (
    SELECT seed_txn FROM chain GROUP BY seed_txn HAVING MAX(hop) >= 3
  )
  SELECT DISTINCT c.txn_id, 'mule_chain'
  FROM chain c JOIN long_chains l ON l.seed_txn = c.seed_txn;

  -- 2. rebuild alerts from the risk score
  TRUNCATE TABLE fraud_alerts;
  INSERT INTO fraud_alerts (txn_id, risk_score, rules_hit)
  SELECT txn_id, risk_score, rules_hit
  FROM v_risk_scores
  WHERE risk_score >= p_threshold;

  -- 3. log the run
  SELECT COUNT(*) INTO v_flags  FROM rule_flags;
  SELECT COUNT(*) INTO v_alerts FROM fraud_alerts;
  INSERT INTO pipeline_runs (started_at, finished_at, threshold, rule_flags, alerts_raised)
  VALUES (v_start, NOW(), p_threshold, v_flags, v_alerts);
END$$
DELIMITER ;