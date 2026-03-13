import csv

DB = r'c:\Users\irvhu\Downloads\inventory_items_rows (2).csv'
CSV = r'c:\Users\irvhu\Desktop\ventoz_import_csv\ventoz_voorraad_zeilen.csv'

with open(DB, 'r', encoding='utf-8-sig') as f:
    db_rows = list(csv.DictReader(f))

with open(CSV, 'r', encoding='utf-8-sig') as f:
    csv_rows = list(csv.DictReader(f, delimiter=';'))

db_total = sum(int(r.get('voorraad_actueel') or 0) for r in db_rows)
csv_total = sum(int(r.get('voorraad') or 0) for r in csv_rows)

print(f"DB rows: {len(db_rows)}, total stock: {db_total}")
print(f"CSV rows: {len(csv_rows)}, total stock: {csv_total}")

ids = [int(r['id']) for r in db_rows]
print(f"DB ID range: {min(ids)} - {max(ids)}")

# Check if old rows (from previous import) still exist
old_rows = [r for r in db_rows if int(r['id']) < 1157]
print(f"Old rows (id < 1157): {len(old_rows)}")

# Check for EAN-as-VE-code issues
ean_as_ve = []
for r in db_rows:
    ve = (r.get('leverancier_code') or '').strip()
    if ve and len(ve) > 10 and ve.startswith('87'):
        ean_as_ve.append(r)

print(f"EAN-as-VE-code rows: {len(ean_as_ve)}")
for r in ean_as_ve:
    print(f"  id={r['id']} ve={r['leverancier_code']} prod={r['variant_label']} stock={r['voorraad_actueel']}")

# Check specific problem products
print("\n=== Problem products in DB ===")
for name in ['hobie cat 16 main', 'polyvalk rolfok', 'rs feva main', 'laser pico main', 'blokart 5']:
    items = [r for r in db_rows if name in (r.get('variant_label') or '').lower()]
    total = sum(int(r.get('voorraad_actueel') or 0) for r in items)
    print(f"\n{name}: {len(items)} rows, stock={total}")
    for r in items:
        print(f"  id={r['id']:5s} ve={r.get('leverancier_code',''):15s} "
              f"kleur={r.get('kleur',''):20s} art={r.get('artikelnummer',''):5s} "
              f"stock={r.get('voorraad_actueel',''):5s}")

# Overall VE-code comparison
db_ves = set((r.get('leverancier_code') or '').strip() for r in db_rows if r.get('leverancier_code'))
csv_ves = set((r.get('code') or '').strip() for r in csv_rows if r.get('code'))

print(f"\nDB VE-codes: {len(db_ves)}")
print(f"CSV VE-codes: {len(csv_ves)}")
print(f"Matching: {len(db_ves & csv_ves)}")
print(f"Only in DB: {len(db_ves - csv_ves)}")
print(f"Only in CSV: {len(csv_ves - db_ves)}")

only_db = db_ves - csv_ves
if only_db:
    print(f"\nVE-codes only in DB (should not exist):")
    for ve in sorted(only_db):
        r = next(r for r in db_rows if r.get('leverancier_code', '').strip() == ve)
        print(f"  {ve:20s} prod={r['variant_label']:30s} stock={r['voorraad_actueel']}")
