import csv

f = open(r'c:\Users\irvhu\Desktop\ventoz_import_csv\ventoz_voorraad_zeilen.csv', 'r', encoding='utf-8-sig')
r = csv.DictReader(f, delimiter=';')
rows = list(r)
f.close()

print("=== blokart 2.x entries ===")
for row in rows:
    if 'blokart 2' in row.get('product', '').lower():
        print(f"  prod={row['product']:25s} kleur={row['kleur']:20s} art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']:4s}")

print("\n=== Hobie Cat 16 main entries ===")
for row in rows:
    if 'hobie' in row.get('product', '').lower() and 'main' in row.get('product', '').lower() and '16' in row.get('product', ''):
        print(f"  prod={row['product']:25s} kleur={row['kleur']:25s} art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']:4s} best={row['besteld']:4s}")

print("\n=== Topaz Uno grootzeil entries ===")
for row in rows:
    if 'topaz' in row.get('product', '').lower() and 'groot' in row.get('product', '').lower():
        print(f"  prod={row['product']:25s} kleur={row['kleur']:25s} art={row['artikelnummer']:5s} ve={row['code']:10s} vr={row['voorraad']:4s}")

print("\n=== Products with same name but different colors (grouping check) ===")
from collections import defaultdict
groups = defaultdict(set)
for row in rows:
    prod = row.get('product', '').strip()
    kleur = row.get('kleur', '').strip()
    if prod:
        groups[prod.lower()].add(kleur)

multi_color = {k: v for k, v in groups.items() if len(v) > 1 and 'topaz' in k}
for name, colors in sorted(multi_color.items()):
    print(f"  {name}: {sorted(colors)}")
