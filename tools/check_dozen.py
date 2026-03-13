import openpyxl

wb = openpyxl.load_workbook(r'c:\Users\irvhu\Desktop\2026 Ventoz VOORRAAD Zeilen.xlsx', data_only=True)
ws = wb.active

current_cat = ''
for ridx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
    cells = list(row)
    while len(cells) < 30:
        cells.append(None)

    cat = str(cells[0] or '').strip()
    product = str(cells[1] or '').strip()
    kleur = str(cells[2] or '').strip()

    if cat:
        current_cat = cat

    if current_cat.lower() == 'dozen' or 'dozen' in cat.lower():
        print(f"Row {ridx:3d}: cat='{cat:10s}' curr_cat='{current_cat:10s}' "
              f"prod='{product:20s}' kleur='{kleur:10s}' "
              f"cells[9]={cells[9]}")
