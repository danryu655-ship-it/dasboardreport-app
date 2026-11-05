import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Layar Tagihan — cerminan `#tab-bills` di web:
/// ringkasan total belum/telah dibayar + daftar tagihan + tambah.
/// Bayar: konfirmasi → otomatis buat pengeluaran "Bayar Tagihan: [nama]"
/// (lihat AppState.payBill).
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final unpaid = state.bills.where((b) => !b.isLunas).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final paid = state.bills.where((b) => b.isLunas).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final totalUnpaid = unpaid.fold<int>(0, (sum, b) => sum + b.nominal);
    final totalPaid = paid.fold<int>(0, (sum, b) => sum + b.nominal);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('bills_title'),
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
              // Ringkasan.
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      context,
                      state.t('bills_total_unpaid'),
                      formatRupiah(totalUnpaid),
                      AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryCard(
                      context,
                      state.t('bills_total_paid'),
                      formatRupiah(totalPaid),
                      AppColors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                state.t('bills_waiting', {'n': unpaid.length.toString()}),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (unpaid.isEmpty)
                _emptyState(context, state)
              else
                ...unpaid.map((b) => _billTile(context, state, b)),
              if (paid.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  state.t('bills_done_count', {'n': paid.length.toString()}),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...paid.map((b) => _billTile(context, state, b)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBillForm(context, state),
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: Text(
          state.t('bills_add'),
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
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
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 40,
            color: AppColors.green,
          ),
          const SizedBox(height: 8),
          Text(
            state.t('bills_empty'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            state.t('bills_empty_sub'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _billTile(BuildContext context, AppState state, Bill bill) {
    final due = parseIsoDate(bill.tanggal);
    final overdue = !bill.isLunas && due.isBefore(DateTime.now().startOfDay());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bill.isLunas
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              bill.isLunas ? Icons.check_rounded : Icons.receipt_long_rounded,
              color: bill.isLunas ? AppColors.green : AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.nama, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Tempo: ${formatTanggalPendek(due)}'
                  '${overdue ? ' • Terlambat' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: overdue ? AppColors.danger : AppColors.muted,
                  ),
                ),
                Text(
                  formatRupiah(bill.nominal),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppColors.orange),
                ),
              ],
            ),
          ),
          if (!bill.isLunas)
            ElevatedButton(
              onPressed: () => _payBill(context, state, bill),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: Text(state.t('bill_pay')),
            )
          else
            const Icon(Icons.check_circle_rounded, color: AppColors.green),
          IconButton(
            onPressed: () => _deleteBill(context, state, bill),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payBill(BuildContext context, AppState state, Bill bill) async {
    final ok = await showAppConfirm(
      context,
      title: state.t('bill_pay'),
      message: state.t('bill_pay_confirm', {
        'name': bill.nama,
        'amount': formatRupiah(bill.nominal),
      }),
      confirmLabel: state.t('bill_pay'),
    );
    if (ok != true) return;
    await state.payBill(bill.id);
    if (context.mounted) showAppSnack(context, state.t('bill_paid_ok'));
  }

  Future<void> _deleteBill(
    BuildContext context,
    AppState state,
    Bill bill,
  ) async {
    final ok = await showAppConfirm(
      context,
      title: state.t('delete'),
      message: state.t('bill_delete_confirm'),
      confirmLabel: state.t('delete'),
      isDestructive: true,
    );
    if (ok == true) await state.deleteBill(bill.id);
  }

  void _showBillForm(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var due = DateTime.now();
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
                state.t('bills_add'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: state.t('bill_name'),
                  hintText: state.t('bill_name_hint'),
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
                    initialDate: due,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheet(() => due = picked);
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
                        DateFormat('d MMMM yyyy', 'id_ID').format(due),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: state.t('save'),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final amount = parseNominal(amountCtrl.text);
                  if (name.isEmpty || amount <= 0) {
                    showAppSnack(ctx, state.t('required_field'), isError: true);
                    return;
                  }
                  await state.addBill(
                    Bill(
                      id: DateTime.now().millisecondsSinceEpoch,
                      profile: state.activeProfile ?? '',
                      nama: name,
                      nominal: amount,
                      tanggal: toIsoDate(due),
                      status: 'belum',
                    ),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _DateOnly on DateTime {
  DateTime startOfDay() => DateTime(year, month, day);
}
