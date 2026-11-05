import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'transaction_form_screen.dart';

/// Kalender — cerminan `#tab-kalender` di web: pilih tanggal → rekap
/// transaksi hari itu (total pemasukan/pengeluaran + daftar).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  List<AppTransaction> _dayTransactions(AppState state, DateTime day) {
    final iso = toIsoDate(day);
    return state.transactions.where((t) => t.tanggal == iso).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final days = _monthDays(_month);
    final dayTrx = _dayTransactions(state, _selected);
    final income = dayTrx
        .where((t) => t.isPemasukan)
        .fold<int>(0, (s, t) => s + t.nominal);
    final expense = dayTrx
        .where((t) => !t.isPemasukan)
        .fold<int>(0, (s, t) => s + t.nominal);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('calendar_title'),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Navigasi bulan.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    formatBulanTahun(_month),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Header hari.
              Row(
                children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              // Grid tanggal.
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: firstWeekday - 1 + days,
                itemBuilder: (ctx, i) {
                  if (i < firstWeekday - 1) return const SizedBox.shrink();
                  final day = i - (firstWeekday - 1) + 1;
                  final date = DateTime(_month.year, _month.month, day);
                  final hasTrx = _dayTransactions(state, date).isNotEmpty;
                  final isSelected =
                      date.year == _selected.year &&
                      date.month == _selected.month &&
                      date.day == _selected.day;
                  final isToday =
                      date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;
                  return InkWell(
                    onTap: () => setState(() => _selected = date),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.purple
                            : isToday
                            ? AppColors.gray
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.black,
                            ),
                          ),
                          if (hasTrx)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.purple,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Rekap hari yang dipilih.
              Text(
                DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selected),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _daySummary(
                      context,
                      state.t('income'),
                      formatRupiah(income),
                      AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _daySummary(
                      context,
                      state.t('expense'),
                      formatRupiah(expense),
                      AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (dayTrx.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      state.t('calendar_no_trx'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                ...dayTrx.map(
                  (t) => TransactionTile(
                    trx: t,
                    state: state,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionFormScreen(existing: t),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _monthDays(DateTime month) {
    final next = DateTime(month.year, month.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  Widget _daySummary(
    BuildContext context,
    String label,
    String amount,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
