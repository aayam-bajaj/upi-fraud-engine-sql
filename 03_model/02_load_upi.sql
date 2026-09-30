USE upi_fraud;

TRUNCATE TABLE dim_bank;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/dim_bank.csv'
INTO TABLE dim_bank
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(bank_id, bank_name, upi_handle);

TRUNCATE TABLE users;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/users.csv'
INTO TABLE users
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(user_id, full_name, city, state, age, signup_date);

TRUNCATE TABLE vpas;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/vpas.csv'
INTO TABLE vpas
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(vpa_id, user_id, vpa, bank_id, created_at);

TRUNCATE TABLE devices;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/devices.csv'
INTO TABLE devices
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(device_id, device_hash, os);

TRUNCATE TABLE vpa_devices;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/vpa_devices.csv'
INTO TABLE vpa_devices
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(vpa_id, device_id, first_seen);

TRUNCATE TABLE merchants;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/merchants.csv'
INTO TABLE merchants
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(merchant_id, merchant_name, category, city);

TRUNCATE TABLE upi_transactions;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/upi_transactions.csv'
INTO TABLE upi_transactions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(txn_id, txn_ts, payer_vpa_id, payee_vpa_id, merchant_id, txn_type, amount, device_id, status, city);

TRUNCATE TABLE fraud_labels;
LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-engine-sql/data/upi/fraud_labels.csv'
INTO TABLE fraud_labels
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(txn_id, fraud_type);

-- quick check
SELECT COUNT(*) AS total_txns FROM upi_transactions;
SELECT fraud_type, COUNT(*) AS n FROM fraud_labels GROUP BY fraud_type;