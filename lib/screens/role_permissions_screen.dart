import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';

class RolePermissionsScreen extends StatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  State<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<RolePermissionsScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _gold = Color(0xFFD4A843);

  final _userService = UserService();
  bool _loading = true;
  bool _saving = false;
  bool _isOwner = false;
  bool _hasChanges = false;

  static const _allDisplayRoles = [
    UserType.owner,
    UserType.admin,
    UserType.wederverkoper,
    UserType.prospect,
    UserType.klant,
    UserType.user,
  ];

  late Map<String, UserPermissions> _rolePerms;

  @override
  void initState() {
    super.initState();
    _rolePerms = {
      for (final role in UserType.values)
        role.dbValue: UserPermissions.defaultForRole(role),
    };
    _load();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.rollenRechtenToewijzen) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    final isOwner = await _userService.isCurrentUserOwner();
    final saved = await _userService.loadRolePermissions();
    if (saved != null) {
      for (final entry in saved.entries) {
        _rolePerms[entry.key] = entry.value;
      }
    }
    // Owner always keeps all permissions
    _rolePerms[UserType.owner.dbValue] = UserPermissions.ownerPreset;
    if (mounted) setState(() { _isOwner = isOwner; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _userService.saveRolePermissions(_rolePerms);
      _hasChanges = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rolrechten opgeslagen'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opslaan mislukt: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _resetToDefaults() {
    setState(() {
      _rolePerms = {
        for (final role in UserType.values)
          role.dbValue: UserPermissions.defaultForRole(role),
      };
      _hasChanges = true;
    });
  }

  void _togglePermission(String roleDbValue, String permKey) {
    if (roleDbValue == UserType.owner.dbValue) return;
    final current = _rolePerms[roleDbValue]!;
    final newVal = !current.getByKey(permKey);
    setState(() {
      _rolePerms[roleDbValue] = current.withKey(permKey, newVal);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Rolrechten beheren', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (_isOwner && _hasChanges)
            TextButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.restore, color: Colors.white70, size: 18),
              label: Text('Standaard', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13)),
            ),
          if (_isOwner && _hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Opslaan...' : 'Opslaan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navy,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildMatrix(),
    );
  }

  Widget _buildMatrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTable(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Owner-rechten staan vast en kunnen niet worden gewijzigd. '
              'MFA is verplicht voor Owner, Admin en Wederverkoper; optioneel voor Klant.',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 16),
          _mfaBadge('Verplicht', const Color(0xFFE53935)),
          const SizedBox(width: 8),
          _mfaBadge('Optioneel', const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _mfaBadge('Geen', const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _mfaBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildTable() {
    const roleColWidth = 140.0;
    const permLabelWidth = 260.0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with role names
          Row(
            children: [
              SizedBox(
                width: permLabelWidth,
                child: Text('Autorisatie', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
              ),
              for (final role in _allDisplayRoles)
                SizedBox(
                  width: roleColWidth,
                  child: Column(
                    children: [
                      Text(role.label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                      const SizedBox(height: 4),
                      _mfaIndicator(role),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Category groups
          for (final category in UserPermissions.keyCategories.entries)
            _buildCategory(category.key, category.value, permLabelWidth, roleColWidth),
        ],
      ),
    );
  }

  Widget _mfaIndicator(UserType role) {
    if (role.mfaRequired) {
      return _mfaBadge('MFA verplicht', const Color(0xFFE53935));
    } else if (role.mfaOptional) {
      return _mfaBadge('MFA optioneel', const Color(0xFFF59E0B));
    } else {
      return _mfaBadge('Geen MFA', const Color(0xFF94A3B8));
    }
  }

  Widget _buildCategory(String title, List<String> keys, double labelWidth, double colWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: _navy, letterSpacing: 0.3)),
        ),
        const SizedBox(height: 6),
        for (final key in keys)
          _buildPermissionRow(key, labelWidth, colWidth),
      ],
    );
  }

  Widget _buildPermissionRow(String key, double labelWidth, double colWidth) {
    final label = UserPermissions.keyLabels[key] ?? key;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF334155))),
            ),
          ),
          for (final role in _allDisplayRoles)
            SizedBox(
              width: colWidth,
              child: Center(
                child: _permCheckbox(role, key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _permCheckbox(UserType role, String permKey) {
    final perms = _rolePerms[role.dbValue]!;
    final value = perms.getByKey(permKey);
    final isOwnerRole = role == UserType.owner;

    if (isOwnerRole) {
      return Icon(
        value ? Icons.check_circle : Icons.remove_circle_outline,
        size: 20,
        color: value ? const Color(0xFF2E7D32) : const Color(0xFFCBD5E1),
      );
    }

    if (!_isOwner) {
      return Icon(
        value ? Icons.check_circle : Icons.cancel_outlined,
        size: 20,
        color: value ? const Color(0xFF2E7D32) : const Color(0xFFCBD5E1),
      );
    }

    return InkWell(
      onTap: () => _togglePermission(role.dbValue, permKey),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          value ? Icons.check_box : Icons.check_box_outline_blank,
          size: 22,
          color: value ? const Color(0xFF1B4965) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}
