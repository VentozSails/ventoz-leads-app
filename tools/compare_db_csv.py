#!/usr/bin/env python3
"""Compare DB export with correct CSV to find all discrepancies."""
import csv
from collections import defaultdict

DB_FILE = r'c:\Users\irvhu\Downloads\inventory_items_rows (1).csv'
CSV_FILE = r'c:\Users\irvhu\Desktop\ventoz_import_csv\ventoz_voorraad_zeilen.csv'

# Load DB export
db_rows = []
with open(DB_FILE, 'r', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f)
    db_rows = list(reader)

# Load correct CSV
csv_rows = []
with open(CSV_FILE, 'r', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f, delimiter=';')
    csv_rows = list(reader)

print(f"DB rows: {len(db_rows)}")
print(f"CSV rows: {len(csv_rows)}")

# === Build lookup structures ===

# DB: group by VE-code (leverancier_code)
db_by_ve = {}
for row in db_rows:
    ve = (row.get('leverancier_code') or '').strip()
    if ve:
        db_by_ve[ve] = row

# CSV: group by VE-code
csv_by_ve = {}
for row in csv_rows:
    ve = (row.get('code') or '').strip()
    if ve:
        csv_by_ve[ve] = row

# DB: group by product name
db_by_product = defaultdict(list)
for row in db_rows:
    name = (row.get('variant_label') or '').strip().lower()
    db_by_product[name].append(row)

# CSV: group by product name
csv_by_product = defaultdict(list)
for row in csv_rows:
    name = (row.get('product') or '').strip().lower()
    csv_by_product[name].append(row)

# === COMPARISON 1: Product-level totals ===
print("\n" + "=" * 100)
print("PRODUCT-LEVEL COMPARISON: stock totals per product")
print("=" * 100)

all_products = sorted(set(list(db_by_product.keys()) + list(csv_by_product.keys())))
mismatches = []

for prod in all_products:
    if not prod:
        continue
    db_items = db_by_product.get(prod, [])
    csv_items = csv_by_product.get(prod, [])
    
    db_stock = sum(int(r.get('voorraad_actueel') or 0) for r in db_items)
    csv_stock = sum(int(r.get('voorraad') or 0) for r in csv_items)
    db_count = len(db_items)
    csv_count = len(csv_items)
    
    if db_stock != csv_stock or db_count != csv_count:
        mismatches.append({
            'product': prod,
            'db_stock': db_stock,
            'csv_stock': csv_stock,
            'db_rows': db_count,
            'csv_rows': csv_count,
        })

if mismatches:
    print(f"\n{len(mismatches)} product(en) met afwijkingen:\n")
    print(f"{'Product':<45s} {'DB stk':>7s} {'CSV stk':>7s} {'Diff':>6s} {'DB rij':>6s} {'CSV rij':>7s}")
    print("-" * 85)
    for m in mismatches:
        diff = m['db_stock'] - m['csv_stock']
        flag = " ***" if diff != 0 else ""
        print(f"{m['product']:<45s} {m['db_stock']:>7d} {m['csv_stock']:>7d} {diff:>+6d} {m['db_rows']:>6d} {m['csv_rows']:>7d}{flag}")
else:
    print("\nAlle producten komen overeen!")

# === COMPARISON 2: VE-code level ===
print("\n" + "=" * 100)
print("VE-CODE COMPARISON: wrong product assignment")
print("=" * 100)

wrong_product = []
wrong_stock = []
missing_in_db = []
extra_in_db = []

for ve, csv_row in csv_by_ve.items():
    db_row = db_by_ve.get(ve)
    csv_prod = (csv_row.get('product') or '').strip()
    csv_stock = int(csv_row.get('voorraad') or 0)
    
    if db_row is None:
        missing_in_db.append({'ve': ve, 'product': csv_prod, 'stock': csv_stock})
        continue
    
    db_prod = (db_row.get('variant_label') or '').strip()
    db_stock = int(db_row.get('voorraad_actueel') or 0)
    
    if db_prod.lower() != csv_prod.lower():
        wrong_product.append({
            've': ve,
            'db_prod': db_prod,
            'csv_prod': csv_prod,
            'db_stock': db_stock,
            'csv_stock': csv_stock,
        })
    elif db_stock != csv_stock:
        wrong_stock.append({
            've': ve,
            'product': csv_prod,
            'db_stock': db_stock,
            'csv_stock': csv_stock,
        })

for ve, db_row in db_by_ve.items():
    if ve not in csv_by_ve:
        extra_in_db.append({
            've': ve,
            'product': (db_row.get('variant_label') or '').strip(),
            'stock': int(db_row.get('voorraad_actueel') or 0),
        })

if wrong_product:
    print(f"\n{len(wrong_product)} VE-codes met VERKEERD PRODUCT:\n")
    print(f"{'VE-code':<15s} {'DB product':<35s} {'Correct product':<35s}")
    print("-" * 85)
    for w in wrong_product:
        print(f"{w['ve']:<15s} {w['db_prod']:<35s} {w['csv_prod']:<35s}")

if wrong_stock:
    print(f"\n{len(wrong_stock)} VE-codes met VERKEERDE VOORRAAD:\n")
    print(f"{'VE-code':<15s} {'Product':<35s} {'DB':>5s} {'CSV':>5s} {'Diff':>6s}")
    print("-" * 70)
    for w in wrong_stock:
        diff = w['db_stock'] - w['csv_stock']
        print(f"{w['ve']:<15s} {w['product']:<35s} {w['db_stock']:>5d} {w['csv_stock']:>5d} {diff:>+6d}")

if missing_in_db:
    print(f"\n{len(missing_in_db)} VE-codes in CSV maar NIET in DB:")
    for m in missing_in_db:
        print(f"  {m['ve']:<15s} {m['product']:<35s} stock={m['stock']}")

if extra_in_db:
    print(f"\n{len(extra_in_db)} VE-codes in DB maar NIET in CSV:")
    for e in extra_in_db:
        print(f"  {e['ve']:<15s} {e['product']:<35s} stock={e['stock']}")

# === COMPARISON 3: Dozen/packaging in DB ===
print("\n" + "=" * 100)
print("DOZEN/VERPAKKINGEN CHECK: should not be in inventory")
print("=" * 100)

BOX_NAMES = {'wit kleinste', 'wit middel', 'midden', 'groot', 'lang standaard',
             'lang groot', 'splash', 'mk ii', 'valk'}
boxes_in_db = []
for row in db_rows:
    name = (row.get('variant_label') or '').strip().lower()
    cat = (row.get('categorie') or '').strip().lower()
    if name in BOX_NAMES or cat == 'dozen':
        boxes_in_db.append({
            'id': row.get('id'),
            'name': row.get('variant_label', '').strip(),
            'cat': row.get('categorie', '').strip(),
        })

if boxes_in_db:
    print(f"\n{len(boxes_in_db)} dozen/verpakkingen gevonden in DB (moeten verwijderd):")
    for b in boxes_in_db:
        print(f"  id={b['id']} name='{b['name']}' cat='{b['cat']}'")
else:
    print("\nGeen dozen in DB gevonden.")

# === SUMMARY ===
print("\n" + "=" * 100)
print("SAMENVATTING")
print("=" * 100)
db_total = sum(int(r.get('voorraad_actueel') or 0) for r in db_rows)
csv_total = sum(int(r.get('voorraad') or 0) for r in csv_rows)
print(f"DB totaal voorraad:  {db_total}")
print(f"CSV totaal voorraad: {csv_total}")
print(f"Verschil:            {db_total - csv_total:+d}")
print(f"Product-mismatches:  {len(mismatches)}")
print(f"VE verkeerd product: {len(wrong_product)}")
print(f"VE verkeerde stock:  {len(wrong_stock)}")
print(f"VE ontbreekt in DB:  {len(missing_in_db)}")
print(f"VE extra in DB:      {len(extra_in_db)}")
print(f"Dozen in DB:         {len(boxes_in_db)}")
