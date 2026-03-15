import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sales_channel_service.dart';
import '../services/user_service.dart';

class AdminSalesChannelsScreen extends StatefulWidget {
  const AdminSalesChannelsScreen({super.key});

  @override
  State<AdminSalesChannelsScreen> createState() => _AdminSalesChannelsScreenState();
}

class _AdminSalesChannelsScreenState extends State<AdminSalesChannelsScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);

  final _service = SalesChannelService();
  final _userService = UserService();
  List<SalesChannel> _channels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.verkoopkanalenBeheren) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    final channels = await _service.getAll();
    if (mounted) setState(() { _channels = channels; _loading = false; });
  }

  void _showEditDialog({SalesChannel? channel}) {
    final naamCtrl = TextEditingController(text: channel?.naam ?? '');
    final codeCtrl = TextEditingController(text: channel?.code ?? '');
    bool actief = channel?.actief ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(channel != null ? 'Kanaal bewerken' : 'Nieuw verkoopkanaal'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: naamCtrl,
                  decoration: const InputDecoration(labelText: 'Naam', border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code (uniek)',
                    border: OutlineInputBorder(),
                    hintText: 'bv. ebay, amazon, website',
                  ),
                  enabled: channel == null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Actief'),
                  value: actief,
                  onChanged: (v) => setDialogState(() => actief = v),
                  activeTrackColor: Colors.green.withValues(alpha: 0.4),
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () async {
                if (naamCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) return;
                try {
                  await _service.save(SalesChannel(
                    id: channel?.id,
                    naam: naamCtrl.text.trim(),
                    code: codeCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
                    actief: actief,
                    sortOrder: channel?.sortOrder ?? _channels.length,
                  ));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(SalesChannel channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Verkoopkanaal verwijderen'),
        content: Text('Weet je zeker dat je "${channel.naam}" wilt verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.delete(channel.id!);
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Verkoopkanalen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showEditDialog(),
            tooltip: 'Nieuw kanaal',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _channels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Geen verkoopkanalen', style: GoogleFonts.dmSans(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Kanaal toevoegen'),
                        style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _channels.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _channels.removeAt(oldIndex);
                    _channels.insert(newIndex, item);
                    setState(() {});
                    for (int i = 0; i < _channels.length; i++) {
                      final ch = _channels[i];
                      if (ch.sortOrder != i) {
                        await _service.save(SalesChannel(
                          id: ch.id,
                          naam: ch.naam,
                          code: ch.code,
                          actief: ch.actief,
                          sortOrder: i,
                        ));
                      }
                    }
                    _load();
                  },
                  itemBuilder: (ctx, i) {
                    final ch = _channels[i];
                    return Card(
                      key: ValueKey(ch.id),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: ch.actief ? const Color(0xFFE8ECF1) : const Color(0xFFE0E0E0)),
                      ),
                      color: ch.actief ? Colors.white : const Color(0xFFF5F5F5),
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: ch.actief ? _accent.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _channelIcon(ch.code),
                            size: 20,
                            color: ch.actief ? _accent : Colors.grey,
                          ),
                        ),
                        title: Text(ch.naam, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: ch.actief ? _navy : Colors.grey)),
                        subtitle: Text('Code: ${ch.code}', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: ch.actief,
                              onChanged: (v) async {
                                await _service.toggleActive(ch.id!, v);
                                _load();
                              },
                              activeTrackColor: Colors.green.withValues(alpha: 0.4),
                              activeThumbColor: Colors.green,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showEditDialog(channel: ch),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE53935)),
                              onPressed: () => _confirmDelete(ch),
                            ),
                            const Icon(Icons.drag_handle, size: 20, color: Color(0xFFBDBDBD)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _channelIcon(String code) {
    switch (code) {
      case 'website': return Icons.language_rounded;
      case 'ebay': return Icons.gavel_rounded;
      case 'amazon': return Icons.shopping_cart_rounded;
      case 'bol_com': return Icons.store_rounded;
      case 'marktplaats': return Icons.sell_rounded;
      case 'handmatig': return Icons.edit_rounded;
      case 'overig': return Icons.more_horiz_rounded;
      default: return Icons.storefront_rounded;
    }
  }
}
