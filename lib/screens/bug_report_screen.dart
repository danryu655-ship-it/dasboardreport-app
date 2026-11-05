import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Laporan bug — web hanya mencatat log + alert (tanpa server).
/// Versi Flutter: laporan DISIMPAN LOKAL (tabel bug_reports, ikut sync
/// Supabase bila aktif) + draf laporan bisa disalin pengguna untuk dikirim
/// manual. Tidak ada pengiriman otomatis ke server.
class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  String _fitur = 'Dashboard';
  String _severity = 'Sedang';
  final _judulCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();
  final _langkahCtrl = TextEditingController();
  bool _saving = false;

  static const _fiturList = [
    'Dashboard',
    'Wallet',
    'Report',
    'Tagihan',
    'Utang-Piutang',
    'Kalender',
    'Ekspor',
    'Lainnya',
  ];
  static const _severityList = ['Rendah', 'Sedang', 'Tinggi', 'Kritis'];

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskripsiCtrl.dispose();
    _langkahCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    if (_saving) return;
    final judul = _judulCtrl.text.trim();
    final deskripsi = _deskripsiCtrl.text.trim();
    if (judul.isEmpty || deskripsi.isEmpty) {
      showAppSnack(context, state.t('required_field'), isError: true);
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    await state.addBugReport(
      BugReport(
        profile: state.activeProfile ?? '',
        fitur: _fitur,
        severity: _severity,
        judul: judul,
        deskripsi: deskripsi,
        langkah: _langkahCtrl.text.trim(),
        waktu: DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(now),
        createdAt: now.millisecondsSinceEpoch,
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _judulCtrl.clear();
      _deskripsiCtrl.clear();
      _langkahCtrl.clear();
    });
    showAppSnack(context, state.t('bug_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('bug_title'),
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
                state.t('bug_subtitle'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      label: state.t('bug_feature'),
                      value: _fitur,
                      items: _fiturList,
                      onChanged: (v) => setState(() => _fitur = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown(
                      label: state.t('bug_severity'),
                      value: _severity,
                      items: _severityList,
                      onChanged: (v) => setState(() => _severity = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _judulCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: state.t('bug_report_title'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deskripsiCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: state.t('bug_report_desc'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _langkahCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: state.t('bug_report_steps'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: state.t('bug_submit'),
                onPressed: _saving ? null : () => _submit(state),
                isLoading: _saving,
              ),
              const SizedBox(height: 24),
              Text(
                state.t('bug_history'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.bugReports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      state.t('bug_empty'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                ...state.bugReports.map((b) => _reportTile(context, state, b)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _reportTile(BuildContext context, AppState state, BugReport b) {
    final severityColor = switch (b.severity) {
      'Kritis' => AppColors.danger,
      'Tinggi' => AppColors.orange,
      'Sedang' => AppColors.blue,
      _ => AppColors.muted,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b.severity,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: severityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(b.fitur, style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text(b.waktu, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(b.judul, style: Theme.of(context).textTheme.titleSmall),
          Text(
            b.deskripsi,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: b.toShareText('2.9.31')),
                  );
                  if (context.mounted) {
                    showAppSnack(context, state.t('bug_copied'));
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(state.t('bug_copy')),
              ),
              const Spacer(),
              IconButton(
                onPressed: () async {
                  final ok = await showAppConfirm(
                    context,
                    title: state.t('delete'),
                    message: state.t('bug_delete_confirm'),
                    confirmLabel: state.t('delete'),
                    isDestructive: true,
                  );
                  if (ok == true) {
                    await state.deleteBugReport(b.id ?? 0);
                  }
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
