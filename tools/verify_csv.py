#!/usr/bin/env python3
"""Verify the generated CSV for data quality issues."""
import csv
import os

path = r'c:\Users\irvhu\Desktop\ventoz_import_csv\ventoz_voorraad_zeilen.csv'

with open(path, encoding='utf-8-sig') as f:
    reader = csv.DictReader(f, delimiter=';')
    rows = list(reader)

print(f'Total rows: {len(rows)}')

# Check VE code uniqueness
ve_codes = {}
for i, r in enumerate(rows):
    vc = r.get('code', '').strip()
    if vc:
        if vc in ve_codes:
            ve_codes[vc].append(i + 2)
        else:
            ve_codes[vc] = [i + 2]

dupes = {k: v for k, v in ve_codes.items() if len(v) > 1}
if dupes:
    print(f'\nDuplicate VE-codes ({len(dupes)}):')
    for k, v in sorted(dupes.items()):
        print(f'  {k}: rows {v}')

# Check for suspicious voorraad values
suspicious = []
for i, r in enumerate(rows):
    v = r.get('voorraad', '').strip()
    if v and v != '0':
        try:
            val = int(v)
            if val > 200 or val < -10:
                suspicious.append((i + 2, r['product'], r['code'], val))
        except ValueError:
            suspicious.append((i + 2, r['product'], r['code'], v))

if suspicious:
    print(f'\nSuspicious voorraad values ({len(suspicious)}):')
    for row_num, product, code, val in suspicious:
        print(f'  Row {row_num}: {product[:30]:30s} | {code:10s} | voorraad={val}')

# Check for rows without product name
no_product = [(i + 2, r) for i, r in enumerate(rows) if not r.get('product', '').strip()]
print(f'\nRows without product name: {no_product[:5]}')

# Check totaal row not present
totaal = [r for r in rows if 'totaal' in r.get('product', '').lower() or 'totaal' in r.get('kleur', '').lower()]
print(f'Totaal rows (should be 0): {len(totaal)}')

# Check box rows not present
box_names = {'wit kleinste', 'wit middel', 'midden', 'groot', 'lang standaard',
             'lang groot', 'splash', 'mk ii', 'valk'}
box_rows_found = [r for r in rows if r.get('product', '').lower().strip() in box_names]
print(f'Box rows (should be 0): {len(box_rows_found)}')

# Count with stock > 0
with_stock = len([r for r in rows if r.get('voorraad', '').strip() and int(r.get('voorraad', '0') or '0') > 0])
print(f'\nRows with stock > 0: {with_stock}')

# Count unique products
products = set(r.get('product', '').strip() for r in rows if r.get('product', '').strip())
print(f'Unique product names: {len(products)}')

# Verify EAN codes look valid (13 digits)
for i, r in enumerate(rows):
    ean = r.get('ean', '').strip()
    if ean and (len(ean) != 13 or not ean.isdigit()):
        print(f'  Warning: Invalid EAN at row {i+2}: "{ean}" for {r["product"][:30]} | {r["code"]}')
