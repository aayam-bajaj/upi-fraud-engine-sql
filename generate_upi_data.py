"""
generate_upi_data.py
--------------------
Builds a SIMULATED India-style UPI world (users, VPAs, devices, merchants,
transactions) and plants known fraud patterns in it.

Run from your project root (the folder that contains 01_raw, 03_model, ...):
    python generate_upi_data.py            # full size (~2M transactions)
    python generate_upi_data.py --small    # quick test (~100K transactions)

Output:
    data/upi/*.csv                  (CSV files, git-ignored)
    03_model/02_load_upi.sql        (loader script with your real paths)

All data is synthetic. Fraud labels go ONLY into fraud_labels.csv so the
detection rules never see them.
"""
import os
import re
import sys

import numpy as np
import pandas as pd
from faker import Faker

# ----------------------------------------------------------------- settings
SMALL = "--small" in sys.argv
SEED = 42
N_USERS = 2_000 if SMALL else 50_000
N_MULES = 60 if SMALL else 300
N_FARM_DEVICES = 8 if SMALL else 25
N_MERCHANTS = 400 if SMALL else 4_000
N_NORMAL_TXNS = 100_000 if SMALL else 2_000_000
N_VELOCITY_BURSTS = 20 if SMALL else 200
N_MULE_CHAINS = 40 if SMALL else 400
N_SCAMMERS = 12 if SMALL else 120

SIM_START = np.datetime64("2026-01-01T00:00:00")
SIM_DAYS = 90

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "data", "upi")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(ROOT, "03_model"), exist_ok=True)

rng = np.random.default_rng(SEED)
fake = Faker("en_IN")
Faker.seed(SEED)

# hour-of-day weights: quiet at night, busy 9am-9pm
HOUR_W = np.array([1, .5, .4, .3, .4, .8, 2, 4, 6, 7, 8, 8,
                   9, 8, 7, 7, 8, 9, 10, 10, 9, 7, 4, 2], dtype=float)
HOUR_P = HOUR_W / HOUR_W.sum()
NIGHT_HOURS = np.array([22, 23, 0, 1, 2, 3])


def td(value, unit):
    return np.timedelta64(int(value), unit)


def random_ts(hour_choices=None):
    """Random timestamp inside the simulation window."""
    day = rng.integers(0, SIM_DAYS)
    if hour_choices is not None:
        hour = rng.choice(hour_choices)
    else:
        hour = rng.choice(24, p=HOUR_P)
    return SIM_START + td(day, "D") + td(hour, "h") + td(rng.integers(0, 3600), "s")


# --------------------------------------------------------------------- banks
banks = pd.DataFrame({
    "bank_id": range(1, 9),
    "bank_name": ["State Bank of India", "HDFC Bank", "ICICI Bank", "Axis Bank",
                  "Yes Bank (PSP)", "Paytm Payments Bank", "Amazon Pay (PSP)", "ICICI (PSP)"],
    "upi_handle": ["oksbi", "okhdfcbank", "okicici", "okaxis",
                   "ybl", "paytm", "apl", "ibl"],
})
BANK_P = np.array([.20, .16, .12, .10, .22, .10, .04, .06])

# -------------------------------------------------------------------- cities
CITY_LIST = [("Mumbai", "Maharashtra", 12), ("Delhi", "Delhi", 12),
             ("Bengaluru", "Karnataka", 11), ("Hyderabad", "Telangana", 8),
             ("Chennai", "Tamil Nadu", 7), ("Kolkata", "West Bengal", 7),
             ("Pune", "Maharashtra", 7), ("Ahmedabad", "Gujarat", 5),
             ("Jaipur", "Rajasthan", 4), ("Lucknow", "Uttar Pradesh", 4),
             ("Surat", "Gujarat", 3), ("Nagpur", "Maharashtra", 3),
             ("Patna", "Bihar", 3), ("Bhopal", "Madhya Pradesh", 3)]
CITY_P = np.array([c[2] for c in CITY_LIST], dtype=float)
CITY_P /= CITY_P.sum()

# --------------------------------------------------------------------- users
print("Building users, VPAs, devices ...")
n_total_users = N_USERS + N_MULES
user_id = np.arange(1, n_total_users + 1)
city_idx = rng.choice(len(CITY_LIST), size=n_total_users, p=CITY_P)
names = [fake.name() for _ in range(n_total_users)]

signup = SIM_START.astype("datetime64[D]") - rng.integers(30, 1500, n_total_users).astype("timedelta64[D]")
# 60% of mule accounts are brand new (opened shortly before/inside the window)
is_mule_user = user_id > N_USERS
new_mule = is_mule_user & (rng.random(n_total_users) < 0.60)
signup[new_mule] = (SIM_START.astype("datetime64[D]")
                    - rng.integers(0, 45, new_mule.sum()).astype("timedelta64[D]"))

users = pd.DataFrame({
    "user_id": user_id,
    "full_name": [n[:80] for n in names],
    "city": [CITY_LIST[i][0] for i in city_idx],
    "state": [CITY_LIST[i][1] for i in city_idx],
    "age": np.clip(rng.normal(34, 11, n_total_users), 18, 75).astype(int),
    "signup_date": signup.astype(str),
})
user_city = users["city"].to_numpy()

# ---------------------------------------------------------------------- VPAs
has_second = rng.random(N_USERS) < 0.20
vpa_user = np.concatenate([user_id[:N_USERS], user_id[:N_USERS][has_second],
                           user_id[N_USERS:]])
n_vpa = len(vpa_user)
vpa_id = np.arange(1, n_vpa + 1)
is_mule_vpa = vpa_user > N_USERS
vpa_bank = rng.choice(np.arange(1, 9), size=n_vpa, p=BANK_P)
handles = banks.set_index("bank_id")["upi_handle"]


def slug(name):
    first = re.sub(r"[^a-z]", "", name.split()[0].lower())
    return first or "user"


vpa_str = [f"{slug(names[u - 1])}{i}@{handles[b]}"
           for i, u, b in zip(vpa_id, vpa_user, vpa_bank)]
vpa_created = (signup[vpa_user - 1].astype("datetime64[s]")
               + rng.integers(0, 30 * 86400, n_vpa).astype("timedelta64[s]"))

vpas = pd.DataFrame({
    "vpa_id": vpa_id, "user_id": vpa_user, "vpa": vpa_str,
    "bank_id": vpa_bank, "created_at": vpa_created.astype(str),
})
vpa_city = user_city[vpa_user - 1]

# ------------------------------------------------------------------- devices
# regular users: device_id == user_id (a user's own VPAs share their phone)
# mules: 70% sit on a small set of "farm" devices, 30% have their own phone
vpa_device = np.zeros(n_vpa, dtype=np.int64)
vpa_device[~is_mule_vpa] = vpa_user[~is_mule_vpa]
mule_pos = np.where(is_mule_vpa)[0]
on_farm = rng.random(len(mule_pos)) < 0.70
farm_ids = N_USERS + 1 + np.arange(N_FARM_DEVICES)
farm_pick = rng.choice(farm_ids, size=len(mule_pos))
solo_pick = N_USERS + N_FARM_DEVICES + 1 + np.arange(len(mule_pos))
vpa_device[mule_pos] = np.where(on_farm, farm_pick, solo_pick)

used_devices = np.unique(vpa_device)
hashes = [f"{a:08x}{b:08x}" for a, b in
          zip(rng.integers(0, 2**32, len(used_devices)),
              rng.integers(0, 2**32, len(used_devices)))]
devices = pd.DataFrame({
    "device_id": used_devices, "device_hash": hashes,
    "os": rng.choice(["Android", "iOS"], size=len(used_devices), p=[.88, .12]),
})
vpa_devices = pd.DataFrame({
    "vpa_id": vpa_id, "device_id": vpa_device,
    "first_seen": vpa_created.astype(str),
})

# ----------------------------------------------------------------- merchants
CATS = ["Grocery", "Food Delivery", "Fuel", "Utilities", "Mobile Recharge",
        "Travel", "Pharmacy", "Electronics", "Fashion", "Entertainment"]
CAT_P = np.array([.22, .18, .10, .10, .12, .07, .07, .05, .06, .03])
merchants = pd.DataFrame({
    "merchant_id": np.arange(1, N_MERCHANTS + 1),
    "merchant_name": [fake.company()[:80] for _ in range(N_MERCHANTS)],
    "category": rng.choice(CATS, size=N_MERCHANTS, p=CAT_P),
    "city": [CITY_LIST[i][0] for i in rng.choice(len(CITY_LIST), N_MERCHANTS, p=CITY_P)],
})

# -------------------------------------------------------- normal transactions
print(f"Generating {N_NORMAL_TXNS:,} normal transactions ...")
activity = rng.lognormal(0, 1.0, n_vpa)
activity[is_mule_vpa] *= 0.5          # mules also have some ordinary activity
p_payer = activity / activity.sum()

n = N_NORMAL_TXNS
payer = rng.choice(n_vpa, size=n, p=p_payer)
ttype = rng.choice(3, size=n, p=[.30, .68, .02])      # 0=P2P 1=P2M 2=COLLECT
payee = rng.integers(0, n_vpa, size=n)
clash = payee == payer
payee[clash] = (payee[clash] + 1) % n_vpa

amount = np.empty(n)
amount[ttype == 0] = rng.lognormal(np.log(500), 1.0, (ttype == 0).sum())
amount[ttype == 1] = rng.lognormal(np.log(300), 1.1, (ttype == 1).sum())
amount[ttype == 2] = rng.lognormal(np.log(700), 0.9, (ttype == 2).sum())
amount = np.clip(np.round(amount, 2), 1, 100_000)

ts = (SIM_START
      + rng.integers(0, SIM_DAYS, n).astype("timedelta64[D]")
      + rng.choice(24, size=n, p=HOUR_P).astype("timedelta64[h]")
      + rng.integers(0, 3600, n).astype("timedelta64[s]"))

TYPE_NAMES = np.array(["P2P", "P2M", "COLLECT"])
normal = pd.DataFrame({
    "txn_ts": ts,
    "payer_vpa_id": payer + 1,
    "payee_vpa_id": pd.array(np.where(ttype == 1, -1, payee + 1), dtype="Int64"),
    "merchant_id": pd.array(np.where(ttype == 1, rng.integers(1, N_MERCHANTS + 1, n), -1), dtype="Int64"),
    "txn_type": TYPE_NAMES[ttype],
    "amount": amount,
    "device_id": vpa_device[payer],
    "status": np.where(rng.random(n) < 0.97, "SUCCESS", "FAILED"),
    "city": vpa_city[payer],
    "fraud_type": None,
})
normal["payee_vpa_id"] = normal["payee_vpa_id"].replace(-1, pd.NA)
normal["merchant_id"] = normal["merchant_id"].replace(-1, pd.NA)

# ----------------------------------------------------------- planted fraud
print("Planting fraud patterns ...")
mule_idx = np.where(is_mule_vpa)[0]          # positions in the vpa arrays
victim_pool = np.where(~is_mule_vpa)[0]
farm_device_ids = farm_ids
fraud_rows = []


def add(payer_i, payee_i, ttype_name, amt, t, device_id, status, label):
    fraud_rows.append({
        "txn_ts": t, "payer_vpa_id": int(payer_i) + 1,
        "payee_vpa_id": int(payee_i) + 1, "merchant_id": pd.NA,
        "txn_type": ttype_name, "amount": round(float(amt), 2),
        "device_id": int(device_id), "status": status,
        "city": vpa_city[payer_i], "fraud_type": label,
    })


# Pattern 1: velocity bursts - a hijacked account fires many payments in minutes
for _ in range(N_VELOCITY_BURSTS):
    victim = rng.choice(victim_pool)
    start = random_ts(NIGHT_HOURS if rng.random() < 0.6 else None)
    payees = rng.choice(mule_idx, size=rng.integers(3, 7), replace=False)
    attacker_device = rng.choice(farm_device_ids)      # NOT the victim's phone
    for _k in range(rng.integers(8, 26)):
        add(victim, rng.choice(payees), "P2P", rng.integers(2000, 20001),
            start + td(rng.integers(0, 600), "s"), attacker_device,
            "SUCCESS" if rng.random() < 0.9 else "FAILED", "VELOCITY_BURST")

# Pattern 2: mule chains - victim -> mule1 -> mule2 -> ... within minutes,
# each hop keeping back a small cut
for _ in range(N_MULE_CHAINS):
    victim = rng.choice(victim_pool)
    chain = rng.choice(mule_idx, size=rng.integers(3, 6), replace=False)
    t = random_ts()
    amt = float(rng.integers(20000, 95001))
    src = victim
    for hop_no, dst in enumerate(chain):
        dev = vpa_device[src]                 # each sender uses their own device
        add(src, dst, "P2P", amt, t, dev, "SUCCESS", "MULE_CHAIN")
        t = t + td(rng.integers(60, 600), "s")
        amt = amt * rng.uniform(0.96, 0.99)
        src = dst

# Pattern 3 (shared devices) is not a transaction type: it is the hidden link.
# Many mules sit on the same "farm" devices, and burst attackers use them too.

# Pattern 4: collect-request scams - a scammer pulls money from many strangers,
# mostly at night; most victims decline (FAILED) but some pay
for _ in range(N_SCAMMERS):
    scammer = rng.choice(mule_idx)
    for _k in range(rng.integers(10, 41)):
        victim = rng.choice(victim_pool)
        night = rng.random() < 0.55
        add(victim, scammer, "COLLECT", rng.integers(3000, 50001),
            random_ts(NIGHT_HOURS if night else None), vpa_device[victim],
            "SUCCESS" if rng.random() < 0.15 else "FAILED", "COLLECT_SCAM")

fraud = pd.DataFrame(fraud_rows)
for col in ("payee_vpa_id", "merchant_id"):
    fraud[col] = fraud[col].astype("Int64")

# ---------------------------------------------------- combine, sort, number
allx = pd.concat([normal, fraud], ignore_index=True)
allx["txn_ts"] = pd.to_datetime(allx["txn_ts"])
allx = allx.sort_values("txn_ts", kind="stable").reset_index(drop=True)
allx.insert(0, "txn_id", np.arange(1, len(allx) + 1, dtype=np.int64))
labels = allx.loc[allx["fraud_type"].notna(), ["txn_id", "fraud_type"]]
txns = allx[["txn_id", "txn_ts", "payer_vpa_id", "payee_vpa_id", "merchant_id",
             "txn_type", "amount", "device_id", "status", "city"]].copy()
txns["txn_ts"] = txns["txn_ts"].dt.strftime("%Y-%m-%d %H:%M:%S")

# ------------------------------------------------------------- write CSV files
print("Writing CSV files ...")
tables = {
    "dim_bank": banks, "users": users, "vpas": vpas, "devices": devices,
    "vpa_devices": vpa_devices, "merchants": merchants,
    "upi_transactions": txns, "fraud_labels": labels,
}
for name, df in tables.items():
    df.to_csv(os.path.join(OUT, f"{name}.csv"), index=False, header=False,
              na_rep=r"\N", lineterminator="\n")
    print(f"  {name:<18}{len(df):>10,} rows")

# --------------------------------------------------------- write loader script
sql = ["USE upi_fraud;", ""]
for name, df in tables.items():
    path = os.path.join(OUT, f"{name}.csv").replace("\\", "/")
    cols = ", ".join(df.columns)
    sql.append(f"TRUNCATE TABLE {name};")
    sql.append(f"LOAD DATA LOCAL INFILE '{path}'\n"
               f"INTO TABLE {name}\n"
               "FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'\n"
               "LINES TERMINATED BY '\\n'\n"
               f"({cols});\n")
sql.append("-- quick check\n"
           "SELECT COUNT(*) AS total_txns FROM upi_transactions;\n"
           "SELECT fraud_type, COUNT(*) AS n FROM fraud_labels GROUP BY fraud_type;")
with open(os.path.join(ROOT, "03_model", "02_load_upi.sql"), "w") as f:
    f.write("\n".join(sql))

fraud_pct = 100 * len(labels) / len(txns)
print(f"\nDone. {len(txns):,} transactions, {len(labels):,} fraud ({fraud_pct:.2f}%).")
print("Next: run 03_model/02_load_upi.sql in MySQL Workbench.")
