#!/usr/bin/env python3
"""Analyze specific problem products in Excel vs CSV to find discrepancies."""
import openpyxl
import csv
import os

EXCEL = r'c:\Users\irvhu\Desktop\2026 Ventoz VOORRAAD Zeilen.xlsx'
CSV_DIR = r'c:\Users\irvhu\Desktop\ventoz_import_csv'
CSV_FILE = os.path.join(CSV_DIR, 'ventoz_voorraad_zeilen.csv')

PROBLEM_PRODUCTS = ['hobie cat 16', 'polyvalk', 'rs feva', 'topaz uno']

print("=" * 80)
print("PART 1: EXCEL ANALYSIS - Problem products")
print("=" * 80)

wb = openpyxl.load_workbook(EXCEL, data_only=True)
ws = wb.active

current_cat = ''
current_prod = ''

excel_products = {}

for ridx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
    cells = list(row)
    while len(cells) < 30:
        cells.append(None)

    cat = str(cells[0] or '').strip()
    product = str(cells[1] or '').strip()
    kleur = str(cells[2] or '').strip()
    artikelnr = str(cells[3] or '').strip()
    ve_code = str(cells[27] or '').strip()

    voorraad_actueel = cells[9]
    voorraad_besteld = cells[7]
    inkoop = cells[13]

    if cat:
        current_cat = cat
    if product:
        current_prod = product

    effective_prod = product if product else current_prod

    if kleur.lower() in ('totaal', 'totalen', 'total', 'subtotaal'):
        for pp in PROBLEM_PRODUCTS:
            if pp in effective_prod.lower():
                print(f"\n  >>> TOTAAL ROW for '{effective_prod}' row {ridx}: "
                      f"voorraad={voorraad_actueel}, besteld={voorraad_besteld}, "
                      f"inkoop={inkoop}")
        continue

    for pp in PROBLEM_PRODUCTS:
        if pp in effective_prod.lower():
            key = f"{effective_prod}|{artikelnr}"
            if key not in excel_products:
                excel_products[key] = []
            excel_products[key].append({
                'row': ridx,
                'cat': current_cat,
                'product': product,
                'effective': effective_prod,
                'kleur': kleur,
                'art': artikelnr,
                've': ve_code,
                'voorraad': voorraad_actueel,
                'besteld': voorraad_besteld,
                'inkoop': inkoop,
            })

for key, items in sorted(excel_products.items()):
    total = sum(i['voorraad'] or 0 for i in items if i['ve'])
    print(f"\n--- {key} (total stock: {total}) ---")
    for i in items:
        print(f"  Row {i['row']:3d}: prod='{i['product']:30s}' kleur='{i['kleur']:25s}' "
              f"art={i['art']:5s} VE={i['ve']:8s} voorraad={str(i['voorraad']):5s} "
              f"besteld={str(i['besteld']):5s} inkoop={i['inkoop']}")

print("\n\n" + "=" * 80)
print("PART 2: CSV ANALYSIS - Same products")
print("=" * 80)

csv_products = {}
with open(CSV_FILE, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter=';')
    headers = reader.fieldnames
    print(f"\nCSV headers: {headers}\n")

    for cidx, row in enumerate(reader, start=2):
        prod = row.get('productnaam', '').strip()
        for pp in PROBLEM_PRODUCTS:
            if pp in prod.lower():
                key = f"{prod}|{row.get('artikelnummer', '')}"
                if key not in csv_products:
                    csv_products[key] = []
                csv_products[key].append({
                    'csv_row': cidx,
                    'productnaam': prod,
                    'kleur': row.get('kleur', ''),
                    'art': row.get('artikelnummer', ''),
                    've': row.get('leverancier_code', ''),
                    'voorraad': row.get('voorraad_actueel', ''),
                    'besteld': row.get('voorraad_besteld', ''),
                    'inkoop': row.get('inkoopprijs', ''),
                    'categorie': row.get('categorie', ''),
                })

for key, items in sorted(csv_products.items()):
    total = sum(int(i['voorraad'] or 0) for i in items if i['ve'])
    print(f"\n--- {key} (total stock: {total}) ---")
    for i in items:
        print(f"  CSV row {i['csv_row']:3d}: prod='{i['productnaam']:30s}' "
              f"kleur='{i['kleur']:25s}' art={i['art']:5s} VE={i['ve']:8s} "
              f"voorraad={i['voorraad']:5s} besteld={i['besteld']:5s} "
              f"inkoop={i['inkoop']:10s}")

print("\n\n" + "=" * 80)
print("PART 3: TOPAZ UNO - Grouping issue analysis")
print("=" * 80)

topaz_groups = {}
with open(CSV_FILE, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter=';')
    for row in reader:
        prod = row.get('productnaam', '').strip()
        if 'topaz' in prod.lower() and 'uno' in prod.lower():
            kleur = row.get('kleur', '').strip()
            key = f"{prod}|{kleur}"
            if key not in topaz_groups:
                topaz_groups[key] = 0
            topaz_groups[key] += 1

print("\nTopaz Uno variants in CSV:")
for key, count in sorted(topaz_groups.items()):
    print(f"  {key}: {count} VE-codes")

print("\n\n" + "=" * 80)
print("PART 4: GENERAL STATS - Duplicate product+art combinations with different colors")
print("=" * 80)

all_groups = {}
with open(CSV_FILE, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter=';')
    for row in reader:
        prod = row.get('productnaam', '').strip()
        art = row.get('artikelnummer', '').strip()
        kleur = row.get('kleur', '').strip()
        key = f"{prod}|{art}"
        if key not in all_groups:
            all_groups[key] = set()
        all_groups[key].add(kleur)

multi_color = {k: v for k, v in all_groups.items() if len(v) > 1}
print(f"\nProducts with multiple colors (same product+art): {len(multi_color)}")
for key, colors in sorted(multi_color.items()):
    print(f"  {key}: {sorted(colors)}")
