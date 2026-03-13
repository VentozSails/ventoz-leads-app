#!/usr/bin/env python3
"""Check blokart entries in Excel to find naming issues."""
import openpyxl

wb = openpyxl.load_workbook(r'c:\Users\irvhu\Desktop\2026 Ventoz VOORRAAD Zeilen.xlsx', data_only=True)
ws = wb.active

print("=== All rows with 'blokart' in product name ===")
current_product = ''
for ridx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
    cells = list(row)
    while len(cells) < 30:
        cells.append(None)

    product = str(cells[1] or '').strip()
    kleur = str(cells[2] or '').strip()
    art = str(cells[3] or '').strip()
    ve = str(cells[27] or '').strip()
    voorraad = cells[9]

    if product:
        current_product = product

    effective = product if product else current_product

    if 'blokart' in effective.lower():
        print(f'Row {ridx:3d}: product="{product:30s}" effective="{effective:30s}" kleur="{kleur:20s}" art={art:5s} VE={ve:8s} voorraad={voorraad}')
