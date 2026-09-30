USE upi_fraud;

DROP TABLE IF EXISTS fraud_labels, upi_transactions, merchants,
                     vpa_devices, devices, vpas, users, dim_bank;

CREATE TABLE dim_bank (
  bank_id     TINYINT PRIMARY KEY,
  bank_name   VARCHAR(50),
  upi_handle  VARCHAR(20)
);

CREATE TABLE users (
  user_id      INT PRIMARY KEY,
  full_name    VARCHAR(80),
  city         VARCHAR(40),
  state        VARCHAR(40),
  age          TINYINT,
  signup_date  DATE
);

CREATE TABLE vpas (
  vpa_id      INT PRIMARY KEY,
  user_id     INT,
  vpa         VARCHAR(60) UNIQUE,
  bank_id     TINYINT,
  created_at  DATETIME
);

CREATE TABLE devices (
  device_id    INT PRIMARY KEY,
  device_hash  CHAR(16),
  os           VARCHAR(10)
);

CREATE TABLE vpa_devices (
  vpa_id      INT,
  device_id   INT,
  first_seen  DATETIME,
  PRIMARY KEY (vpa_id, device_id)
);

CREATE TABLE merchants (
  merchant_id    INT PRIMARY KEY,
  merchant_name  VARCHAR(80),
  category       VARCHAR(30),
  city           VARCHAR(40)
);

CREATE TABLE upi_transactions (
  txn_id        BIGINT PRIMARY KEY,
  txn_ts        DATETIME,
  payer_vpa_id  INT,
  payee_vpa_id  INT NULL,          -- used for P2P and COLLECT
  merchant_id   INT NULL,          -- used for P2M
  txn_type      ENUM('P2P','P2M','COLLECT'),
  amount        DECIMAL(12,2),
  device_id     INT,
  status        ENUM('SUCCESS','FAILED'),
  city          VARCHAR(40)
);

-- The answer key. Our detection rules must never read this table;
-- it is only used afterwards to score them.
CREATE TABLE fraud_labels (
  txn_id      BIGINT PRIMARY KEY,
  fraud_type  VARCHAR(30)
);

SELECT 'schema created' AS status;