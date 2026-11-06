import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bills_screen.dart';
import 'calendar_screen.dart';
import 'debts_screen.dart';
import 'profile_screen.dart';
import 'split_screen.dart';
import 'transaction_form_screen.dart';
import 'wrapped_screen.dart';

/// Dashboard — cerminan `#tab-dashboard` di web:
/// header + saldo utama + action bar + 4 kartu ringkasan + transaksi terbaru.
/// Polish mobile: radius besar, shadow lembut, spacing lega (lihat DESIGN_AND_MAPPING.md).
class DashboardScreen extends StatelessWidget {
  final VoidCallback onGoWallet;
  final VoidCallback onGoReport;

  const DashboardScreen({
    super.key,
    required this.onGoWallet,
    required this.onGoReport,
  });

  void _openForm(BuildContext context, {AppTransaction? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(existing: existing),
      ),
    );
  }

  Future<void> _deleteTrx(
    BuildContext context,
    AppState state,
    AppTransaction trx,
  ) async {
    final ok = await showAppConfirm(
      context,
      title: state.t('delete'),
      message: state.t('delete_trx_confirm'),
      confirmLabel: state.t('delete'),
      isDestructive: true,
    );
    if (ok == true) await state.deleteTransaction(trx.id);
  }

  void _showMonthDetail(BuildContext context, AppState state, String jenis) {
    final list = state.monthTransactions(jenis);
    final total = list.fold<int>(0, (sum, t) => sum + t.nominal);
    final isIn = jenis == 'pemasukan';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // SafeArea (bottom: true) agar isi bawah sheet tidak tertutup system
      // navigation bar Android — pola yang sama dengan form utang/tagihan
      // (laporan user 2026-11-06).
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => SafeArea(
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isIn
                        ? 'Rincian Pemasukan Bulan Ini'
                        : 'Rincian Pengeluaran Bulan Ini',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.gray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIn ? 'Total Pemasukan' : 'Total Pengeluaran',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isPrivacyMode ? 'Rp •••' : formatRupiah(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          state.t('no_trx_yet'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: list.length,
                        itemBuilder: (_, i) =>
                            TransactionTile(trx: list[i], state: state),
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showUnpaidBills(BuildContext context, AppState state) {
    final bills = state.unpaidBills;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // SafeArea (bottom: true) agar isi bawah sheet tidak tertutup system
      // navigation bar Android — pola yang sama dengan form utang/tagihan
      // (laporan user 2026-11-06).
      builder: (ctx) => SafeArea(
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                state.t('bills_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: 6),
            Text(
              state.t('not_yet_paid'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (bills.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    state.t('all_paid'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else
              ...bills.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.nama,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              'Tempo: ${formatTanggalPendek(parseIsoDate(b.tanggal))}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        Text(
                          state.isPrivacyMode ? '•••' : formatRupiah(b.nominal),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.orange),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.recentTransactions;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Header (logo + profil + kalender + notifikasi) ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DasboardReport',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gray,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    size: 13,
                                    color: AppColors.purple,
                                  ),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 100,
                                    ),
                                    child: Text(
                                      state.activeProfile ?? 'Akun',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    size: 13,
                                    color: AppColors.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.calendar_month_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CalendarScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleIconButton(
                        icon: Icons.notifications_rounded,
                        onTap: () => _showUnpaidBills(context, state),
                        badge: state.unpaidBills.isNotEmpty
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---------- Saldo utama ----------
              Text(
                state.t('main_balance'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.isPrivacyMode
                        ? 'Rp •••'
                        : formatRupiah(state.balance),
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  CircleIconButton(
                    size: 34,
                    iconSize: 16,
                    icon: state.isPrivacyMode
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    onTap: state.togglePrivacy,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------- Action bar: Add / Split / Utang / Wrap ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ActionItem(
                    icon: Icons.add_rounded,
                    label: state.t('btn_add'),
                    onTap: () => _openForm(context),
                  ),
                  _ActionItem(
                    icon: Icons.safety_divider_rounded,
                    label: state.t('btn_split'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SplitScreen()),
                    ),
                  ),
                  _ActionItem(
                    icon: Icons.handshake_rounded,
                    label: state.t('btn_debt'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DebtsScreen()),
                    ),
                  ),
                  _ActionItem(
                    icon: Icons.auto_awesome_rounded,
                    label: state.t('btn_wrap'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WrappedScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------- Ringkasan bulan ini ----------
              SectionHeader(
                title: state.t('summary_month'),
                linkLabel: state.t('analysis_link'),
                onLinkTap: onGoReport,
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  SummaryCard(
                    color: AppColors.purple,
                    icon: Icons.arrow_downward_rounded,
                    label: state.t('income'),
                    amount: state.isPrivacyMode
                        ? '•••'
                        : formatRupiah(state.monthIncome),
                    onTap: () => _showMonthDetail(context, state, 'pemasukan'),
                  ),
                  SummaryCard(
                    color: AppColors.blue,
                    icon: Icons.arrow_upward_rounded,
                    label: state.t('expense'),
                    amount: state.isPrivacyMode
                        ? '•••'
                        : formatRupiah(state.monthExpense),
                    onTap: () =>
                        _showMonthDetail(context, state, 'pengeluaran'),
                  ),
                  SummaryCard(
                    color: AppColors.green,
                    icon: Icons.receipt_long_rounded,
                    label: state.t('upcoming_bills'),
                    amount: '${state.unpaidBills.length} Item',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BillsScreen()),
                    ),
                  ),
                  SummaryCard(
                    color: AppColors.orange,
                    icon: Icons.warning_rounded,
                    label: state.t('active_receivables'),
                    amount: state.isPrivacyMode
                        ? '•••'
                        : formatRupiah(state.netReceivable),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DebtsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---------- Transaksi terbaru ----------
              SectionHeader(
                title: state.t('recent_trx'),
                linkLabel: state.t('view_all'),
                onLinkTap: onGoWallet,
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      state.t('no_trx_yet'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                ...recent.map(
                  (t) => TransactionTile(
                    trx: t,
                    state: state,
                    onTap: () => _openForm(context, existing: t),
                    onDelete: () => _deleteTrx(context, state, t),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gray,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(icon, size: 20, color: AppColors.black),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
