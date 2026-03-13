import openpyxl

wb = openpyxl.load_workbook(r'c:\Users\irvhu\Desktop\2026 Ventoz VOORRAAD Zeilen.xlsx', data_only=True)
ws = wb.active

print("=== Excel rows 135-170: Laser transition area ===")
for ridx in range(135, 171):
    row = list(ws.iter_rows(min_row=ridx, max_row=ridx, values_only=True))[0]
    cells = list(row)
    while len(cells) < 30:
        cells.append(None)
    prod = str(cells[1] or '').strip()
    kleur = str(cells[2] or '').strip()
    art = str(cells[3] or '').strip()
    ve = str(cells[27] or '').strip()
    vr = cells[9]
    marker = ' <-- NEW PRODUCT' if prod else ''
    if not prod and not kleur and not art and not ve:
        marker = ' <-- EMPTY SEPARATOR'
    print(f"Row {ridx:3d}: prod='{prod:30s}' kleur='{kleur:25s}' "
          f"art={art:5s} VE={ve:10s} vr={str(vr):5s}{marker}")
