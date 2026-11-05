import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'transaction_form_screen.dart';

/// Layar Wallet — cerminan `#tab-wallet` di web:
/// ringkasan saldo + pengeluaran bulan ini, grafik garis pengeluaran harian
/// (ungu #9b65f7), pencarian, filter tanggal, filter jenis
/// (Semua/Masuk/Keluar/Piutang), navigasi bulan, daftar gabungan transaksi +
/// utang/piutang (urut tanggal desc).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _search = '';
  String _jenis = 'semua';
  DateTime? _from;
  DateTime? _to;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _iso(DateTime? d) => d == null ? null : toIsoDate(d);

  Future<void> _pickRangeDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final monthExpense = state
        .transactionsForMonth(_month.year, _month.month)
        .where((t) => !t.isPemasukan)
        .fold<int>(0, (s, t) => s + t.nominal);
    final daily = state.dailyExpense(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    final trx = state.walletTransactions(
      search: _search,
      from: _iso(_from),
      to: _iso(_to),
      jenis: _jenis == 'piutang' ? 'semua' : _jenis,
    );
    final debts = _jenis == 'piutang'
        ? state.walletDebts(
            search: _search,
            from: _iso(_from),
            to: _iso(_to),
            jenis: 'piutang',
          )
        : (_jenis == 'semua'
              ? state.walletDebts(
                  search: _search,
                  from: _iso(_from),
                  to: _iso(_to),
                  jenis: 'semua',
                )
              : <Debt>[]);

    // Gabung + urut tanggal desc (cerminan renderSemuaTransaksi di web).
    final merged =
        <_WalletEntry>[
          for (final t in trx) _WalletEntry.trx(t),
          for (final d in debts) _WalletEntry.debt(d),
        ]..sort((a, b) {
          final cmp = b.tanggal.compareTo(a.tanggal);
          return cmp != 0 ? cmp : b.id.compareTo(a.id);
        });

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('nav_wallet'),
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
              // Ringkasan.
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      context,
                      state.t('main_balance'),
                      state.isPrivacyMode
                          ? 'Rp •••'
                          : formatRupiah(state.balance),
                      AppColors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryCard(
                      context,
                      state.t('wallet_spent'),
                      state.isPrivacyMode ? '•••' : formatRupiah(monthExpense),
                      AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Grafik garis pengeluaran harian.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gray,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.t('wallet_chart_title'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _LineChartPainter(daily, daysInMonth),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Pencarian.
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: state.t('search_trx'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              // Filter tanggal.
              Row(
                children: [
                  Expanded(
                    child: _dateChip(
                      context,
                      _from == null
                          ? state.t('from_date')
                          : DateFormat('d MMM yyyy', 'id_ID').format(_from!),
                      () => _pickRangeDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateChip(
                      context,
                      _to == null
                          ? state.t('to_date')
                          : DateFormat('d MMM yyyy', 'id_ID').format(_to!),
                      () => _pickRangeDate(context, false),
                    ),
                  ),
                  if (_from != null || _to != null)
                    IconButton(
                      onPressed: () => setState(() {
                        _from = null;
                        _to = null;
                      }),
                      icon: const Icon(Icons.clear_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter jenis.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final j in [
                      ('semua', state.t('all_label')),
                      ('pemasukan', state.t('income')),
                      ('pengeluaran', state.t('expense')),
                      ('piutang', state.t('debt_label')),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(j.$2),
                          selected: _jenis == j.$1,
                          selectedColor: AppColors.purple,
                          labelStyle: TextStyle(
                            color: _jenis == j.$1
                                ? AppColors.white
                                : AppColors.black,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _jenis = j.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Daftar gabungan.
              if (merged.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      state.t('no_trx_found'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                ...merged.map((e) {
                  if (e.trx != null) {
                    final t = e.trx!;
                    return TransactionTile(
                      trx: t,
                      state: state,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionFormScreen(existing: t),
                        ),
                      ),
                      onDelete: () async {
                        final ok = await showAppConfirm(
                          context,
                          title: state.t('delete'),
                          message: state.t('delete_trx_confirm'),
                          confirmLabel: state.t('delete'),
                          isDestructive: true,
                        );
                        if (ok == true) {
                          await state.deleteTransaction(t.id);
                        }
                      },
                    );
                  }
                  final d = e.debt!;
                  return _debtRow(context, state, d);
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String label,
    String amount,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(BuildContext context, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: AppColors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _debtRow(BuildContext context, AppState state, Debt debt) {
    final isViewOnly =
        debt.creatorName.isNotEmpty && debt.creatorName != state.activeProfile;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: debt.isPiutang
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              debt.isPiutang
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: debt.isPiutang ? AppColors.green : AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.partnerName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${debt.jenis} • ${formatTanggalPendek(parseIsoDate(debt.tanggal))}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (!debt.isLunas && !isViewOnly)
            TextButton(
              onPressed: () async {
                final ok = await showAppConfirm(
                  context,
                  title: state.t('action_settle'),
                  message: state.t('debt_settle_confirm', {
                    'jenis': debt.jenis,
                    'name': debt.partnerName,
                    'amount': formatRupiah(debt.nominal),
                  }),
                  confirmLabel: state.t('action_settle'),
                );
                if (ok == true) {
                  final canNext = await state.settleDebt(debt.id);
                  if (context.mounted && canNext) {
                    final next = (debt.cicilanKe ?? 0) + 1;
                    final create = await showAppConfirm(
                      context,
                      title: state.t('action_settle'),
                      message: state.t('next_installment', {
                        'n': (debt.cicilanKe ?? 0).toString(),
                        'total': (debt.tenorBulan ?? 0).toString(),
                        'next': next.toString(),
                      }),
                      confirmLabel: state.t('yes'),
                    );
                    if (create == true) {
                      await state.createNextInstallment(debt.id);
                    }
                  }
                }
              },
              child: Text(state.t('action_settle')),
            ),
          Text(
            '${debt.isPiutang ? '+' : '-'}${formatRupiah(debt.nominal)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: debt.isPiutang ? AppColors.green : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

/// Entri daftar Wallet: transaksi atau utang/piutang.
class _WalletEntry {
  final AppTransaction? trx;
  final Debt? debt;
  _WalletEntry.trx(this.trx) : debt = null;
  _WalletEntry.debt(this.debt) : trx = null;
  String get tanggal => trx?.tanggal ?? debt!.tanggal;
  int get id => trx?.id ?? debt!.id;
}

/// Grafik garis pengeluaran harian — cerminan renderGrafik() di web
/// (garis ungu #9b65f7 dengan titik dan area bawah).
class _LineChartPainter extends CustomPainter {
  final Map<int, int> daily;
  final int daysInMonth;
  _LineChartPainter(this.daily, this.daysInMonth);

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = daily.values.fold<int>(0, math.max);
    if (maxValue == 0) {
      final paint = Paint()
        ..color = AppColors.muted
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, size.height - 8),
        Offset(size.width, size.height - 8),
        paint,
      );
      return;
    }
    final points = <Offset>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final value = (daily[day] ?? 0).toDouble();
      final x = (day - 1) / (daysInMonth - 1) * size.width;
      final y = size.height - 8 - (value / maxValue) * (size.height - 16);
      points.add(Offset(x, y));
    }
    final linePaint = Paint()
      ..color = AppColors.purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    // Area bawah garis.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.purple.withValues(alpha: 0.12),
    );
    canvas.drawPath(path, linePaint);
    // Titik di hari yang ada pengeluaran.
    final dotPaint = Paint()..color = AppColors.purple;
    for (var day = 1; day <= daysInMonth; day++) {
      if ((daily[day] ?? 0) > 0) {
        canvas.drawCircle(points[day - 1], 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.daily != daily || oldDelegate.daysInMonth != daysInMonth;
  }
}
