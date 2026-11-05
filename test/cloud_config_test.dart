import 'package:dasboardreport/sync/sheets_backup.dart';
import 'package:dasboardreport/sync/supabase_config.dart';
import 'package:dasboardreport/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudConfig', () {
    test('tanpa --dart-define, Supabase & Sheets tidak terkonfigurasi', () {
      // Test berjalan tanpa dart-define: aplikasi harus tetap jalan lokal.
      expect(CloudConfig.isSupabaseConfigured, isFalse);
      expect(CloudConfig.isSheetsConfigured, isFalse);
      expect(CloudConfig.supabaseUrl, isEmpty);
      expect(CloudConfig.supabaseAnonKey, isEmpty);
    });
  });

  group('SheetsBackup.buildPayload', () {
    test('payload berisi 5 tab sesuai Sheet Backup DasboardReport', () {
      final payload = SheetsBackup.buildPayload(
        profile: 'Dan',
        profiles: ['Dan', 'Usaha'],
        transactions: [
          {
            'id': 1,
            'profile': 'Dan',
            'tanggal': '2026-11-06',
            'jenis': 'pemasukan',
            'kategori': 'Gaji',
            'nominal': 5000000,
            'keterangan': 'Gaji',
          },
        ],
        bills: const [],
        debts: const [],
        logs: const [],
      );
      expect(payload['type'], 'backup');
      expect(payload['profile'], 'Dan');
      final tabs = payload['tabs'] as Map<String, dynamic>;
      expect(tabs.keys.toSet(), {
        'Profil',
        'Transaksi',
        'Tagihan',
        'Utang Piutang',
        'Log Aktivitas',
      });
      expect((tabs['Profil'] as List).length, 2);
      final trx = (tabs['Transaksi'] as List).first as Map<String, dynamic>;
      expect(trx['jumlah_rp'], 5000000);
      expect(trx['profil'], 'Dan');
      expect(trx.keys.toSet(), SheetsBackup.tabColumns['Transaksi']!.toSet());
    });

    test('mapDebt cicilan: total = nominal x tenor, sisa berkurang', () {
      final row = SheetsBackup.mapDebt({
        'id': 9,
        'profile': 'Dan',
        'jenis': 'utang',
        'partnerName': 'Budi',
        'tipeTempo': 'cicilan',
        'tenorBulan': 3,
        'cicilanKe': 2,
        'nominal': 100000,
        'status': 'belum',
      });
      expect(row['jumlah_total_rp'], 300000);
      expect(row['cicilan_rp'], 100000);
      expect(row['sisa_rp'], 200000); // cicilan ke-1 sudah dibayar
      expect(row['pihak'], 'Budi');
    });

    test('mapDebt tanpa tempo: total = nominal, sisa 0 bila sudah', () {
      final row = SheetsBackup.mapDebt({
        'id': 10,
        'profile': 'Dan',
        'jenis': 'piutang',
        'partnerName': 'Ani',
        'tipeTempo': 'tanpa_tempo',
        'nominal': 250000,
        'status': 'sudah',
      });
      expect(row['jumlah_total_rp'], 250000);
      expect(row['sisa_rp'], 0);
      expect(row['cicilan_rp'], '');
    });

    test('mapLog: aksi dari frasa sebelum titik dua', () {
      final row = SheetsBackup.mapLog({
        'id': 1,
        'profile': 'Dan',
        'waktu': '6 Nov 2026, 10.00',
        'deskripsi': 'Mencatat transaksi baru: Gaji',
      });
      expect(row['aksi'], 'Mencatat transaksi baru');
      expect(row['detail'], 'Mencatat transaksi baru: Gaji');
    });

    test(
      'backup tanpa URL mengembalikan notConfigured (tanpa kirim)',
      () async {
        final result = await SheetsBackup.backup({'type': 'backup'});
        expect(result.ok, isFalse);
        expect(result.isNotConfigured, isTrue);
      },
    );
  });

  group('SyncService', () {
    test('tanpa konfigurasi, init menjadi disabled (no-op)', () async {
      final service = SyncService.instance;
      await service.init();
      expect(service.status, SyncStatus.disabled);
      // syncNow no-op dan tidak melempar.
      await service.syncNow();
      expect(service.status, SyncStatus.disabled);
    });
  });
}
