CREATE DATABASE IF NOT EXISTS upi_fraud;
SELECT 'ok' AS status;

USE upi_fraud;
DROP TABLE IF EXISTS raw_paysim;
CREATE TABLE raw_paysim (
  step             INT,
  type             VARCHAR(10),
  amount           DECIMAL(14,2),
  name_orig        VARCHAR(20),
  oldbalance_org   DECIMAL(14,2),
  newbalance_org   DECIMAL(14,2),
  name_dest        VARCHAR(20),
  oldbalance_dest  DECIMAL(14,2),
  newbalance_dest  DECIMAL(14,2),
  is_fraud         TINYINT,
  is_flagged_fraud TINYINT
) ENGINE=InnoDB;

SELECT 'table created' AS status;