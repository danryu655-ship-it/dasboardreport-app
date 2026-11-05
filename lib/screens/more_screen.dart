import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lock_screen.dart';
import 'profile_screen.dart';

/// Layar "Lainnya" (pengaturan) — cerminan modal #modalSettings di web.
/// v1: TIDAK ADA item Backup GSheet (scope: tanpa sinkronisasi server).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.t('more_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SettingsItem(
                icon: Icons.language_rounded,
                iconColor: AppColors.blue,
                label: state.t('settings_language'),
                trailing: Text(
                  state.lang.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purple,
                  ),
                ),
                onTap: () => state.toggleLang(),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.bug_report_rounded,
                iconColor: AppColors.danger,
                label: state.t('bug_report'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BugReportScreen()),
                ),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.new_releases_rounded,
                iconColor: AppColors.green,
                label: state.t('update_notes'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpdateNotesScreen()),
                ),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.history_rounded,
                iconColor: AppColors.purple,
                label: state.t('settings_activity_log'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
                ),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.lock_rounded,
                iconColor: AppColors.orange,
                label: state.t('settings_pin'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LockScreen(mode: 'set'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.group_rounded,
                iconColor: AppColors.blue,
                label: state.t('settings_profile'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                state.t('export_backup_title'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: AppColors.black,
                label: state.t('export_pdf'),
                onTap: () => showComingSoon(context, state),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.table_view_rounded,
                iconColor: AppColors.green,
                label: state.t('export_excel'),
                onTap: () => showComingSoon(context, state),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Text(
                      state.t('app_version'),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.t('app_tagline'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Log aktivitas — cerminan modal #modalLogAktivitas (maks 50 entri).
class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: Text(state.t('settings_activity_log'))),
      body: state.logs.isEmpty
          ? Center(
              child: Text(
                'Belum ada aktivitas tercatat.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: state.logs.length,
              itemBuilder: (_, i) {
                final log = state.logs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.deskripsi,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(log.waktu,
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Catatan update — konten statis seperti modal web (2.9.31 terbaru).
class UpdateNotesScreen extends StatelessWidget {
  const UpdateNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notes = [
      (
        'Version 2.9.31 (Terbaru)',
        [
          'Versi Android native (Flutter) — Dashboard, kunci PIN, manajemen profil, semua data tersimpan lokal di perangkat.',
        ],
      ),
      (
        'Version 2.9.30',
        [
          'Manajemen Profil & Profil Pill — Penambahan fitur pindah profil cepat dan pengaturan nama profil aktif.',
          'Mode Privasi (Sembunyikan Saldo) — Fitur tombol mata untuk menyembunyikan nominal saldo dari pandangan orang lain.',
        ],
      ),
      (
        'Version 2.8.x',
        [
          'Integrasi MySQL & Google Sheets — Dukungan backup data ganda secara online maupun lokal offline. (Tidak termasuk v1 Android — semua data lokal.)',
          'Scan Struk AI (Tesseract) — Otomatis membaca nominal, tanggal, dan merchant dari foto struk belanja. (Fase berikutnya.)',
        ],
      ),
    ];
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: Text(state.t('update_notes'))),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: notes.length,
        itemBuilder: (_, i) {
          final (version, items) = notes[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gray,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Text(version,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: AppColors.purple,
                                fontWeight: FontWeight.w800)),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3A3A3C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lapor bug — cerminan modal web: pilih fitur, tingkat keparahan, judul,
/// deskripsi, langkah reproduksi. Di v1 disimpan ke log aktivitas lokal
/// (web: hanya log + alert, tanpa server).
class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  static const features = [
    'Quick Record',
    'Transaksi',
    'Anggaran',
    'Kartu',
    'Dompet',
    'Kategori',
    'Utang',
    'Tagihan',
  ];
  static const severities = ['Rendah', 'Sedang', 'Tinggi', 'Kritis'];

  String _feature = 'Quick Record';
  String _severity = 'Sedang';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _stepsController = TextEditingController();

  Color _severityColor(String s) {
    switch (s) {
      case 'Rendah':
        return AppColors.green;
      case 'Sedang':
        return AppColors.orange;
      case 'Tinggi':
        return AppColors.blue;
      default:
        return AppColors.danger;
    }
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi wajib diisi.')),
      );
      return;
    }
    await state.addLog(
      'Mengirim Laporan Bug [$_feature - $_severity]: ${_titleController.text.trim()}',
    );
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text(
          'Terima kasih! Laporan bug Anda berhasil dikirim ke tim pengembang.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(state.t('close')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: Text(state.t('bug_report'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Aplikasi',
                          style: Theme.of(context).textTheme.bodySmall),
                      const Text('2.9.31',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Perangkat',
                          style: Theme.of(context).textTheme.bodySmall),
                      const Text('Android',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bahasa',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(state.lang.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Fitur yang bermasalah',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: _feature,
              items: features
                  .map((f) =>
                      DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _feature = v ?? _feature),
            ),
            const SizedBox(height: 12),
            Text('Tingkat Keparahan',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Row(
              children: severities.map((s) {
                final selected = s == _severity;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: s == severities.last ? 0 : 6),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      onSelected: (_) => setState(() => _severity = s),
                      selectedColor: _severityColor(s),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.black,
                      ),
                      showCheckmark: false,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text('Judul Bug', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                  hintText: 'Deskripsi singkat masalahnya'),
            ),
            const SizedBox(height: 12),
            Text('Deskripsi', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Apa yang terjadi? Apa yang seharusnya terjadi?'),
            ),
            const SizedBox(height: 12),
            Text('Langkah Reproduksi (Opsional)',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            TextField(
              controller: _stepsController,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: '1. Buka...\n2. Ketuk...\n3. Muncul error'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Kirim Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
