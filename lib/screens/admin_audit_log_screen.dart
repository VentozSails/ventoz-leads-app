import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/audit_service.dart';
import '../services/user_service.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  static const _navy = Color(0xFF1B2A4A);

  final _service = AuditService();
  final _userService = UserService();
  List<AuditEntry> _entries = [];
  bool _loading = true;
  String? _filterAction;

  static const _actionFilters = <String, String>{
    'login_failed': 'Inloggen mislukt',
    'login_success': 'Inloggen geslaagd',
    'account_locked': 'Account geblokkeerd',
    'account_unlocked': 'Account vrijgegeven',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.activiteitenlogBekijken) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final entries = await _service.getRecentLogs(limit: 200);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  List<AuditEntry> get _filtered {
    if (_filterAction == null) return _entries;
    return _entries.where((e) => e.action == _filterAction).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd-MM-yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text('Activiteitenlog', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => _loading = true); _load(); }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _filterChip(null, 'Alles'),
                    ..._actionFilters.entries.map((e) => _filterChip(e.key, e.value)),
                  ]),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('Geen logboekregels gevonden', style: GoogleFonts.dmSans(color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final entry = _filtered[index];
                          return _buildLogRow(entry, fmt);
                        },
                      ),
              ),
            ]),
    );
  }

  Widget _filterChip(String? action, String label) {
    final isActive = _filterAction == action;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: isActive ? Colors.white : _navy)),
        selected: isActive,
        onSelected: (_) => setState(() => _filterAction = action),
        backgroundColor: Colors.white,
        selectedColor: _navy,
        side: BorderSide(color: isActive ? _navy : const Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildLogRow(AuditEntry entry, DateFormat fmt) {
    final (icon, color) = _iconForAction(entry.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(entry.actionLabel, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
              const Spacer(),
              Text(fmt.format(entry.createdAt.toLocal()), style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
            ]),
            const SizedBox(height: 2),
            Text(
              '${entry.actorEmail}${entry.targetEmail != null && entry.targetEmail != entry.actorEmail ? ' → ${entry.targetEmail}' : ''}',
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (entry.details != null && entry.details!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(entry.details!, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
      ]),
    );
  }

  (IconData, Color) _iconForAction(String action) => switch (action) {
        'login_success' => (Icons.login, const Color(0xFF2E7D32)),
        'login_failed' => (Icons.error_outline, const Color(0xFFE65100)),
        'account_locked' => (Icons.lock, const Color(0xFFC62828)),
        'account_unlocked' => (Icons.lock_open, const Color(0xFF2E7D32)),
        'user_invited' => (Icons.person_add, const Color(0xFF1565C0)),
        'user_registered' => (Icons.how_to_reg, const Color(0xFF00838F)),
        'order_placed' => (Icons.shopping_bag, const Color(0xFF5C6BC0)),
        'order_shipped' => (Icons.local_shipping, const Color(0xFF00695C)),
        _ => (Icons.info_outline, const Color(0xFF64748B)),
      };
}
