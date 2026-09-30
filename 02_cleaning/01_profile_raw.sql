USE upi_fraud;

-- A. Nulls
SELECT SUM(step IS NULL) n_step, SUM(type IS NULL) n_type, SUM(amount IS NULL) n_amt,
       SUM(name_orig IS NULL) n_orig, SUM(name_dest IS NULL) n_dest
FROM raw_paysim;

-- B. Distinct accounts
SELECT COUNT(DISTINCT name_orig) AS senders, COUNT(DISTINCT name_dest) AS receivers
FROM raw_paysim;

-- C. Fraud vs normal amounts
SELECT type, is_fraud, COUNT(*) AS txns,
       ROUND(AVG(amount),0) AS avg_amount, ROUND(MAX(amount),0) AS max_amount
FROM raw_paysim
WHERE type IN ('TRANSFER','CASH_OUT')
GROUP BY type, is_fraud;

-- D. Fraud that empties the sender's account
SELECT is_fraud, COUNT(*) AS txns, SUM(amount = oldbalance_org) AS emptied_account
FROM raw_paysim
WHERE type IN ('TRANSFER','CASH_OUT')
GROUP BY is_fraud;

-- E. Built-in flag performance
SELECT SUM(is_flagged_fraud) AS flagged,
       SUM(is_flagged_fraud AND is_fraud) AS flagged_and_real_fraud,
       SUM(is_fraud) AS total_fraud
FROM raw_paysim;

-- F. Fund-flow chain test (slow, unindexed: benchmark for Phase 4)
SELECT COUNT(*) AS chained_pairs
FROM raw_paysim t
JOIN raw_paysim c
  ON c.name_orig = t.name_dest AND c.type = 'CASH_OUT' AND c.step >= t.step
WHERE t.type = 'TRANSFER' AND t.is_fraud = 1;