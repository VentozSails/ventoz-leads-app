import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:file_selector_windows/file_selector_windows.dart';
import '../services/impressions_service.dart';
import '../services/user_service.dart';

class AdminImpressionsScreen extends StatefulWidget {
  const AdminImpressionsScreen({super.key});

  @override
  State<AdminImpressionsScreen> createState() => _AdminImpressionsScreenState();
}

class _AdminImpressionsScreenState extends State<AdminImpressionsScreen> {
  static const _navy = Color(0xFF1B2A4A);

  final _service = ImpressionsService();
  final _userService = UserService();
  List<Impression> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.impressiesBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final items = await _service.getImpressions(forceRefresh: true);
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _pickLocalFiles() async {
    final plugin = FileSelectorWindows();
    final files = await plugin.openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Afbeeldingen',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
        ),
      ],
    );
    if (files.isEmpty) return;

    setState(() => _loading = true);
    var uploaded = 0;
    for (final xFile in files) {
      try {
        final file = File(xFile.path);
        final url = await _service.uploadImage(file);
        await _service.addImpression(imageUrl: url);
        uploaded++;
      } catch (e) {
        if (kDebugMode) debugPrint('Error uploading ${xFile.name}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaden mislukt: ${xFile.name}'), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
    if (mounted && uploaded > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$uploaded foto${uploaded == 1 ? '' : "'s"} geüpload'), backgroundColor: Colors.green.shade700),
      );
    }
    await _load();
  }

  Future<void> _showAddDialog() async {
    final urlCtrl = TextEditingController();
    final captionCtrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Foto toevoegen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () => Navigator.pop(ctx, 'FILE'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2, strokeAlign: BorderSide.strokeAlignInside),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF8FAFB),
                ),
                child: Column(children: [
                  Icon(Icons.upload_file, size: 36, color: _navy.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  Text('Bestand kiezen van computer', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                  const SizedBox(height: 4),
                  Text('JPG, PNG, GIF, WebP, BMP', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('of', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8))),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'Afbeelding URL',
                hintText: 'https://...',
                isDense: true,
                prefixIcon: Icon(Icons.link, size: 18, color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionCtrl,
              decoration: InputDecoration(
                labelText: 'Bijschrift (optioneel)',
                isDense: true,
                prefixIcon: Icon(Icons.text_fields, size: 18, color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: GoogleFonts.dmSans(fontSize: 13),
              maxLines: 2,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'URL'),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Toevoegen via URL'),
          ),
        ],
      ),
    );

    if (result == 'FILE') {
      await _pickLocalFiles();
    } else if (result == 'URL' && urlCtrl.text.trim().isNotEmpty) {
      final imgUrl = urlCtrl.text.trim();
      if (!imgUrl.startsWith('https://')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alleen https:// URLs zijn toegestaan.'), backgroundColor: Color(0xFFE53935)),
          );
        }
        return;
      }
      setState(() => _loading = true);
      await _service.addImpression(
        imageUrl: imgUrl,
        caption: captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim(),
      );
      await _load();
    }
  }

  Future<void> _editCaption(Impression item) async {
    final ctrl = TextEditingController(text: item.caption ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bijschrift bewerken', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Bijschrift', isDense: true),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );

    if (result == true && item.id != null) {
      await _service.updateCaption(item.id!, ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
      await _load();
    }
  }

  Future<void> _delete(Impression item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foto verwijderen?'),
        content: const Text('Deze foto wordt permanent verwijderd uit de gallerij.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      await _service.deleteImpression(item.id!);
      await _load();
    }
  }

  Future<void> _moveUp(int index) async {
    if (index <= 0) return;
    final ids = _items.map((i) => i.id!).toList();
    final temp = ids[index];
    ids[index] = ids[index - 1];
    ids[index - 1] = temp;
    await _service.reorder(ids);
    await _load();
  }

  Future<void> _moveDown(int index) async {
    if (index >= _items.length - 1) return;
    final ids = _items.map((i) => i.id!).toList();
    final temp = ids[index];
    ids[index] = ids[index + 1];
    ids[index + 1] = temp;
    await _service.reorder(ids);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text('Impressies beheren', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add_photo_alternate), onPressed: _showAddDialog, tooltip: 'Foto toevoegen'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Nog geen impressies', style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 18),
                      label: const Text('Eerste foto toevoegen'),
                      style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                      onPressed: _showAddDialog,
                    ),
                  ]),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 4 : 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildAdminTile(_items[index], index),
                  ),
                ),
      floatingActionButton: _items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate, size: 20),
              label: Text('Foto toevoegen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildAdminTile(Impression item, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFFE2E8F0),
              child: const Center(child: Icon(Icons.broken_image, size: 36, color: Color(0xFF94A3B8))),
            ),
          ),
        ),
        Positioned(
          top: 4, right: 4,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _miniButton(Icons.arrow_upward, index > 0 ? () => _moveUp(index) : null),
            _miniButton(Icons.arrow_downward, index < _items.length - 1 ? () => _moveDown(index) : null),
            _miniButton(Icons.edit, () => _editCaption(item)),
            _miniButton(Icons.delete, () => _delete(item), color: Colors.red.shade700),
          ]),
        ),
        if (item.caption != null && item.caption!.isNotEmpty)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.black54,
              child: Text(item.caption!, style: const TextStyle(fontSize: 11, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
      ]),
    );
  }

  Widget _miniButton(IconData icon, VoidCallback? onTap, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: onTap != null ? 0.6 : 0.25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: onTap != null ? color : Colors.white38),
        ),
      ),
    );
  }
}
