import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';

class _MatchResult {
  final OrderRegel regel;
  final InventoryItem? matchedItem;
  final List<InventoryItem> candidates;
  InventoryItem? selectedItem;
  bool skip;

  _MatchResult({
    required this.regel,
    this.matchedItem,
    this.candidates = const [],
  }) : selectedItem = matchedItem, skip = false;

  bool get hasAutoMatch => matchedItem != null;
  bool get needsManualMatch => matchedItem == null && !skip;
}

/// Shows a dialog after label generation asking whether to update stock.
/// Handles automatic matching by artikelnummer/EAN and manual selection for unmatched items.
Future<void> showStockUpdateAfterShipment(
  BuildContext context,
  Order order,
) async {
  if (order.regels.isEmpty) return;

  final update = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.inventory_2_rounded, color: Color(0xFF1565C0), size: 32),
      title: const Text('Voorraad bijwerken?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Het verzendlabel voor ${order.orderNummer} is aangemaakt.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Producten in deze order:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
              const SizedBox(height: 4),
              ...order.regels.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  Text('${r.aantal}x ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                  Expanded(child: Text(r.productNaam, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Wil je de voorraad automatisch verlagen voor deze producten?',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nee, overslaan')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Ja, bijwerken'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
        ),
      ],
    ),
  );

  if (update != true || !context.mounted) return;

  final svc = InventoryService();
  final allItems = await svc.getAll();
  final matches = <_MatchResult>[];

  for (final regel in order.regels) {
    InventoryItem? autoMatch;

    if (regel.productId.isNotEmpty) {
      autoMatch = allItems.where((it) =>
        it.artikelnummer != null &&
        it.artikelnummer!.isNotEmpty &&
        it.artikelnummer == regel.productId
      ).firstOrNull;

      autoMatch ??= allItems.where((it) =>
        it.eanCode != null &&
        it.eanCode!.isNotEmpty &&
        it.eanCode == regel.productId
      ).firstOrNull;
    }

    if (autoMatch == null && regel.productNaam.isNotEmpty) {
      final nameNorm = regel.productNaam.trim().toLowerCase();
      final byName = allItems.where((it) =>
        it.variantLabel.trim().toLowerCase() == nameNorm
      ).toList();

      if (byName.length == 1) {
        autoMatch = byName.first;
      }
    }

    final candidates = autoMatch != null ? <InventoryItem>[] : allItems;
    matches.add(_MatchResult(regel: regel, matchedItem: autoMatch, candidates: candidates));
  }

  final hasUnmatched = matches.any((m) => m.needsManualMatch);

  if (hasUnmatched && context.mounted) {
    final proceed = await _showMatchingDialog(context, matches, allItems);
    if (!proceed || !context.mounted) return;
  }

  int updated = 0;
  int skipped = 0;
  final errors = <String>[];

  for (final m in matches) {
    final target = m.selectedItem;
    if (target == null || target.id == null || m.skip) {
      skipped++;
      continue;
    }
    try {
      await svc.adjustStock(
        target.id!,
        -m.regel.aantal,
        'Verzending order ${order.orderNummer}',
        bron: 'verzending',
        mutatieType: 'verkoop',
        orderNummer: order.orderNummer,
        klantNaam: order.naam,
      );
      updated++;
    } catch (e) {
      errors.add('${m.regel.productNaam}: $e');
    }
  }

  if (context.mounted) {
    final msg = StringBuffer();
    if (updated > 0) msg.write('$updated product(en) voorraad verlaagd');
    if (skipped > 0) { if (msg.isNotEmpty) msg.write(', '); msg.write('$skipped overgeslagen'); }
    if (errors.isNotEmpty) { if (msg.isNotEmpty) msg.write('. '); msg.write('Fouten: ${errors.join(", ")}'); }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg.toString()),
      backgroundColor: errors.isEmpty ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
      duration: const Duration(seconds: 4),
    ));
  }
}

Future<bool> _showMatchingDialog(
  BuildContext context,
  List<_MatchResult> matches,
  List<InventoryItem> allItems,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(children: [
            Icon(Icons.link, color: Color(0xFFE65100), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Producten koppelen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
          content: SizedBox(
            width: 560,
            height: 400,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFE65100)),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    'Niet alle producten konden automatisch worden gekoppeld.\nSelecteer het juiste voorraaditem of sla over.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B4226)),
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(child: ListView.separated(
                itemCount: matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = matches[i];
                  return _buildMatchRow(m, allItems, setD);
                },
              )),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('Voorraad bijwerken'),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}

Widget _buildMatchRow(
  _MatchResult m,
  List<InventoryItem> allItems,
  void Function(VoidCallback) setD,
) {
  final r = m.regel;
  final matched = m.hasAutoMatch;

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    color: m.skip ? const Color(0xFFF5F5F5) : null,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: matched ? const Color(0xFFD4EDDA) : const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(4)),
          child: Text(matched ? 'Automatisch' : 'Handmatig',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: matched ? const Color(0xFF2E7D32) : const Color(0xFFE65100))),
        ),
        const SizedBox(width: 6),
        Text('${r.aantal}x ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1565C0))),
        Expanded(child: Text(r.productNaam, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        if (r.productId.isNotEmpty) Text(r.productId, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF9CA3AF))),
      ]),
      const SizedBox(height: 4),
      if (matched)
        Row(children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Expanded(child: Text(
            '${m.matchedItem!.variantLabel} — ${m.matchedItem!.kleur} (voorraad: ${m.matchedItem!.voorraadActueel})',
            style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
          )),
        ])
      else
        Row(children: [
          Expanded(
            child: m.skip
                ? const Text('Overgeslagen', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF9CA3AF)))
                : DropdownButtonFormField<int>(
                    initialValue: m.selectedItem?.id,
                    isDense: true, isExpanded: true,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      hintText: 'Selecteer voorraaditem...',
                      hintStyle: const TextStyle(fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5)),
                      isDense: true,
                    ),
                    items: allItems.where((it) => it.id != null).map((it) => DropdownMenuItem(
                      value: it.id,
                      child: Text(
                        '${it.variantLabel} — ${it.kleur} [${it.artikelnummer ?? ""}] (${it.voorraadActueel} stk)',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setD(() {
                      m.selectedItem = v != null ? allItems.firstWhere((it) => it.id == v) : null;
                      m.skip = false;
                    }),
                  ),
          ),
          const SizedBox(width: 6),
          SizedBox(height: 32, child: TextButton(
            onPressed: () => setD(() { m.skip = !m.skip; if (m.skip) m.selectedItem = null; }),
            child: Text(m.skip ? 'Toch koppelen' : 'Overslaan', style: const TextStyle(fontSize: 10)),
          )),
        ]),
    ]),
  );
}
