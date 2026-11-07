import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../format.dart';
import '../services/export_service.dart';
import '../sync/sheets_backup.dart';
import '../theme.dart';
import '../widgets.dart';

/// Layar Ekspor — cerminan `exportPDF()` / `exportExcel()` di web:
/// filter jenis laporan (semua/pemasukan/pengeluaran/utang) + rentang tanggal
/// (default bulan berjalan tanggal 1 → hari ini). PDF format neraca, Excel
/// = CSV. Ditambah tombol Backup ke Google Sheets (manual, hanya bila URL
/// Web App sudah dikonfigurasi via --dart-define).
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _jenis = 'semua';
  late DateTime _from;
  late DateTime _to;
  bool _busy = false;
  bool _dialogShown = false;

  /// Dialog progres modal (tidak bisa ditutup paksa) supaya pengguna selalu
  /// melihat animasi saat file disiapkan — sebelumnya tombol hanya nonaktif
  /// tanpa umpan balik, sehingga ekspor terasa "tidak ada hasil".
  void _showProgress(String message) {
    if (_dialogShown) return;
    _dialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  void _hideProgress() {
    if (!_dialogShown) return;
    _dialogShown = false;
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = now;
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
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

  bool get _hasData {
    final state = context.watchAppState();
    if (_jenis == 'utang') {
      return state.debts.any((d) {
        final day = parseIsoDate(d.tanggal);
        return !day.isBefore(_from) && !day.isAfter(_to);
      });
    }
    return state.transactions.any((t) {
      final day = parseIsoDate(t.tanggal);
      return (_jenis == 'semua' || t.jenis == _jenis) &&
          !day.isBefore(_from) &&
          !day.isAfter(_to);
    });
  }

  Future<void> _export(AppState state, bool isPdf) async {
    if (_busy) return;
    if (!_hasData) {
      showAppSnack(context, state.t('export_no_data'), isError: true);
      return;
    }
    setState(() => _busy = true);
    _showProgress(
      state.t(isPdf ? 'export_preparing_pdf' : 'export_preparing_excel'),
    );
    try {
      final file = isPdf
          ? await ExportService.exportPdf(
              profile: state.activeProfile ?? '',
              jenis: _jenis,
              from: _from,
              to: _to,
              transactions: state.transactions,
              debts: state.debts,
            )
          : await ExportService.exportCsv(
              profile: state.activeProfile ?? '',
              jenis: _jenis,
              from: _from,
              to: _to,
              transactions: state.transactions,
              debts: state.debts,
            );
      // Tutup dialog SEBELUM membuka share sheet, supaya sheet tidak
      // tertutup dialog.
      _hideProgress();
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: state.t(isPdf ? 'export_title_pdf' : 'export_title_excel'));
      if (mounted) {
        showAppSnack(
          context,
          state.t(isPdf ? 'export_pdf_ok' : 'export_excel_ok', {
            'type': _jenis,
          }),
        );
      }
    } catch (e) {
      _hideProgress();
      if (mounted) {
        showAppSnack(context, 'Gagal mengekspor: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupSheets(AppState state) async {
    if (_busy) return;
    setState(() => _busy = true);
    _showProgress(state.t('sheets_backup_preparing'));
    try {
      final payload = SheetsBackup.buildPayload(
        profile: state.activeProfile ?? '',
        profiles: state.profiles,
        transactions: state.transactions.map((t) => t.toMap()).toList(),
        bills: state.bills.map((b) => b.toMap()).toList(),
        debts: state.debts.map((d) => d.toMap()).toList(),
        logs: state.logs
            .map(
              (l) => {
                'id': l.id,
                'profile': l.profile,
                'waktu': l.waktu,
                'deskripsi': l.deskripsi,
              },
            )
            .toList(),
      );
      final result = await SheetsBackup.backup(payload);
      _hideProgress();
      if (!mounted) return;
      if (result.ok) {
        showAppSnack(context, state.t('sheets_backup_ok'));
      } else if (result.isNotConfigured) {
        showAppSnack(
          context,
          state.t('sheets_backup_not_configured'),
          isError: true,
        );
      } else {
        showAppSnack(
          context,
          state.t('sheets_backup_failed', {'reason': result.message}),
          isError: true,
        );
      }
    } finally {
      // Idempotent: menutup dialog bila masih terbuka (mis. backup throw).
      _hideProgress();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('export_title'),
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
              Text(
                state.t('export_type'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _jenis,
                    isExpanded: true,
                    items:
                        [
                              ('semua', state.t('all_label')),
                              ('pemasukan', state.t('income')),
                              ('pengeluaran', state.t('expense')),
                              ('utang', state.t('debt_label')),
                            ]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.$1,
                                child: Text(e.$2),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _jenis = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      context,
                      state.t('export_from'),
                      _from,
                      () => _pickDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateField(
                      context,
                      state.t('export_to'),
                      _to,
                      () => _pickDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: state.t('export_title_pdf'),
                onPressed: _busy ? null : () => _export(state, true),
                isLoading: _busy,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(state, false),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_chart_rounded),
                label: Text(state.t('export_title_excel')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                state.t('sheets_backup'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                state.t('sheets_backup_hint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _backupSheets(state),
                icon: const Icon(Icons.cloud_upload_rounded),
                label: Text(state.t('sheets_backup')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    BuildContext context,
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM yyyy', 'id_ID').format(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
