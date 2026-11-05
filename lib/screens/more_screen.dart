import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../sync/sync_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bills_screen.dart';
import 'bug_report_screen.dart';
import 'calendar_screen.dart';
import 'debts_screen.dart';
import 'export_screen.dart';
import 'lock_screen.dart';
import 'profile_screen.dart';
import 'wrapped_screen.dart';

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
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.orange,
                label: state.t('bills_title'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const BillsScreen())),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.handshake_rounded,
                iconColor: AppColors.green,
                label: state.t('debt_title'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.blue,
                label: state.t('calendar_title'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                ),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.auto_awesome_rounded,
                iconColor: AppColors.purple,
                label: state.t('wrap_title'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WrappedScreen()),
                ),
              ),
              const SizedBox(height: 8),
              // Status sinkronisasi cloud (Supabase) — offline-first.
              ListenableBuilder(
                listenable: state.sync,
                builder: (ctx, _) {
                  final sync = state.sync;
                  final statusText = switch (sync.status) {
                    SyncStatus.disabled => state.t('sync_disabled'),
                    SyncStatus.idle => state.t('sync_synced'),
                    SyncStatus.syncing => state.t('sync_syncing'),
                    SyncStatus.synced => state.t('sync_synced'),
                    SyncStatus.error => state.t('sync_error'),
                  };
                  final trailing = sync.pendingCount > 0
                      ? state.t('sync_pending', {
                          'n': sync.pendingCount.toString(),
                        })
                      : statusText;
                  return SettingsItem(
                    icon: Icons.cloud_rounded,
                    iconColor: AppColors.purple,
                    label: state.t('sync_title'),
                    trailing: Text(
                      trailing,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    onTap: () {
                      if (sync.status == SyncStatus.disabled) {
                        showAppSnack(
                          context,
                          state.t('sync_disabled'),
                          isError: true,
                        );
                      } else {
                        sync.syncNow();
                      }
                    },
                  );
                },
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
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ExportScreen())),
              ),
              const SizedBox(height: 8),
              SettingsItem(
                icon: Icons.table_view_rounded,
                iconColor: AppColors.green,
                label: state.t('export_excel'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ExportScreen())),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.deskripsi,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.waktu,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Text(
                    version,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: AppColors.purple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
