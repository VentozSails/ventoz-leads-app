import csv

f = open(r'c:\Users\irvhu\Desktop\ventoz_import_csv\ventoz_voorraad_zeilen.csv', 'r', encoding='utf-8-sig')
r = csv.DictReader(f, delimiter=';')
rows = list(r)
f.close()

print("=== 'blokart 5' entries in CSV ===")
for i, row in enumerate(rows, 2):
    p = row.get('product', '').lower()
    if 'blokart' in p and '5' in p:
        print(f"  row {i}: prod='{row['product']:25s}' kleur='{row['kleur']:20s}' "
              f"art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']}")

print("\n=== Row 152 equivalent: art=27, kleur 'rood, wit, rood' ===")
for i, row in enumerate(rows, 2):
    if row.get('artikelnummer', '') == '27' and 'rood' in row.get('kleur', '').lower():
        print(f"  row {i}: prod='{row['product']:30s}' kleur='{row['kleur']:20s}' "
              f"art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']}")

print("\n=== All Laser 4.7 entries ===")
for i, row in enumerate(rows, 2):
    p = row.get('product', '').lower()
    if 'laser 4.7' in p or 'laser 4,7' in p:
        print(f"  row {i}: prod='{row['product']:25s}' kleur='{row['kleur']:25s}' "
              f"art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']}")

print("\n=== All Laser radial entries ===")
for i, row in enumerate(rows, 2):
    p = row.get('product', '').lower()
    if 'radial' in p:
        print(f"  row {i}: prod='{row['product']:25s}' kleur='{row['kleur']:25s}' "
              f"art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']}")

print("\n=== All Hobie Cat 16 entries ===")
for i, row in enumerate(rows, 2):
    p = row.get('product', '').lower()
    if 'hobie' in p and '16' in p:
        print(f"  row {i}: prod='{row['product']:35s}' kleur='{row['kleur']:25s}' "
              f"art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']:4s} "
              f"ean={row['ean']:20s} besteld={row['besteld']:5s}")
