import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets.dart';

/// Financial Wrapped — cerminan `#tab-wrap` di web:
/// nama profil, total transaksi tercatat, kategori pengeluaran terbesar,
/// plus ringkasan tahun (pemasukan/pengeluaran & transaksi terbesar).
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final years =
        state.transactions
            .map((t) => parseIsoDate(t.tanggal).year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (years.isEmpty) years.add(DateTime.now().year);
    if (!years.contains(_year)) _year = years.first;

    final yearTrx = state.transactions
        .where((t) => parseIsoDate(t.tanggal).year == _year)
        .toList();
    final income = yearTrx
        .where((t) => t.isPemasukan)
        .fold<int>(0, (s, t) => s + t.nominal);
    final expense = yearTrx
        .where((t) => !t.isPemasukan)
        .fold<int>(0, (s, t) => s + t.nominal);
    final byCategory = <String, int>{};
    for (final t in yearTrx) {
      if (t.isPemasukan) continue;
      byCategory[t.kategori] = (byCategory[t.kategori] ?? 0) + t.nominal;
    }
    String topCategory = '-';
    var topCategoryAmount = 0;
    byCategory.forEach((k, v) {
      if (v > topCategoryAmount) {
        topCategory = k;
        topCategoryAmount = v;
      }
    });
    final topTrx = yearTrx.isEmpty
        ? null
        : yearTrx.reduce((a, b) => a.nominal >= b.nominal ? a : b);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('wrap_title'),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pilih tahun.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.activeProfile ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  DropdownButton<int>(
                    value: _year,
                    items: years
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _year = v ?? _year),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _wrapCard(
                context,
                Icons.receipt_long_rounded,
                state.t('wrap_total_trx'),
                '${yearTrx.length}',
                AppColors.purple,
              ),
              const SizedBox(height: 10),
              _wrapCard(
                context,
                Icons.arrow_downward_rounded,
                state.t('wrap_total_income'),
                formatRupiah(income),
                AppColors.green,
              ),
              const SizedBox(height: 10),
              _wrapCard(
                context,
                Icons.arrow_upward_rounded,
                state.t('wrap_total_expense'),
                formatRupiah(expense),
                AppColors.danger,
              ),
              const SizedBox(height: 10),
              _wrapCard(
                context,
                categoryIcon(topCategory),
                state.t('wrap_top_category'),
                topCategory == '-'
                    ? '-'
                    : '$topCategory • ${formatRupiah(topCategoryAmount)}',
                AppColors.orange,
              ),
              if (topTrx != null) ...[
                const SizedBox(height: 10),
                _wrapCard(
                  context,
                  Icons.star_rounded,
                  state.t('wrap_top_trx'),
                  '${topTrx.keterangan} • ${formatRupiah(topTrx.nominal)}',
                  AppColors.blue,
                ),
              ],
              const SizedBox(height: 20),
              Text(
                state.t('wrap_monthly'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...List.generate(12, (i) => i + 1).map((month) {
                final mTrx = yearTrx.where((t) {
                  final d = parseIsoDate(t.tanggal);
                  return d.month == month;
                }).toList();
                final mExp = mTrx
                    .where((t) => !t.isPemasukan)
                    .fold<int>(0, (s, t) => s + t.nominal);
                final mInc = mTrx
                    .where((t) => t.isPemasukan)
                    .fold<int>(0, (s, t) => s + t.nominal);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatBulanTahun(DateTime(_year, month)).split(',')[0],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${mTrx.length} trx • +${formatRupiah(mInc)} / -${formatRupiah(mExp)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
