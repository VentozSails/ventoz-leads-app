import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/email_log.dart';
import '../services/email_log_service.dart';
import '../services/export_service.dart';
import '../services/smtp_service.dart';
import '../services/user_service.dart';
import 'package:intl/intl.dart';

class EmailOverviewScreen extends StatefulWidget {
  const EmailOverviewScreen({super.key});

  @override
  State<EmailOverviewScreen> createState() => _EmailOverviewScreenState();
}

class _EmailOverviewScreenState extends State<EmailOverviewScreen> {
  final EmailLogService _service = EmailLogService();
  final SmtpService _smtpService = SmtpService();

  List<EmailLog> _emails = [];
  List<EmailLog> _filteredEmails = [];
  bool _loading = true;
  EmailStatus? _statusFilter;
  SmtpSettings? _smtpSettings;
  Map<String, int> _statusCounts = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _canExport = false;

  @override
  void initState() {
    super.initState();
    _autoArchive();
    _load();
    _checkExportPermission();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _checkExportPermission() async {
    final perms = await UserService().getCurrentUserPermissions();
    if (mounted) setState(() => _canExport = perms.exporteren);
  }

  Future<void> _autoArchive() async {
    final count = await _service.archiveOldEmails();
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count oude e-mails automatisch gearchiveerd'), backgroundColor: const Color(0xFF78909C)),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _applySearch();
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredEmails = _emails;
    } else {
      _filteredEmails = _emails.where((e) {
        return e.leadNaam.toLowerCase().contains(_searchQuery) ||
            (e.onderwerp?.toLowerCase().contains(_searchQuery) ?? false) ||
            e.verzondenAan.toLowerCase().contains(_searchQuery) ||
            (e.kortingscode?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await UserService().getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.leadEmailsVersturen) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    final results = await Future.wait([
      _service.fetchAll(status: _statusFilter),
      _service.countByStatus(),
      _smtpService.loadSettings(),
    ]);
    if (mounted) {
      setState(() {
        _emails = results[0] as List<EmailLog>;
        _statusCounts = results[1] as Map<String, int>;
        _smtpSettings = results[2] as SmtpSettings?;
        _applySearch();
        _loading = false;
      });
    }
  }

  void _setFilter(EmailStatus? status) {
    _statusFilter = status;
    _load();
  }

  Future<void> _exportCsv() async {
    if (_filteredEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen e-mails om te exporteren')),
      );
      return;
    }
    final csv = ExportService.emailLogsToCsv(_filteredEmails);
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final path = await ExportService.downloadCsv(csv, 'ventoz_emails_$now.csv');
    if (path == null || !mounted) return;
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 48),
          title: const Text('Export geslaagd'),
          content: SelectableText(path),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten'))],
        ),
      );
    }
  }

  Color _statusColor(EmailStatus s) {
    return switch (s) {
      EmailStatus.concept => const Color(0xFF1E88E5),
      EmailStatus.gepland => const Color(0xFFF59E0B),
      EmailStatus.verzonden => const Color(0xFF43A047),
      EmailStatus.mislukt => const Color(0xFFE53935),
      EmailStatus.gearchiveerd => const Color(0xFF78909C),
      EmailStatus.conversie => const Color(0xFF8E24AA),
    };
  }

  IconData _statusIcon(EmailStatus s) {
    return switch (s) {
      EmailStatus.concept => Icons.edit_note,
      EmailStatus.gepland => Icons.schedule,
      EmailStatus.verzonden => Icons.check_circle,
      EmailStatus.mislukt => Icons.error_outline,
      EmailStatus.gearchiveerd => Icons.archive,
      EmailStatus.conversie => Icons.trending_up,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-mails'),
        actions: [
          if (_canExport)
            IconButton(icon: const Icon(Icons.download), tooltip: 'Exporteer CSV', onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Vernieuwen', onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilterBar(),
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEmails.isEmpty
                    ? _buildEmptyState()
                    : _buildEmailList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterBar() {
    final total = _statusCounts.values.fold(0, (a, b) => a + b);

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(null, 'Alle', total),
            const SizedBox(width: 6),
            ...EmailStatus.values.map((s) =>
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _filterChip(s, s.label, _statusCounts[s.name] ?? 0),
                )),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(EmailStatus? status, String label, int count) {
    final isActive = _statusFilter == status;
    final color = status != null ? _statusColor(status) : const Color(0xFF455A64);

    return FilterChip(
      selected: isActive,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withAlpha(60) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? Colors.white : const Color(0xFF64748B))),
            ),
          ],
        ],
      ),
      onSelected: (_) => _setFilter(status),
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: isActive ? Colors.white : const Color(0xFF475569)),
      backgroundColor: Colors.white,
      side: BorderSide(color: isActive ? color : const Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Zoek op naam, onderwerp, e-mail of kortingscode...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF455A64), width: 2)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasSearch ? Icons.search_off : (_statusFilter != null ? _statusIcon(_statusFilter!) : Icons.inbox),
              size: 48, color: const Color(0xFFCFD8DC)),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'Geen resultaten voor "$_searchQuery"'
                : _statusFilter != null
                    ? 'Geen e-mails met status "${_statusFilter!.label}"'
                    : 'Nog geen e-mails',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 16),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: () => _searchController.clear(), child: const Text('Zoekopdracht wissen')),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredEmails.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildEmailCard(_filteredEmails[i]),
    );
  }

  Widget _buildEmailCard(EmailLog email) {
    final dateStr = email.verzondenOp != null
        ? DateFormat('dd-MM-yyyy HH:mm').format(email.verzondenOp!)
        : '—';
    final color = _statusColor(email.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(email),
        child: Column(
          children: [
            Container(
              height: 4,
              color: color,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_statusIcon(email.status), size: 18, color: color),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withAlpha(60)),
                        ),
                        child: Text(email.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          email.leadNaam,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 4),
                      _buildQuickCopy(email),
                    ],
                  ),
                  if (email.onderwerp != null && email.onderwerp!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      email.onderwerp!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 12, color: Colors.blueGrey[300]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          email.verzondenAan.isNotEmpty ? email.verzondenAan : '—',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey[400]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (email.kortingscode != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.local_offer, size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 3),
                        Text(email.kortingscode!, style: TextStyle(fontSize: 11, color: Colors.amber[700], fontWeight: FontWeight.w600)),
                      ],
                      if (email.verzondenVia.isNotEmpty && email.status != EmailStatus.conversie) ...[
                        const SizedBox(width: 8),
                        Text('via ${email.verzondenVia}', style: TextStyle(fontSize: 10, color: Colors.blueGrey[300])),
                      ],
                    ],
                  ),
                  if (email.foutmelding != null && email.foutmelding!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, size: 14, color: Colors.red[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(email.foutmelding!, style: TextStyle(fontSize: 11, color: Colors.red[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCopy(EmailLog email) {
    final hasContent = (email.inhoud ?? '').isNotEmpty || (email.onderwerp ?? '').isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.copy, size: 15, color: Colors.blueGrey[300]),
        tooltip: 'Kopieer inhoud',
        onPressed: () {
          final text = [
            if (email.onderwerp != null && email.onderwerp!.isNotEmpty) 'Onderwerp: ${email.onderwerp}',
            '',
            email.inhoud ?? '',
          ].join('\n');
          Clipboard.setData(ClipboardData(text: text.trim()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('E-mail inhoud gekopieerd'), duration: Duration(seconds: 2)),
          );
        },
      ),
    );
  }

  void _openDetail(EmailLog email) {
    showDialog(
      context: context,
      builder: (ctx) => _EmailDetailDialog(
        email: email,
        smtpSettings: _smtpSettings,
        smtpService: _smtpService,
        emailLogService: _service,
        statusColor: _statusColor,
        statusIcon: _statusIcon,
        onChanged: _load,
      ),
    );
  }
}

class _EmailDetailDialog extends StatefulWidget {
  final EmailLog email;
  final SmtpSettings? smtpSettings;
  final SmtpService smtpService;
  final EmailLogService emailLogService;
  final Color Function(EmailStatus) statusColor;
  final IconData Function(EmailStatus) statusIcon;
  final VoidCallback onChanged;

  const _EmailDetailDialog({
    required this.email,
    required this.smtpSettings,
    required this.smtpService,
    required this.emailLogService,
    required this.statusColor,
    required this.statusIcon,
    required this.onChanged,
  });

  @override
  State<_EmailDetailDialog> createState() => _EmailDetailDialogState();
}

class _EmailDetailDialogState extends State<_EmailDetailDialog> {
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  late TextEditingController _toController;
  bool _sending = false;
  bool _edited = false;

  bool get _isEditable => widget.email.status.isEditable;
  bool get _canResend => widget.email.status.canResend;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.email.onderwerp ?? '');
    _bodyController = TextEditingController(text: widget.email.inhoud ?? '');
    _toController = TextEditingController(text: widget.email.verzondenAan);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (widget.email.id == null) return;
    await widget.emailLogService.updateDraft(
      widget.email.id!,
      onderwerp: _subjectController.text,
      inhoud: _bodyController.text,
      verzondenAan: _toController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concept bijgewerkt'), backgroundColor: Color(0xFF43A047)),
      );
      widget.onChanged();
      setState(() => _edited = false);
    }
  }

  Future<void> _sendEmail() async {
    final settings = widget.smtpSettings;
    if (settings == null || !settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMTP niet geconfigureerd')),
      );
      return;
    }

    final to = _toController.text.trim();
    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen ontvanger opgegeven')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.smtpService.sendEmail(
        settings: settings,
        toAddress: to,
        subject: _subjectController.text,
        body: _bodyController.text,
      );
      if (widget.email.id != null) {
        await widget.emailLogService.markSent(widget.email.id!);
        await widget.emailLogService.updateDraft(
          widget.email.id!,
          onderwerp: _subjectController.text,
          inhoud: _bodyController.text,
          verzondenAan: to,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verzonden naar $to'), backgroundColor: const Color(0xFF43A047)),
        );
        widget.onChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (widget.email.id != null) {
        await widget.emailLogService.markFailed(widget.email.id!, msg);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444), duration: const Duration(seconds: 6)),
        );
        widget.onChanged();
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _archive() async {
    if (widget.email.id == null) return;
    await widget.emailLogService.markArchived(widget.email.id!);
    if (mounted) {
      widget.onChanged();
      Navigator.pop(context);
    }
  }

  Future<void> _deleteEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-mail verwijderen'),
        content: const Text('Weet je zeker dat je deze e-mail wilt verwijderen?\nDeze actie kan niet ongedaan worden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.email.id == null) return;
    await widget.emailLogService.delete(widget.email.id!);
    if (mounted) {
      widget.onChanged();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    final color = widget.statusColor(email.status);
    final screenWidth = MediaQuery.of(context).size.width;
    final dateStr = email.verzondenOp != null
        ? DateFormat('dd-MM-yyyy HH:mm').format(email.verzondenOp!)
        : '—';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screenWidth > 700 ? 660 : screenWidth * 0.95,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: const Color(0xFF37474F),
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              child: Row(
                children: [
                  Icon(widget.statusIcon(email.status), color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email.leadNaam, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        Row(children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color.withAlpha(60), borderRadius: BorderRadius.circular(4)),
                            child: Text(email.status.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5))),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  _fieldRow('Aan', _isEditable
                      ? TextField(controller: _toController, onChanged: (_) => setState(() => _edited = true),
                          style: const TextStyle(fontSize: 13), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)))
                      : Text(email.verzondenAan, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
                  const SizedBox(height: 8),
                  _fieldRow('Onderwerp', _isEditable
                      ? TextField(controller: _subjectController, onChanged: (_) => setState(() => _edited = true),
                          style: const TextStyle(fontSize: 13), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)))
                      : SelectableText(email.onderwerp ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
                  if (email.templateNaam != null) ...[
                    const SizedBox(height: 6),
                    _fieldRow('Template', Text(email.templateNaam!, style: TextStyle(fontSize: 12, color: Colors.blueGrey[500]))),
                  ],
                  if (email.producten != null) ...[
                    const SizedBox(height: 6),
                    _fieldRow('Producten', Text(email.producten!, style: TextStyle(fontSize: 12, color: Colors.blueGrey[500]))),
                  ],
                  if (email.kortingscode != null) ...[
                    const SizedBox(height: 6),
                    _fieldRow('Code', Row(children: [
                      Icon(Icons.local_offer, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(email.kortingscode!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.amber[800])),
                    ])),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            if (email.foutmelding != null && email.foutmelding!.isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.red[50],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(email.foutmelding!, style: TextStyle(fontSize: 12, color: Colors.red[700]))),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: _isEditable
                      ? TextField(
                          controller: _bodyController,
                          maxLines: null,
                          minLines: 12,
                          onChanged: (_) => setState(() => _edited = true),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        )
                      : SelectableText(
                          email.inhoud ?? 'Geen inhoud beschikbaar',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.7),
                        ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
              child: Row(
                children: [
                  if (email.status != EmailStatus.conversie)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
                      tooltip: 'Verwijderen',
                      onPressed: _deleteEmail,
                    ),
                  if (email.status != EmailStatus.gearchiveerd && email.status != EmailStatus.conversie)
                    IconButton(
                      icon: Icon(Icons.archive_outlined, size: 20, color: Colors.blueGrey[400]),
                      tooltip: 'Archiveren',
                      onPressed: _archive,
                    ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 20, color: Colors.blueGrey[400]),
                    tooltip: 'Kopieer inhoud',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${_subjectController.text}\n\n${_bodyController.text}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gekopieerd'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                  const Spacer(),
                  if (_isEditable && _edited)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Opslaan'),
                      onPressed: _saveDraft,
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1E88E5), side: const BorderSide(color: Color(0xFF1E88E5))),
                    ),
                  if (_canResend) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: _sending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 16),
                      label: Text(email.status == EmailStatus.mislukt ? 'Opnieuw versturen' : 'Versturen'),
                      onPressed: _sending ? null : _sendEmail,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ),
        Expanded(child: value),
      ],
    );
  }
}
