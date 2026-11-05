import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Layar Utang-Piutang — cerminan `#tab-piutang` di web:
/// ringkasan saldo bersih + daftar + tambah. Lunasi: konfirmasi → transaksi
/// otomatis (lihat AppState.settleDebt) → bila cicilan, tanya buat cicilan
/// berikutnya. Item view-only (dibuat orang lain) tidak bisa dilunasi/diubah.
class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final active = state.debts.where((d) => !d.isLunas).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final done = state.debts.where((d) => d.isLunas).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final totalPiutang = active
        .where((d) => d.isPiutang)
        .fold<int>(0, (sum, d) => sum + d.nominal);
    final totalUtang = active
        .where((d) => !d.isPiutang)
        .fold<int>(0, (sum, d) => sum + d.nominal);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('debt_title'),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.t('net_balance'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isPrivacyMode
                          ? 'Rp •••'
                          : formatRupiah(totalPiutang - totalUtang),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.t('debt_piutang')}: ${formatRupiah(totalPiutang)}'
                      '  •  ${state.t('debt_utang')}: ${formatRupiah(totalUtang)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                state.t('debt_modal_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
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
                ...active.map((d) => _debtTile(context, state, d)),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  state.t('done_label'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...done.map((d) => _debtTile(context, state, d)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDebtForm(context, state),
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: Text(
          state.t('debt_add'),
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _debtTile(BuildContext context, AppState state, Debt debt) {
    final isViewOnly =
        debt.creatorName.isNotEmpty && debt.creatorName != state.activeProfile;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: debt.isPiutang
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  debt.isPiutang
                      ? state.t('debt_piutang')
                      : state.t('debt_utang'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: debt.isPiutang ? AppColors.green : AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  debt.partnerName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                formatRupiah(debt.nominal),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: debt.isPiutang ? AppColors.green : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatTanggalPendek(parseIsoDate(debt.tanggal))}'
            '${debt.tipeTempo == 'cicilan' ? ' • ${state.t('debt_installment_n', {'n': (debt.cicilanKe ?? 1).toString(), 'total': (debt.tenorBulan ?? 1).toString()})}' : ''}'
            '${debt.keterangan.isNotEmpty ? ' • ${debt.keterangan}' : ''}'
            '${isViewOnly ? ' ${state.t('debt_view_only')}' : ''}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (debt.syncCode.isNotEmpty)
            Text(
              'Kode: ${debt.syncCode}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (!debt.isLunas && !isViewOnly) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _settle(context, state, debt),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: const BorderSide(color: AppColors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(state.t('action_settle')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _deleteDebt(context, state, debt),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(state.t('delete')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _settle(BuildContext context, AppState state, Debt debt) async {
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
    if (ok != true) return;
    final canCreateNext = await state.settleDebt(debt.id);
    if (!context.mounted) return;
    if (canCreateNext) {
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

  Future<void> _deleteDebt(
    BuildContext context,
    AppState state,
    Debt debt,
  ) async {
    final ok = await showAppConfirm(
      context,
      title: state.t('delete'),
      message: state.t('debt_log_deleted', {
        'jenis': debt.jenis,
        'name': debt.partnerName,
      }),
      confirmLabel: state.t('delete'),
      isDestructive: true,
    );
    if (ok == true) await state.deleteDebt(debt.id);
  }

  void _showDebtForm(BuildContext context, AppState state) {
    var jenis = 'piutang';
    var tipeTempo = 'tanpa_tempo';
    var tenor = 1;
    var cicilanKe = 1;
    var tanggal = DateTime.now();
    final partnerCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  state.t('debt_add'),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                // Jenis.
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      for (final j in ['piutang', 'utang'])
                        Expanded(
                          child: InkWell(
                            onTap: () => setSheet(() => jenis = j),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: jenis == j
                                    ? AppColors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: jenis == j ? AppShadows.soft : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                j == 'piutang'
                                    ? state.t('debt_piutang')
                                    : state.t('debt_utang'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: jenis == j
                                      ? AppColors.black
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partnerCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: state.t('debt_partner'),
                    hintText: state.t('debt_partner_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: state.t('amount_label'),
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tanggal,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheet(() => tanggal = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('d MMMM yyyy', 'id_ID').format(tanggal),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: state.t('description'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tipe tempo.
                DropdownButtonFormField<String>(
                  initialValue: tipeTempo,
                  decoration: InputDecoration(
                    labelText: state.t('debt_tempo'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'tanpa_tempo',
                      child: Text(state.t('debt_no_tempo')),
                    ),
                    DropdownMenuItem(
                      value: 'cicilan',
                      child: Text(state.t('debt_installment')),
                    ),
                  ],
                  onChanged: (v) => setSheet(() => tipeTempo = v!),
                ),
                if (tipeTempo == 'cicilan') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: tenor,
                          decoration: InputDecoration(
                            labelText: state.t('total_tenor'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ),
                          onChanged: (v) => setSheet(() {
                            tenor = v!;
                            if (cicilanKe > tenor) cicilanKe = tenor;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: cicilanKe,
                          decoration: InputDecoration(
                            labelText: state.t('debt_cicilan_ke'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: List.generate(
                            tenor,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ),
                          onChanged: (v) => setSheet(() => cicilanKe = v!),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: state.t('save'),
                  onPressed: () async {
                    final partner = partnerCtrl.text.trim();
                    final amount = parseNominal(amountCtrl.text);
                    if (partner.isEmpty || amount <= 0) {
                      showAppSnack(
                        ctx,
                        state.t('required_field'),
                        isError: true,
                      );
                      return;
                    }
                    await state.addDebt(
                      Debt(
                        id: DateTime.now().millisecondsSinceEpoch,
                        profile: state.activeProfile ?? '',
                        creatorName: state.activeProfile ?? '',
                        partnerName: partner,
                        jenis: jenis,
                        tipeTempo: tipeTempo,
                        tenorBulan: tipeTempo == 'cicilan' ? tenor : null,
                        cicilanKe: tipeTempo == 'cicilan' ? cicilanKe : null,
                        tanggal: toIsoDate(tanggal),
                        nominal: amount,
                        keterangan: noteCtrl.text.trim(),
                        status: 'belum',
                        syncCode: '',
                      ),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
