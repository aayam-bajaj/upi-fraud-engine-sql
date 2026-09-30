SET GLOBAL local_infile = 1;

SHOW VARIABLES LIKE 'local_infile';


LOAD DATA LOCAL INFILE 'C:/Users/A5286763/OneDrive - Saint-Gobain/Desktop/upi-fraud-sql-engine/data/PS_20174392719_1491204439457_log.csv'
INTO TABLE raw_paysim
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(step, type, amount, name_orig, oldbalance_org, newbalance_org,
 name_dest, oldbalance_dest, newbalance_dest, is_fraud, is_flagged_fraud);