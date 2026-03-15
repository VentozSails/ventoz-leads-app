import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/statistics_service.dart';
import '../services/export_service.dart';
import '../services/user_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatisticsService _service = StatisticsService();
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;
  bool _canExport = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkExportPermission();
  }

  Future<void> _checkExportPermission() async {
    final perms = await UserService().getCurrentUserPermissions();
    if (mounted) setState(() => _canExport = perms.exporteren);
  }

  Future<void> _exportCsv() async {
    if (_stats == null) return;
    final s = _stats!;
    final csv = ExportService.statisticsToCsv({
      'totaalLeads': s.totaalLeads,
      'totaalKlanten': s.totaalKlanten,
      'conversieRatio': '${s.conversieRatio.toStringAsFixed(1)}%',
      'mails30Dagen': s.mails30Dagen,
      'mails7Dagen': s.mails7Dagen,
      'mailsTotaal': s.mailsTotaal,
      'leadsPerLand': s.leadsPerLand,
      'leadsPerStatus': s.leadsPerStatus,
      'productenInMails': s.productenInMails,
      'kortingscodesGebruikt': s.kortingscodesGebruikt,
    });
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final path = await ExportService.downloadCsv(csv, 'ventoz_statistieken_$now.csv');
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

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final perms = await UserService().getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.statistiekenBekijken) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    try {
      final stats = await _service.fetchStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading statistics: $e');
      if (mounted) setState(() { _error = 'Er is een fout opgetreden bij het laden.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const Text('Statistieken & Inzichten'),
        actions: [
          if (_canExport)
            IconButton(icon: const Icon(Icons.download), tooltip: 'Exporteer CSV', onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Vernieuwen', onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Fout: $_error'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final s = _stats!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKpiCards(s),
            const SizedBox(height: 24),
            _buildSectionTitle('Sales Funnel'),
            const SizedBox(height: 12),
            _buildFunnel(s),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Leads per Land'),
                      const SizedBox(height: 12),
                      _buildCountryChart(s),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Product Populariteit'),
                      const SizedBox(height: 12),
                      _buildProductChart(s),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Status Verdeling'),
                      const SizedBox(height: 12),
                      _buildStatusChart(s),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Top Kortingscodes'),
                      const SizedBox(height: 12),
                      _buildTopCodes(s),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== KPI CARDS ==========

  Widget _buildKpiCards(DashboardStats s) {
    return Row(
      children: [
        Expanded(child: _kpiCard(Icons.people, 'Totaal Leads', s.totaalLeads.toString(), const Color(0xFF455A64))),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(Icons.trending_up, 'Conversie', '${s.conversieRatio.toStringAsFixed(1)}%', const Color(0xFF10B981))),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(Icons.email, 'Mails (30d)', s.mails30Dagen.toString(), const Color(0xFF3B82F6),
            subtitle: '${s.mails7Dagen} afgelopen week')),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard(Icons.star, 'Klanten', s.totaalKlanten.toString(), const Color(0xFFF59E0B))),
      ],
    );
  }

  Widget _kpiCard(IconData icon, String label, String value, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ),
        ],
      ),
    );
  }

  // ========== SALES FUNNEL ==========

  Widget _buildFunnel(DashboardStats s) {
    final steps = [
      ('Nieuw', s.funnelNieuw, const Color(0xFF94A3B8)),
      ('Gemaild', s.funnelContact, const Color(0xFF3B82F6)),
      ('Aangeboden', s.funnelAangeboden, const Color(0xFFF59E0B)),
      ('Klant', s.funnelKlant, const Color(0xFF10B981)),
    ];
    final maxVal = s.funnelNieuw.clamp(1, double.maxFinite.toInt());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: steps.map((step) {
          final fraction = step.$2 / maxVal;
          final percentage = s.funnelNieuw > 0 ? (step.$2 / s.funnelNieuw * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(step.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    Text('${step.$2} (${percentage.toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: step.$3)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction.toDouble(),
                    minHeight: 18,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: step.$3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ========== COUNTRY BAR CHART ==========

  Widget _buildCountryChart(DashboardStats s) {
    final entries = s.leadsPerLand.entries.toList();
    final colors = [const Color(0xFF455A64), const Color(0xFF78909C), const Color(0xFFB0BEC5)];

    return _chartCard(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b) * 1.2).toDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                return BarTooltipItem(
                  '${entries[groupIdx].key}\n${rod.toY.toInt()} leads',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 35,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < entries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(entries[i].key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1)),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: entries[i].value.toDouble(), color: colors[i % colors.length], width: 32,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
            ]);
          }),
        ),
      ),
    );
  }

  // ========== PRODUCT PIE CHART ==========

  Widget _buildProductChart(DashboardStats s) {
    final entries = s.productenInMails.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return _chartCard(height: 220, child: const Center(child: Text('Nog geen producten in e-mails', style: TextStyle(color: Color(0xFF94A3B8)))));
    }

    final top = entries.take(6).toList();
    final total = top.fold(0, (sum, e) => sum + e.value);
    final pieColors = [
      const Color(0xFF455A64), const Color(0xFFF59E0B), const Color(0xFF3B82F6),
      const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFFEF4444),
    ];

    return _chartCard(
      height: 220,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: List.generate(top.length, (i) {
                  final pct = total > 0 ? (top[i].value / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: top[i].value.toDouble(),
                    color: pieColors[i % pieColors.length],
                    radius: 50,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(top.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: pieColors[i % pieColors.length], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 100,
                      child: Text(top[i].key, style: const TextStyle(fontSize: 10, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    Text('${top[i].value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ========== STATUS PIE CHART ==========

  Widget _buildStatusChart(DashboardStats s) {
    final entries = s.leadsPerStatus.entries.toList();
    if (entries.isEmpty) return _chartCard(height: 200, child: const Center(child: Text('Geen data')));

    final total = entries.fold(0, (sum, e) => sum + e.value);
    final statusColors = <String, Color>{
      'Nieuw': const Color(0xFF3B82F6),
      'Aangeboden': const Color(0xFFF59E0B),
      'Klant': const Color(0xFF10B981),
      'Niet interessant': const Color(0xFFEF4444),
    };

    return _chartCard(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: entries.map((e) {
                  final pct = total > 0 ? (e.value / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: e.value.toDouble(),
                    color: statusColors[e.key] ?? const Color(0xFF94A3B8),
                    radius: 45,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(
                      color: statusColors[e.key] ?? const Color(0xFF94A3B8), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(e.key, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    const SizedBox(width: 4),
                    Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ========== TOP CODES ==========

  Widget _buildTopCodes(DashboardStats s) {
    final entries = s.kortingscodesGebruikt.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return _chartCard(height: 200, child: const Center(child: Text('Nog geen kortingscodes verstuurd', style: TextStyle(color: Color(0xFF94A3B8)))));
    }

    final top = entries.take(8).toList();
    return _chartCard(
      height: 200,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: top.length,
        itemBuilder: (_, i) {
          final e = top[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 20,
                  alignment: Alignment.center,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF78350F), letterSpacing: 1)),
                ),
                const Spacer(),
                Text('${e.value}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              ],
            ),
          );
        },
      ),
    );
  }

  // ========== HELPERS ==========

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));
  }

  Widget _chartCard({required double height, required Widget child}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}
