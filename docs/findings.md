# Profiling findings: PaySim (6,362,620 rows, 743 hourly steps)

- Data is clean: no nulls in key columns.
- Fraud occurs only in TRANSFER (4,097) and CASH_OUT (4,116).
- Fraudulent transactions are far larger on average (about 1.46M vs 174K for CASH_OUT).
- About 98% of fraud (8,034 of 8,213) empties the sender's entire balance; 0 normal transactions do.
- The dataset's built-in flag catches only 16 of 8,213 fraud cases (about 0.2%): baseline to beat.
- Accounts are nearly unique (6.35M senders across 6.36M transactions), and only 1 fraudulent transfer is followed by a cash-out from the receiver. PaySim therefore cannot support velocity or fund-flow detection, so a calibrated India-style UPI simulator is needed for those
