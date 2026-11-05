import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets.dart';

/// Layar Report — cerminan `#tab-laporan` di web:
/// donut alokasi pengeluaran per kategori + filter periode (YYYY-MM) dan
/// kategori + rincian dengan total. Bila satu kategori dipilih, donut
/// menampilkan rincian per keterangan (cerminan renderLaporan).
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _periode = 'semua';
  String _kategori = 'semua';

  static const _palette = [
    Color(0xFF9B65F7),
    Color(0xFF2A94F6),
    Color(0xFF0DB35C),
    Color(0xFFF2780C),
    Color(0xFFFF3B30),
    Color(0xFF00B8A9),
    Color(0xFFEC4899),
    Color(0xFF8D6E63),
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final periods = state.expensePeriods;
    final categories = state.expenseCategories;
    final data = state.reportAggregation(
      periode: _periode,
      kategori: _kategori,
    );
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final items = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final list = state.reportTransactions(
      periode: _periode,
      kategori: _kategori,
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('report_title'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter periode + kategori.
              Row(
                children: [
                  Expanded(
                    child: _filterDropdown(
                      value: _periode,
                      items: ['semua', ...periods],
                      labels: {
                        'semua': state.t('all_label'),
                        for (final p in periods) p: p,
                      },
                      onChanged: (v) => setState(() => _periode = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _filterDropdown(
                      value: _kategori,
                      items: ['semua', ...categories],
                      labels: {
                        'semua': state.t('all_label'),
                        for (final c in categories) c: c,
                      },
                      onChanged: (v) => setState(() => _kategori = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      state.t('report_no_data'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else ...[
                // Donut.
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _DonutPainter(items, _palette),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.t('report_total'),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.isPrivacyMode ? '•••' : formatRupiah(total),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Legenda + rincian agregasi.
                ...items.asMap().entries.map((e) {
                  final i = e.key;
                  final entry = e.value;
                  final pct = total == 0 ? 0.0 : entry.value / total * 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatRupiah(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              // Rincian per transaksi.
              if (list.isNotEmpty) ...[
                Text(
                  state.t('report_detail'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...list.map((t) => TransactionTile(trx: t, state: state)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required Map<String, String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(labels[e] ?? e, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Donut chart — cerminan renderDonut() di web (SVG stroke-dasharray).
class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> items;
  final List<Color> palette;
  _DonutPainter(this.items, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<int>(0, (s, e) => s + e.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const stroke = 28.0;
    if (total == 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppColors.gray
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < items.length; i++) {
      final sweep = items[i].value / total * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..color = palette[i % palette.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}
