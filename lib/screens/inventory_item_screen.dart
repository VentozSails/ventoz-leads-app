import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';

class InventoryItemScreen extends StatefulWidget {
  final int? itemId;

  const InventoryItemScreen({super.key, this.itemId});

  @override
  State<InventoryItemScreen> createState() => _InventoryItemScreenState();
}

class _InventoryItemScreenState extends State<InventoryItemScreen> {
  static const _headerColor = Color(0xFF1E3A5F);

  final _inventoryService = InventoryService();
  final _userService = UserService();

  final _artikelnummerCtrl = TextEditingController();
  final _eanCodeCtrl = TextEditingController();
  final _variantLabelCtrl = TextEditingController();
  final _kleurCtrl = TextEditingController();
  final _leverancierCodeCtrl = TextEditingController();
  final _opmerkingCtrl = TextEditingController();
  final _minimaleVoorraadCtrl = TextEditingController();
  final _besteldeHoeveelheidCtrl = TextEditingController();
  final _inkoopPrijsCtrl = TextEditingController();
  final _vliegtuigKostenCtrl = TextEditingController();
  final _invoertaxAdminCtrl = TextEditingController();
  final _inkoopTotaalCtrl = TextEditingController();
  final _nettoInkoopCtrl = TextEditingController();
  final _nettoInkoopWaardeCtrl = TextEditingController();
  final _importKostenCtrl = TextEditingController();
  final _brutoInkoopCtrl = TextEditingController();
  final _verkoopprijsInclCtrl = TextEditingController();
  final _verkoopprijsExclCtrl = TextEditingController();
  final _verkoopWaardeExclCtrl = TextEditingController();
  final _verkoopWaardeInclCtrl = TextEditingController();
  final _margeCtrl = TextEditingController();
  final _gewichtProductCtrl = TextEditingController();
  final _gewichtVerpakkingCtrl = TextEditingController();

  InventoryItem? _item;
  List<InventoryMutation> _mutations = [];
  bool _loading = true;
  bool _saving = false;
  String? _vervoerMethode;

  static const _vervoerOpties = ['vliegtuig', 'trein', 'boot', 'overig'];
  static const _bronOpties = ['handmatig', 'correctie', 'verkoop_app', 'retour'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _artikelnummerCtrl.dispose();
    _eanCodeCtrl.dispose();
    _variantLabelCtrl.dispose();
    _kleurCtrl.dispose();
    _leverancierCodeCtrl.dispose();
    _opmerkingCtrl.dispose();
    _minimaleVoorraadCtrl.dispose();
    _besteldeHoeveelheidCtrl.dispose();
    _inkoopPrijsCtrl.dispose();
    _vliegtuigKostenCtrl.dispose();
    _invoertaxAdminCtrl.dispose();
    _inkoopTotaalCtrl.dispose();
    _nettoInkoopCtrl.dispose();
    _nettoInkoopWaardeCtrl.dispose();
    _importKostenCtrl.dispose();
    _brutoInkoopCtrl.dispose();
    _verkoopprijsInclCtrl.dispose();
    _verkoopprijsExclCtrl.dispose();
    _verkoopWaardeExclCtrl.dispose();
    _verkoopWaardeInclCtrl.dispose();
    _margeCtrl.dispose();
    _gewichtProductCtrl.dispose();
    _gewichtVerpakkingCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.voorraadBeheren) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geen toegang tot voorraadbeheer.'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    try {
      if (widget.itemId != null) {
        _item = await _inventoryService.getById(widget.itemId!);
        _mutations = await _inventoryService.getMutations(widget.itemId!);
        if (_item != null) _populateFromItem(_item!);
      } else {
        _item = null;
        _mutations = [];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryItemScreen load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _populateFromItem(InventoryItem item) {
    _artikelnummerCtrl.text = item.artikelnummer ?? '';
    _eanCodeCtrl.text = item.eanCode ?? '';
    _variantLabelCtrl.text = item.variantLabel;
    _kleurCtrl.text = item.kleur;
    _leverancierCodeCtrl.text = item.leverancierCode ?? '';
    _opmerkingCtrl.text = item.opmerking ?? '';
    _minimaleVoorraadCtrl.text = item.voorraadMinimum.toString();
    _besteldeHoeveelheidCtrl.text = item.voorraadBesteld.toString();
    _inkoopPrijsCtrl.text = item.inkoopPrijs?.toStringAsFixed(2) ?? '';
    _vliegtuigKostenCtrl.text = item.vliegtuigKosten?.toStringAsFixed(2) ?? '';
    _invoertaxAdminCtrl.text = item.invoertaxAdmin?.toStringAsFixed(2) ?? '';
    _inkoopTotaalCtrl.text = item.inkoopTotaal?.toStringAsFixed(2) ?? '';
    _nettoInkoopCtrl.text = item.nettoInkoop?.toStringAsFixed(2) ?? '';
    _nettoInkoopWaardeCtrl.text = item.nettoInkoopWaarde?.toStringAsFixed(2) ?? '';
    _importKostenCtrl.text = item.importKosten?.toStringAsFixed(2) ?? '';
    _brutoInkoopCtrl.text = item.brutoInkoop?.toStringAsFixed(2) ?? '';
    _verkoopprijsInclCtrl.text = item.verkoopprijsIncl?.toStringAsFixed(2) ?? '';
    _verkoopprijsExclCtrl.text = item.verkoopprijsExcl?.toStringAsFixed(2) ?? '';
    _verkoopWaardeExclCtrl.text = item.verkoopWaardeExcl?.toStringAsFixed(2) ?? '';
    _verkoopWaardeInclCtrl.text = item.verkoopWaardeIncl?.toStringAsFixed(2) ?? '';
    _margeCtrl.text = item.marge?.toStringAsFixed(2) ?? '';
    _gewichtProductCtrl.text = item.gewichtGram?.toString() ?? '';
    _gewichtVerpakkingCtrl.text = item.gewichtVerpakkingGram?.toString() ?? '';
    _vervoerMethode = item.vervoerMethode;
  }

  int get _actueleVoorraad => _item?.voorraadActueel ?? 0;

  int get _totaalGewicht {
    final product = int.tryParse(_gewichtProductCtrl.text) ?? 0;
    final verpakking = int.tryParse(_gewichtVerpakkingCtrl.text) ?? 0;
    return product + verpakking;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final item = InventoryItem(
        id: _item?.id,
        productId: _item?.productId,
        artikelnummer: _artikelnummerCtrl.text.trim().isEmpty ? null : _artikelnummerCtrl.text.trim(),
        eanCode: _eanCodeCtrl.text.trim().isEmpty ? null : _eanCodeCtrl.text.trim(),
        variantLabel: _variantLabelCtrl.text.trim(),
        kleur: _kleurCtrl.text.trim(),
        leverancierCode: _leverancierCodeCtrl.text.trim().isEmpty ? null : _leverancierCodeCtrl.text.trim(),
        opmerking: _opmerkingCtrl.text.trim().isEmpty ? null : _opmerkingCtrl.text.trim(),
        voorraadActueel: _actueleVoorraad,
        voorraadMinimum: int.tryParse(_minimaleVoorraadCtrl.text) ?? 0,
        voorraadBesteld: int.tryParse(_besteldeHoeveelheidCtrl.text) ?? 0,
        inkoopPrijs: double.tryParse(_inkoopPrijsCtrl.text.replaceAll(',', '.')) ?? _item?.inkoopPrijs,
        vliegtuigKosten: double.tryParse(_vliegtuigKostenCtrl.text.replaceAll(',', '.')) ?? _item?.vliegtuigKosten,
        invoertaxAdmin: double.tryParse(_invoertaxAdminCtrl.text.replaceAll(',', '.')) ?? _item?.invoertaxAdmin,
        inkoopTotaal: double.tryParse(_inkoopTotaalCtrl.text.replaceAll(',', '.')) ?? _item?.inkoopTotaal,
        nettoInkoop: double.tryParse(_nettoInkoopCtrl.text.replaceAll(',', '.')) ?? _item?.nettoInkoop,
        nettoInkoopWaarde: double.tryParse(_nettoInkoopWaardeCtrl.text.replaceAll(',', '.')) ?? _item?.nettoInkoopWaarde,
        importKosten: double.tryParse(_importKostenCtrl.text.replaceAll(',', '.')) ?? _item?.importKosten,
        brutoInkoop: double.tryParse(_brutoInkoopCtrl.text.replaceAll(',', '.')) ?? _item?.brutoInkoop,
        verkoopprijsIncl: double.tryParse(_verkoopprijsInclCtrl.text.replaceAll(',', '.')) ?? _item?.verkoopprijsIncl,
        verkoopprijsExcl: double.tryParse(_verkoopprijsExclCtrl.text.replaceAll(',', '.')) ?? _item?.verkoopprijsExcl,
        verkoopWaardeExcl: double.tryParse(_verkoopWaardeExclCtrl.text.replaceAll(',', '.')) ?? _item?.verkoopWaardeExcl,
        verkoopWaardeIncl: double.tryParse(_verkoopWaardeInclCtrl.text.replaceAll(',', '.')) ?? _item?.verkoopWaardeIncl,
        marge: double.tryParse(_margeCtrl.text.replaceAll(',', '.')) ?? _item?.marge,
        vervoerMethode: _vervoerMethode,
        gewichtGram: int.tryParse(_gewichtProductCtrl.text) ?? _item?.gewichtGram,
        gewichtVerpakkingGram: int.tryParse(_gewichtVerpakkingCtrl.text) ?? _item?.gewichtVerpakkingGram,
        isArchived: _item?.isArchived ?? false,
      );
      final saved = await _inventoryService.save(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
        if (saved != null) {
          setState(() {
            _item = saved;
            if (widget.itemId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => InventoryItemScreen(itemId: saved.id),
                  ),
                );
              });
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryItemScreen save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showStockAdjustDialog(bool isPlus) {
    if (_item?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sla eerst het item op voordat je voorraad aanpast.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }

    final qtyCtrl = TextEditingController();
    final redenCtrl = TextEditingController();
    String bron = 'handmatig';
    String mutatieType = isPlus ? 'inkoop' : 'verkoop';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isPlus ? 'Voorraad verhogen' : 'Voorraad verlagen'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Hoeveelheid',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: mutatieType,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: InventoryMutation.mutatieTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => mutatieType = v ?? mutatieType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: redenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reden (verplicht)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: bron,
                  decoration: const InputDecoration(labelText: 'Bron', border: OutlineInputBorder()),
                  items: _bronOpties.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setDialogState(() => bron = v ?? bron),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text);
                final reden = redenCtrl.text.trim();
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voer een geldige hoeveelheid in.'), backgroundColor: Color(0xFFE53935)),
                  );
                  return;
                }
                if (reden.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reden is verplicht.'), backgroundColor: Color(0xFFE53935)),
                  );
                  return;
                }
                final delta = isPlus ? qty : -qty;
                Navigator.pop(ctx);
                try {
                  await _inventoryService.adjustStock(
                    _item!.id!, delta, reden,
                    bron: bron,
                    mutatieType: mutatieType,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voorraad bijgewerkt'), backgroundColor: Color(0xFF2E7D32)),
                    );
                    await _load();
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('adjustStock error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _headerColor, foregroundColor: Colors.white),
              child: const Text('Toepassen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _headerColor,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventarisitem'), backgroundColor: _headerColor, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemId == null ? 'Nieuw inventarisitem' : 'Inventarisitem bewerken'),
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Productinformatie
            _sectionHeader('Productinformatie'),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _artikelnummerCtrl,
                    decoration: const InputDecoration(labelText: 'Artikelnummer', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _eanCodeCtrl,
                    decoration: const InputDecoration(labelText: 'EAN-code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _variantLabelCtrl,
                    decoration: const InputDecoration(labelText: 'Variant label', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _kleurCtrl,
                    decoration: const InputDecoration(labelText: 'Kleur', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _leverancierCodeCtrl,
                    decoration: const InputDecoration(labelText: 'Leverancierscode / VE-code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _opmerkingCtrl,
                    decoration: const InputDecoration(labelText: 'Opmerking', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            // Voorraad
            _sectionHeader('Voorraad'),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Actuele voorraad', style: TextStyle(fontSize: 14)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFE53935)),
                            onPressed: _item?.id != null ? () => _showStockAdjustDialog(false) : null,
                          ),
                          Text(
                            '$_actueleVoorraad',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _headerColor),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
                            onPressed: _item?.id != null ? () => _showStockAdjustDialog(true) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _minimaleVoorraadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Minimale voorraad', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _besteldeHoeveelheidCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Bestelde hoeveelheid', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),

            // Inkoop
            _sectionHeader('Inkoop'),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: TextFormField(controller: _inkoopPrijsCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Inkoop (Wilfer factuur)', border: OutlineInputBorder(), prefixText: '€ '))),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: _vervoerMethode != null && _vervoerOpties.contains(_vervoerMethode) ? _vervoerMethode! : _vervoerOpties.first,
                      decoration: const InputDecoration(labelText: 'Vervoermethode', border: OutlineInputBorder()),
                      items: _vervoerOpties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setState(() => _vervoerMethode = v),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _vliegtuigKostenCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Extra vliegtuigkosten', border: OutlineInputBorder(), prefixText: '€ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _invoertaxAdminCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Invoertax + administratie', border: OutlineInputBorder(), prefixText: '€ '))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _inkoopTotaalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Inkoop totaal', border: OutlineInputBorder(), prefixText: '€ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _importKostenCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Import (10,4%)', border: OutlineInputBorder(), prefixText: '€ '))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _nettoInkoopCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Netto inkoop (excl. consultancy)', border: OutlineInputBorder(), prefixText: '€ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _nettoInkoopWaardeCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Netto inkoop waarde (incl.)', border: OutlineInputBorder(), prefixText: '€ '))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: _brutoInkoopCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bruto inkoop waarde (excl.)', border: OutlineInputBorder(), prefixText: '€ ')),
                ],
              ),
            ),

            // Verkoop
            _sectionHeader('Verkoop'),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: TextFormField(controller: _verkoopprijsInclCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Verkoopprijs (incl. BTW)', border: OutlineInputBorder(), prefixText: '€ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _verkoopprijsExclCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Verkoopprijs (excl. BTW)', border: OutlineInputBorder(), prefixText: '€ '))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _verkoopWaardeExclCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Verkoop waarde (excl.)', border: OutlineInputBorder(), prefixText: '€ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _verkoopWaardeInclCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Verkoop waarde (incl.)', border: OutlineInputBorder(), prefixText: '€ '))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: _margeCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Marge (verkoop / inkoop)', border: OutlineInputBorder(), suffixText: 'x')),
                ],
              ),
            ),

            // Gewicht
            _sectionHeader('Gewicht'),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _gewichtProductCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Gewicht product (gram)', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _gewichtVerpakkingCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Gewicht verpakking (gram)', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text('Totaal gewicht: $_totaalGewicht gram', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // Mutatiegeschiedenis
            if (_item?.id != null) ...[
              _sectionHeader('Mutatiegeschiedenis'),
              _card(
                _mutations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Geen mutaties', style: TextStyle(color: Color(0xFF64748B))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _mutations.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final m = _mutations[i];
                          final dateStr = m.createdAt != null
                              ? '${m.createdAt!.day.toString().padLeft(2, '0')}-${m.createdAt!.month.toString().padLeft(2, '0')}-${m.createdAt!.year}'
                              : '-';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${m.hoeveelheidDelta >= 0 ? '+' : ''}${m.hoeveelheidDelta} • $dateStr',
                              style: TextStyle(
                                color: m.hoeveelheidDelta >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text('${m.reden} • ${m.bron}'),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
