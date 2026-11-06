import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../services/import_service.dart';
import '../theme.dart';
import '../widgets.dart';

/// Layar Import Excel — menu baru di Lainnya > "Ekspor & Cadangan Data"
/// (tepat di bawah "Ekspor Excel", laporan user 2026-11-06):
/// 1. unduh TEMPLATE (kolom sama persis dengan Ekspor Excel),
/// 2. pilih file Excel (.xlsx) / CSV dari perangkat,
/// 3. validasi + pratinjau sebelum diimpor,
/// 4. impor ke database lokal (masuk antrean sync seperti data biasa).
/// Cakupan: transaksi + utang/piutang. Impor hanya MENAMBAH catatan baru
/// (id baru) — data yang sudah ada tidak pernah diubah atau dihapus.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? _fileName;
  ImportKind? _kind;
  List<AppTransaction> _validTrx = [];
  List<Debt> _validDebts = [];
  List<ImportRowError> _invalid = [];
  String? _fileError;
  bool _importing = false;
  bool _picked = false;

  Future<void> _downloadTemplate(AppState state, ImportKind kind) async {
    final isTrx = kind == ImportKind.transactions;
    final content = isTrx
        ? ImportService.transactionTemplateCsv()
        : ImportService.debtTemplateCsv();
    final dir = await getApplicationDocumentsDirectory();
    final name = isTrx
        ? 'template-transaksi-${toIsoDate(DateTime.now())}.csv'
        : 'template-utang-piutang-${toIsoDate(DateTime.now())}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: state.t('import_template_share'));
    if (mounted) {
      showAppSnack(context, state.t('import_template_ok'));
    }
  }

  Future<void> _pickFile(AppState state) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      setState(() {
        _picked = true;
        _fileName = picked.name;
        _fileError = state.t('import_file_error');
        _kind = null;
        _validTrx = [];
        _validDebts = [];
        _invalid = [];
      });
      return;
    }
    final rows = ImportService.parseFile(fileName: picked.name, bytes: bytes);
    if (rows == null || rows.isEmpty) {
      setState(() {
        _picked = true;
        _fileName = picked.name;
        _fileError = state.t('import_file_error');
        _kind = null;
        _validTrx = [];
        _validDebts = [];
        _invalid = [];
      });
      return;
    }
    final profile = state.activeProfile ?? '';
    final kind = ImportService.detectKind(rows.first);
    if (kind == ImportKind.transactions) {
      final parsed = ImportService.parseTransactions(rows, profile: profile);
      setState(() {
        _picked = true;
        _fileName = picked.name;
        _kind = parsed.kind;
        _fileError = parsed.fileError;
        _validTrx = parsed.valid;
        _validDebts = [];
        _invalid = parsed.invalid;
      });
    } else if (kind == ImportKind.debts) {
      final parsed = ImportService.parseDebts(rows, profile: profile);
      setState(() {
        _picked = true;
        _fileName = picked.name;
        _kind = parsed.kind;
        _fileError = parsed.fileError;
        _validTrx = [];
        _validDebts = parsed.valid;
        _invalid = parsed.invalid;
      });
    } else {
      setState(() {
        _picked = true;
        _fileName = picked.name;
        _kind = null;
        _fileError = state.t('import_unknown_format');
        _validTrx = [];
        _validDebts = [];
        _invalid = [];
      });
    }
  }

  Future<void> _doImport(AppState state) async {
    if (_importing) return;
    final count = _kind == ImportKind.transactions
        ? _validTrx.length
        : _validDebts.length;
    if (count == 0) return;
    setState(() => _importing = true);
    if (_kind == ImportKind.transactions) {
      await state.importTransactions(_validTrx);
    } else {
      await state.importDebts(_validDebts);
    }
    if (!mounted) return;
    setState(() => _importing = false);
    showAppSnack(context, state.t('import_success', {'n': '$count'}));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final validCount = _kind == ImportKind.transactions
        ? _validTrx.length
        : _validDebts.length;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('import_excel'),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.t('import_intro'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.t('import_existing_kept'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                state.t('import_template_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                state.t('import_template_desc'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _downloadTemplate(state, ImportKind.transactions),
                      icon: const Icon(Icons.table_view_rounded, size: 18),
                      label: Text(state.t('import_template_trx')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.green,
                        side: const BorderSide(color: AppColors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _downloadTemplate(state, ImportKind.debts),
                      icon: const Icon(Icons.handshake_rounded, size: 18),
                      label: Text(state.t('import_template_debt')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.orange,
                        side: const BorderSide(color: AppColors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                state.t('import_pick_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickFile(state),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(state.t('import_pick_file')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: const BorderSide(color: AppColors.purple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_picked) ...[
                const SizedBox(height: 20),
                Text(
                  state.t('import_preview_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _previewCard(state, validCount),
              ],
              if (_picked && _fileError == null && validCount > 0) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: state.t('import_do_import', {'n': '$validCount'}),
                  onPressed: _importing ? null : () => _doImport(state),
                  isLoading: _importing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard(AppState state, int validCount) {
    if (_fileError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _fileError!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fileName ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '${state.t('import_valid_rows')}: $validCount'
            '  •  ${state.t('import_invalid_rows')}: ${_invalid.length}',
            style: const TextStyle(fontSize: 13),
          ),
          if (validCount > 0) ...[
            const SizedBox(height: 10),
            ..._validPreviewLines(state).take(10),
            if (validCount > 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.t('import_showing', {
                    'n': '10',
                    'total': '$validCount',
                  }),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
          if (_invalid.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              state.t('import_invalid_rows'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 4),
            ..._invalid.take(10).map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  state.t('import_row_error', {
                    'n': '${e.rowNumber}',
                    'msg': e.message,
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
            if (_invalid.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.t('import_showing', {
                    'n': '10',
                    'total': '${_invalid.length}',
                  }),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
          if (validCount == 0 && _invalid.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.t('import_no_valid'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _validPreviewLines(AppState state) {
    if (_kind == ImportKind.transactions) {
      return _validTrx
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${formatTanggalPendek(parseIsoDate(t.tanggal))} • '
                '${t.keterangan} • ${t.jenis} • ${formatRupiah(t.nominal)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList();
    }
    return _validDebts
        .map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${formatTanggalPendek(parseIsoDate(d.tanggal))} • '
              '${d.partnerName} • ${d.jenis} • ${formatRupiah(d.nominal)}'
              '${d.isLunas ? ' • ${state.t('paid')}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )
        .toList();
  }
}
