USE upi_fraud;

-- Index on payer + time (the chain tracer looks up "what did this account
-- send next?" thousands of times, so it needs this)
CREATE INDEX idx_txn_payer_ts ON upi_transactions (payer_vpa_id, txn_ts);

-- Rule 4: collect scam. A payee pulling money from 6+ different people
CREATE OR REPLACE VIEW v_rule_collect_scam AS
SELECT t.txn_id
FROM upi_transactions t
JOIN (
  SELECT payee_vpa_id
  FROM upi_transactions
  WHERE txn_type = 'COLLECT'
  GROUP BY payee_vpa_id
  HAVING COUNT(DISTINCT payer_vpa_id) >= 6
) s ON s.payee_vpa_id = t.payee_vpa_id
WHERE t.txn_type = 'COLLECT';

DELETE FROM rule_flags WHERE rule_name = 'collect_scam';
INSERT INTO rule_flags SELECT txn_id, 'collect_scam' FROM v_rule_collect_scam;

-- Rule 5: mule chains, traced with a recursive CTE.
-- Start from large payments, then repeatedly find "the receiver sent ~the same
-- amount onward within 10 minutes". Keep chains with 3+ hops.
DELETE FROM rule_flags WHERE rule_name = 'mule_chain';
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

-- Scorecard: each rule, then all rules combined
SELECT f.rule_name, COUNT(*) AS flagged,
       SUM(l.txn_id IS NOT NULL) AS caught,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1) AS precision_pct,
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1) AS recall_pct
FROM rule_flags f LEFT JOIN fraud_labels l ON l.txn_id = f.txn_id
GROUP BY f.rule_name
UNION ALL
SELECT 'ALL RULES', COUNT(*), SUM(l.txn_id IS NOT NULL),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/COUNT(*),1),
       ROUND(100*SUM(l.txn_id IS NOT NULL)/(SELECT COUNT(*) FROM fraud_labels),1)
FROM (SELECT DISTINCT txn_id FROM rule_flags) d
LEFT JOIN fraud_labels l ON l.txn_id = d.txn_id;