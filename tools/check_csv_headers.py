import csv

f = open(r'c:\Users\irvhu\Desktop\ventoz_import_csv\ventoz_voorraad_zeilen.csv', 'r', encoding='utf-8-sig')
r = csv.DictReader(f, delimiter=';')
print('Headers:', r.fieldnames)
rows = list(r)
f.close()

print(f'Total rows: {len(rows)}')
print()
for i in range(min(5, len(rows))):
    row = rows[i]
    print(f"Row {i+2}: cat={row.get('categorie','?')[:15]:15s} "
          f"prod={row.get('product','?')[:30]:30s} "
          f"kleur={row.get('kleur','?')[:20]:20s} "
          f"art={row.get('artikelnummer','?'):5s} "
          f"ve={row.get('code','?'):10s} "
          f"vr={row.get('voorraad','?'):4s}")

print()
print("--- Hobie Cat rows ---")
for i, row in enumerate(rows):
    if 'hobie' in row.get('product', '').lower() and 'main' in row.get('product', '').lower():
        print(f"Row {i+2}: prod={row.get('product','')[:40]:40s} "
              f"kleur={row.get('kleur','')[:25]:25s} "
              f"art={row.get('artikelnummer',''):5s} "
              f"ve={row.get('code',''):10s} "
              f"vr={row.get('voorraad',''):4s} "
              f"besteld={row.get('besteld',''):15s}")

print()
print("--- Topaz Uno grootzeil rows ---")
for i, row in enumerate(rows):
    if 'topaz' in row.get('product', '').lower() and 'groot' in row.get('product', '').lower():
        print(f"Row {i+2}: prod={row.get('product','')[:40]:40s} "
              f"kleur={row.get('kleur','')[:25]:25s} "
              f"art={row.get('artikelnummer',''):5s} "
              f"ve={row.get('code',''):10s} "
              f"vr={row.get('voorraad',''):4s} "
              f"inkoop={row.get('inkoop',''):10s}")
