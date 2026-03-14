import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/customer_service.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);

  final _service = CustomerService();
  final _searchCtrl = TextEditingController();

  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await _service.getAll(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
    if (mounted) setState(() { _customers = results; _loading = false; });
  }

  void _openDetail(Customer? customer) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer?.id)),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Klanten', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.person_add_rounded), onPressed: () => _openDetail(null)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Zoek op naam, email, klantnummer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); })
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _load(),
              onChanged: (v) {
                if (v.isEmpty) _load();
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('${_customers.length} klanten', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B))),
                const Spacer(),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Vernieuwen'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Geen klanten gevonden', style: GoogleFonts.dmSans(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _customers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final c = _customers[i];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => _openDetail(c),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: _accent.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          c.volledigeNaam.isNotEmpty ? c.volledigeNaam[0].toUpperCase() : '?',
                                          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _accent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(c.volledigeNaam, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _accent.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(c.klantnummer, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: _accent)),
                                              ),
                                              if (c.authUserId != null) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.verified_user, size: 14, color: Color(0xFF2E7D32)),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(c.email, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                                          if (c.bedrijfsnaam != null && c.bedrijfsnaam!.isNotEmpty)
                                            Text(c.bedrijfsnaam!, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (c.woonplaats != null)
                                          Text(c.woonplaats!, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                                        Text(c.landCode, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade300),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
