import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/login_security_service.dart';
import '../services/user_service.dart';

class AdminLockedAccountsScreen extends StatefulWidget {
  const AdminLockedAccountsScreen({super.key});

  @override
  State<AdminLockedAccountsScreen> createState() => _AdminLockedAccountsScreenState();
}

class _AdminLockedAccountsScreenState extends State<AdminLockedAccountsScreen> {
  static const _navy = Color(0xFF1B2A4A);

  final _service = LoginSecurityService();
  final _userService = UserService();
  List<LockedAccount> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.geblokkeerdeAccountsBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final accounts = await _service.getLockedAccounts();
    if (mounted) setState(() { _accounts = accounts; _loading = false; });
  }

  Future<void> _unlock(LockedAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Account vrijgeven', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Weet je zeker dat je het account van ${account.email} wilt vrijgeven?\n\n'
          'De gebruiker kan daarna opnieuw proberen in te loggen.',
          style: GoogleFonts.dmSans(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Vrijgeven'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      await _service.unlockAccount(account.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${account.email} is vrijgegeven'), backgroundColor: const Color(0xFF2E7D32)),
        );
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text('Geblokkeerde accounts', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_open, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Geen geblokkeerde accounts', style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('Alles in orde!', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey.shade400)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) => _buildAccountCard(_accounts[index]),
                ),
    );
  }

  Widget _buildAccountCard(LockedAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock, color: Colors.red.shade600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(account.email, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
              if (account.naam.isNotEmpty)
                Text(account.naam, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
              if (account.lockedUntil != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Geblokkeerd wegens te veel mislukte pogingen',
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.red.shade600),
                ),
              ],
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => _unlock(account),
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text('Vrijgeven'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
    );
  }
}
