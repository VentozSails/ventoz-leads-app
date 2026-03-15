import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/smtp_service.dart';
import '../services/user_service.dart';
import '../services/vat_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _service = UserService();

  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;
  bool _isOwner = false;
  bool _canManageUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final owner = await _service.isCurrentUserOwner();
    final perms = await _service.getCurrentUserPermissions();
    if (mounted) {
      setState(() {
        _isOwner = owner;
        _canManageUsers = perms.gebruikersBeheren;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    final perms = await _service.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.gebruikersBeheren) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    try {
      _users = await _service.fetchUsers();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading users: $e');
      _error = 'Er is een fout opgetreden bij het laden.';
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── App URL detection ───

  String _getAppUrl() {
    if (kIsWeb) {
      final base = Uri.base;
      return '${base.scheme}://${base.host}${base.hasPort && base.port != 443 && base.port != 80 ? ':${base.port}' : ''}/';
    }
    return 'https://app.ventoz.com/';
  }

  // ─── Invite dialog ───

  Future<void> _inviteUser() async {
    final result = await showDialog<AppUser>(
      context: context,
      builder: (ctx) => _InviteDialog(isOwner: _isOwner),
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      await _service.inviteUser(
        email: result.email,
        permissions: result.permissions,
        userType: result.userType,
        landCode: result.landCode,
        isParticulier: result.isParticulier,
      );

      // Send invitation email via SMTP
      bool mailSent = false;
      try {
        await SmtpService().sendInviteEmail(
          toEmail: result.email,
          userTypeLabel: result.userType.label,
          mfaRequired: result.userType.mfaRequired,
          appUrl: _getAppUrl(),
        );
        mailSent = true;
      } catch (e) {
        if (kDebugMode) debugPrint('Error sending invite email: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mailSent
                ? '${result.email} is uitgenodigd — e-mail verstuurd'
                : '${result.email} is uitgenodigd, maar de e-mail kon niet worden verstuurd. Deel de registratielink handmatig.'),
            backgroundColor: mailSent ? const Color(0xFF43A047) : const Color(0xFFF59E0B),
            duration: Duration(seconds: mailSent ? 4 : 6),
          ),
        );
      }
      await _loadUsers();
    } catch (e) {
      if (kDebugMode) debugPrint('Error inviting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uitnodigen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)),
        );
        setState(() => _loading = false);
      }
    }
  }

  // ─── Edit user detail dialog ───

  Future<void> _editUser(AppUser user) async {
    final result = await showDialog<AppUser>(
      context: context,
      builder: (ctx) => _EditUserDialog(user: user, isOwner: _isOwner),
    );
    if (result == null) return;

    try {
      await _service.updateUser(result);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gebruiker bijgewerkt'), backgroundColor: Color(0xFF43A047)),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bijwerken mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _toggleAdmin(AppUser user) async {
    try {
      await _service.toggleAdmin(user.email);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isAdmin ? '${user.email} is geen beheerder meer' : '${user.email} is nu beheerder'),
            backgroundColor: const Color(0xFF43A047),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error toggling admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Actie mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _removeUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gebruiker verwijderen'),
        content: Text('Weet je zeker dat je ${user.email} wilt verwijderen?\n\nDeze persoon kan dan niet meer inloggen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeUser(user.email);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.email} is verwijderd'), backgroundColor: const Color(0xFF43A047)),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error removing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gebruikersbeheer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Vernieuwen', onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: _isOwner ? FloatingActionButton.extended(
        onPressed: _inviteUser,
        backgroundColor: const Color(0xFF455A64),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Uitnodigen'),
      ) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
              : _users.isEmpty
                  ? _buildEmptyState()
                  : _buildUserList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.blueGrey[300]),
          const SizedBox(height: 16),
          const Text('Nog geen gebruikers', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          const Text('Nodig iemand uit met de knop rechtsonder', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final currentEmail = _service.currentUserEmail?.toLowerCase();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final user = _users[i];
        final isSelf = user.email.toLowerCase() == currentEmail;

        return Card(
          elevation: user.isOwner ? 2 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: user.isOwner
                ? const BorderSide(color: Color(0xFFE65100), width: 1.5)
                : isSelf
                    ? const BorderSide(color: Color(0xFF455A64), width: 1.5)
                    : BorderSide(color: Colors.blueGrey[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildAvatar(user),
                const SizedBox(width: 14),
                Expanded(child: _buildUserInfo(user, isSelf)),
                _buildActions(user, isSelf),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(AppUser user) {
    final isPending = user.status == InviteStatus.uitgenodigd;
    IconData icon;
    Color bg;
    Color fg;

    if (user.isOwner) {
      icon = Icons.star; bg = const Color(0xFFE65100); fg = Colors.white;
    } else if (user.userType == UserType.wederverkoper) {
      icon = Icons.storefront; bg = const Color(0xFF1565C0); fg = Colors.white;
    } else if (user.userType == UserType.klant) {
      icon = Icons.person; bg = const Color(0xFF2E7D32); fg = Colors.white;
    } else if (user.userType == UserType.prospect) {
      icon = Icons.mail_outline; bg = const Color(0xFFF59E0B); fg = Colors.white;
    } else if (user.isAdmin || user.userType == UserType.admin) {
      icon = Icons.admin_panel_settings; bg = const Color(0xFF455A64); fg = Colors.white;
    } else if (isPending) {
      icon = Icons.hourglass_top; bg = Colors.orange[100]!; fg = Colors.orange[700]!;
    } else {
      icon = Icons.person; bg = Colors.blueGrey[100]!; fg = Colors.blueGrey[600]!;
    }

    return CircleAvatar(radius: 22, backgroundColor: bg, child: Icon(icon, color: fg, size: 22));
  }

  Widget _buildUserInfo(AppUser user, bool isSelf) {
    final isPending = user.status == InviteStatus.uitgenodigd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Flexible(
            child: Text(user.email,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis),
          ),
          if (user.isOwner) ...[const SizedBox(width: 6), _buildBadge('Eigenaar', const Color(0xFFE65100))],
          if (isSelf && !user.isOwner) ...[const SizedBox(width: 6), _buildBadge('Jij', const Color(0xFF455A64))],
          if (isPending) ...[const SizedBox(width: 6), _buildBadge('Wacht op registratie', Colors.orange[700]!)],
        ]),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildTypeBadge(user),
            if (user.isBedrijf) ...[
              _buildBadge('Bedrijf', const Color(0xFF1565C0)),
              if (user.btwNummer != null && user.btwNummer!.isNotEmpty) ...[
                _buildBadge(
                  user.btwGevalideerd ? 'BTW \u2713' : 'BTW \u2717',
                  user.btwGevalideerd ? const Color(0xFF2E7D32) : const Color(0xFFEF4444),
                ),
              ],
            ],
            if (user.effectiveKorting > 0)
              _buildBadge('${user.effectiveKorting.toStringAsFixed(0)}% korting', const Color(0xFF7B1FA2)),
            _buildBadge(user.landCode, Colors.blueGrey[600]!),
          ],
        ),
        const SizedBox(height: 4),
        Row(children: [
          ..._buildPermissionChips(user.permissions),
        ]),
      ],
    );
  }

  Widget _buildTypeBadge(AppUser user) {
    Color color;
    String label;
    switch (user.userType) {
      case UserType.owner:
        color = const Color(0xFFE65100); label = 'Eigenaar';
      case UserType.admin:
        color = const Color(0xFF455A64); label = 'Beheerder';
      case UserType.wederverkoper:
        color = const Color(0xFF1565C0); label = 'Wederverkoper';
      case UserType.prospect:
        color = const Color(0xFFF59E0B); label = 'Prospect';
      case UserType.klant:
        color = const Color(0xFF2E7D32); label = 'Klant';
      case UserType.user:
        color = Colors.blueGrey[500]!; label = 'Gebruiker';
    }
    return _buildBadge(label, color);
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  List<Widget> _buildPermissionChips(UserPermissions p) {
    final chips = <Widget>[];
    void addChip(String label, bool active, IconData icon) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Tooltip(
          message: label,
          child: Icon(icon, size: 14, color: active ? const Color(0xFF455A64) : Colors.blueGrey[200]),
        ),
      ));
    }
    addChip('Inzien', p.inzien, Icons.visibility);
    addChip('Wijzigen', p.wijzigen, Icons.edit);
    addChip('E-mails', p.emailsVersturen, Icons.send);
    addChip('Verwijderen', p.verwijderen, Icons.delete_outline);
    addChip('Exporteren', p.exporteren, Icons.download);
    addChip('Gebruikers', p.gebruikersBeheren, Icons.people);
    return chips;
  }

  Widget _buildActions(AppUser user, bool isSelf) {
    if (isSelf || user.isOwner) {
      if (user.isOwner && !isSelf) {
        return Tooltip(
          message: 'Eigenaar kan niet worden gewijzigd',
          child: Icon(Icons.lock, size: 18, color: Colors.blueGrey[300]),
        );
      }
      return const SizedBox.shrink();
    }

    if (!_isOwner && !_canManageUsers) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.blueGrey[400]),
      itemBuilder: (_) => [
        if (_isOwner)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Bewerken', style: TextStyle(fontSize: 13)), dense: true, contentPadding: EdgeInsets.zero),
          ),
        if (_isOwner)
          PopupMenuItem(
            value: 'toggle_admin',
            child: ListTile(
              leading: Icon(user.isAdmin ? Icons.person : Icons.admin_panel_settings, size: 20),
              title: Text(user.isAdmin ? 'Admin intrekken' : 'Admin maken', style: const TextStyle(fontSize: 13)),
              dense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_isOwner)
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(leading: Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)), title: Text('Verwijderen', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))), dense: true, contentPadding: EdgeInsets.zero),
          ),
      ],
      onSelected: (val) {
        switch (val) {
          case 'edit': _editUser(user);
          case 'toggle_admin': _toggleAdmin(user);
          case 'remove': _removeUser(user);
        }
      },
    );
  }
}

// ─── Invite Dialog ───

class _InviteDialog extends StatefulWidget {
  final bool isOwner;
  const _InviteDialog({required this.isOwner});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  UserType _userType = UserType.klant;
  bool _isParticulier = true;
  String _landCode = 'NL';
  var _perms = UserPermissions.klantPreset;
  double _kortingPermanent = 0;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gebruiker uitnodigen'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-mailadres', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vul een e-mailadres in';
                    if (!VatService.isValidEmail(v.trim())) return 'Ongeldig e-mailadres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserType>(
                  initialValue: _userType,
                  decoration: const InputDecoration(labelText: 'Type gebruiker', prefixIcon: Icon(Icons.badge_outlined)),
                  items: [UserType.klant, UserType.wederverkoper, UserType.prospect, UserType.admin]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _userType = v;
                      _perms = UserPermissions.defaultForRole(v);
                      if (v.isBedrijf) _isParticulier = false;
                      if (v == UserType.klant || v == UserType.user || v == UserType.prospect) _isParticulier = true;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _landCode,
                      decoration: const InputDecoration(labelText: 'Land', prefixIcon: Icon(Icons.public)),
                      items: _countryItems(),
                      onChanged: (v) { if (v != null) setState(() => _landCode = v); },
                    ),
                  ),
                  if (!_userType.isBedrijf && _userType != UserType.klant && _userType != UserType.user && _userType != UserType.prospect) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        title: Text(_isParticulier ? 'Particulier' : 'Bedrijf', style: const TextStyle(fontSize: 13)),
                        value: !_isParticulier,
                        onChanged: (v) => setState(() => _isParticulier = !v),
                        activeTrackColor: const Color(0xFF455A64),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ]),
                if (_userType == UserType.wederverkoper) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.percent, size: 16, color: Color(0xFF7B1FA2)),
                          const SizedBox(width: 8),
                          Text('Permanente korting: ${_kortingPermanent.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7B1FA2))),
                        ]),
                        const SizedBox(height: 8),
                        Slider(
                          value: _kortingPermanent,
                          min: 0, max: 50, divisions: 10,
                          label: '${_kortingPermanent.toStringAsFixed(0)}%',
                          activeColor: const Color(0xFF7B1FA2),
                          onChanged: (v) => setState(() => _kortingPermanent = v),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.security, size: 16, color: Colors.blueGrey[600]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Rechten worden automatisch toegewezen op basis van de gekozen rol. '
                      'De eigenaar kan deze aanpassen via Rolrechten in het dashboard.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Deze persoon kan een account aanmaken op het loginscherm met dit e-mailadres.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, AppUser(
                email: _emailCtrl.text.trim(),
                userType: _userType,
                permissions: _perms,
                landCode: _landCode,
                isParticulier: _isParticulier,
                kortingPermanent: _userType == UserType.wederverkoper ? _kortingPermanent : 0,
              ));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
          child: const Text('Uitnodigen'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _countryItems() {
    return VatService.sortedCountryEntries
        .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} – ${e.value}')))
        .toList();
  }
}

// ─── Edit User Dialog ───

class _EditUserDialog extends StatefulWidget {
  final AppUser user;
  final bool isOwner;
  const _EditUserDialog({required this.user, required this.isOwner});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late UserType _userType;
  late bool _isParticulier;
  late String _landCode;
  late TextEditingController _voornaamCtrl;
  late TextEditingController _achternaamCtrl;
  late TextEditingController _adresCtrl;
  late TextEditingController _postcodeCtrl;
  late TextEditingController _woonplaatsCtrl;
  late TextEditingController _telefoonCtrl;
  late TextEditingController _btwCtrl;
  late TextEditingController _bedrijfCtrl;
  late TextEditingController _ibanCtrl;
  late TextEditingController _kortingPermCtrl;
  late TextEditingController _kortingTijdCtrl;
  DateTime? _kortingGeldigTot;
  bool _btwGevalideerd = false;
  bool _validating = false;
  String? _vatError;
  String? _vatName;
  String? _ibanError;

  bool get _isEuCountry => VatService.isEuCountry(_landCode);

  @override
  void initState() {
    super.initState();
    _userType = widget.user.userType;
    _isParticulier = widget.user.isParticulier;
    _landCode = widget.user.landCode;
    _voornaamCtrl = TextEditingController(text: widget.user.voornaam ?? '');
    _achternaamCtrl = TextEditingController(text: widget.user.achternaam ?? '');
    _adresCtrl = TextEditingController(text: widget.user.adres ?? '');
    _postcodeCtrl = TextEditingController(text: widget.user.postcode ?? '');
    _woonplaatsCtrl = TextEditingController(text: widget.user.woonplaats ?? '');
    _telefoonCtrl = TextEditingController(text: widget.user.telefoon ?? '');
    _btwCtrl = TextEditingController(text: widget.user.btwNummer ?? '');
    _bedrijfCtrl = TextEditingController(text: widget.user.bedrijfsnaam ?? '');
    _ibanCtrl = TextEditingController(text: widget.user.iban ?? '');
    _kortingPermCtrl = TextEditingController(text: widget.user.kortingPermanent > 0 ? widget.user.kortingPermanent.toStringAsFixed(0) : '');
    _kortingTijdCtrl = TextEditingController(text: widget.user.kortingTijdelijk > 0 ? widget.user.kortingTijdelijk.toStringAsFixed(0) : '');
    _kortingGeldigTot = widget.user.kortingGeldigTot;
    _btwGevalideerd = widget.user.btwGevalideerd;
  }

  @override
  void dispose() {
    _voornaamCtrl.dispose();
    _achternaamCtrl.dispose();
    _adresCtrl.dispose();
    _postcodeCtrl.dispose();
    _woonplaatsCtrl.dispose();
    _telefoonCtrl.dispose();
    _btwCtrl.dispose();
    _bedrijfCtrl.dispose();
    _ibanCtrl.dispose();
    _kortingPermCtrl.dispose();
    _kortingTijdCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateVat() async {
    final raw = _btwCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() { _validating = true; _vatError = null; _vatName = null; });

    final result = await VatService().validateVat(raw);
    if (!mounted) return;
    setState(() {
      _validating = false;
      _btwGevalideerd = result.valid;
      _vatName = result.name;
      _vatError = result.valid ? null : result.error;
    });
  }

  Future<void> _pickKortingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _kortingGeldigTot ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _kortingGeldigTot = picked);
  }

  @override
  Widget build(BuildContext context) {
    final showBedrijf = !_isParticulier;
    final isBtwVerlegd = showBedrijf && _btwGevalideerd && _landCode != 'NL' && _isEuCountry;

    return AlertDialog(
      title: Text('Bewerken: ${widget.user.email}', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<UserType>(
                initialValue: _userType,
                decoration: const InputDecoration(labelText: 'Type gebruiker', prefixIcon: Icon(Icons.badge_outlined)),
                items: [UserType.owner, UserType.admin, UserType.klant, UserType.wederverkoper, UserType.prospect, UserType.user]
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _userType = v;
                    if (v.isBedrijf) _isParticulier = false;
                    if (v == UserType.klant || v == UserType.user || v == UserType.prospect) _isParticulier = true;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _landCode,
                decoration: const InputDecoration(labelText: 'Land', prefixIcon: Icon(Icons.public)),
                items: _countryItems(),
                onChanged: (v) { if (v != null) setState(() => _landCode = v); },
              ),
              const SizedBox(height: 16),
              const Text('Persoonlijke gegevens', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _voornaamCtrl, decoration: const InputDecoration(labelText: 'Voornaam', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _achternaamCtrl, decoration: const InputDecoration(labelText: 'Achternaam', border: OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 8),
              TextFormField(controller: _telefoonCtrl, decoration: const InputDecoration(labelText: 'Telefoon', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.phone_outlined, size: 18))),
              const SizedBox(height: 8),
              TextFormField(controller: _adresCtrl, decoration: const InputDecoration(labelText: 'Adres', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 130, child: TextFormField(controller: _postcodeCtrl, decoration: const InputDecoration(labelText: 'Postcode', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _woonplaatsCtrl, decoration: const InputDecoration(labelText: 'Woonplaats', border: OutlineInputBorder(), isDense: true))),
              ]),
              if (showBedrijf) ...[
                const SizedBox(height: 16),
                const Text('Bedrijfsgegevens', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(controller: _bedrijfCtrl, decoration: const InputDecoration(labelText: 'Bedrijfsnaam', prefixIcon: Icon(Icons.business))),
                if (_isEuCountry) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _btwCtrl,
                        decoration: InputDecoration(
                          labelText: 'BTW-nummer',
                          prefixIcon: const Icon(Icons.receipt_long),
                          suffixIcon: _validating
                              ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                              : _btwGevalideerd
                                  ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                                  : _vatError != null
                                      ? const Icon(Icons.cancel, color: Color(0xFFEF4444))
                                      : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _validating ? null : _validateVat,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                      child: const Text('VIES check'),
                    ),
                  ]),
                  if (_vatError != null)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(_vatError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
                  if (_vatName != null)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('Geregistreerd als: $_vatName', style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12))),
                  if (isBtwVerlegd)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('BTW verlegd (ICP)', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500))),
                ],
                if (!_isEuCountry)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('Geen BTW (buiten EU)', style: TextStyle(fontSize: 12, color: Colors.blueGrey[500]))),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ibanCtrl,
                  decoration: InputDecoration(
                    labelText: 'IBAN',
                    prefixIcon: const Icon(Icons.account_balance, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorText: _ibanError,
                  ),
                  onChanged: (v) => setState(() => _ibanError = VatService.validateIban(v)),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Kortingen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _kortingPermCtrl, decoration: const InputDecoration(labelText: 'Permanente korting %', prefixIcon: Icon(Icons.percent)), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _kortingTijdCtrl, decoration: const InputDecoration(labelText: 'Tijdelijke korting %', prefixIcon: Icon(Icons.timer)), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickKortingDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Korting geldig tot', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(
                    _kortingGeldigTot != null
                        ? '${_kortingGeldigTot!.day}-${_kortingGeldigTot!.month}-${_kortingGeldigTot!.year}'
                        : 'Geen einddatum',
                    style: TextStyle(fontSize: 14, color: _kortingGeldigTot != null ? null : Colors.blueGrey[400]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.security, size: 16, color: Colors.blueGrey[600]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Rechten worden toegewezen op basis van de rol (${_userType.label}). '
                    'Aanpasbaar via Rolrechten in het dashboard.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
        ElevatedButton(
          onPressed: (_ibanError != null) ? null : () {
            final isBtwVerlegdSave = !_isParticulier && _btwGevalideerd && _landCode != 'NL' && _isEuCountry;
            Navigator.pop(context, AppUser(
              id: widget.user.id,
              authUserId: widget.user.authUserId,
              email: widget.user.email,
              userType: _userType,
              status: widget.user.status,
              permissions: UserPermissions.defaultForRole(_userType),
              isAdmin: widget.user.isAdmin,
              isOwner: widget.user.isOwner,
              isParticulier: _isParticulier,
              voornaam: _voornaamCtrl.text.trim().isEmpty ? null : _voornaamCtrl.text.trim(),
              achternaam: _achternaamCtrl.text.trim().isEmpty ? null : _achternaamCtrl.text.trim(),
              adres: _adresCtrl.text.trim().isEmpty ? null : _adresCtrl.text.trim(),
              postcode: _postcodeCtrl.text.trim().isEmpty ? null : _postcodeCtrl.text.trim(),
              woonplaats: _woonplaatsCtrl.text.trim().isEmpty ? null : _woonplaatsCtrl.text.trim(),
              telefoon: _telefoonCtrl.text.trim().isEmpty ? null : _telefoonCtrl.text.trim(),
              bedrijfsnaam: _bedrijfCtrl.text.trim().isNotEmpty ? _bedrijfCtrl.text.trim() : null,
              btwNummer: _btwCtrl.text.trim().isNotEmpty ? _btwCtrl.text.trim() : null,
              btwGevalideerd: _btwGevalideerd,
              btwValidatieDatum: _btwGevalideerd ? DateTime.now() : widget.user.btwValidatieDatum,
              btwVerlegd: isBtwVerlegdSave,
              iban: _ibanCtrl.text.trim().isNotEmpty ? _ibanCtrl.text.replaceAll(RegExp(r'\s'), '').toUpperCase() : null,
              landCode: _landCode,
              kortingPermanent: (double.tryParse(_kortingPermCtrl.text) ?? 0).clamp(0, 50),
              kortingTijdelijk: (double.tryParse(_kortingTijdCtrl.text) ?? 0).clamp(0, 50),
              kortingGeldigTot: _kortingGeldigTot,
              createdAt: widget.user.createdAt,
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
          child: const Text('Opslaan'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _countryItems() {
    return VatService.sortedCountryEntries
        .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} – ${e.value}')))
        .toList();
  }
}
