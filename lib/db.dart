import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Lapisan SQLite — cerminan localStorage web app (per profil).
/// v1: 100% lokal, tanpa panggilan network apa pun.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'dasboardreport.db';
  static const _dbVersion = 3; // v3 (fase 2): + tabel bug_reports & sync_queue

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createV1(db);
        await _createBugReports(db);
        await _createSyncQueue(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2: tambah tabel bug_reports (tanpa mengubah data lama).
        if (oldVersion < 2) {
          await _createBugReports(db);
        }
        // v2 → v3: tambah tabel antrean sync Supabase.
        if (oldVersion < 3) {
          await _createSyncQueue(db);
        }
      },
    );
  }

  /// Antrean perubahan lokal yang menunggu di-push ke Supabase.
  /// Setiap mutasi lokal (insert/update/delete) dicatat di sini agar tidak
  /// ada data yang hilang saat offline; SyncService menguras antrean ini
  /// saat online dan Supabase terkonfigurasi.
  Future<void> _createSyncQueue(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT NOT NULL,
        rowId INTEGER NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue ON sync_queue(id)',
    );
  }

  Future<void> _createBugReports(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bug_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile TEXT NOT NULL,
        fitur TEXT NOT NULL,
        severity TEXT NOT NULL,
        judul TEXT NOT NULL,
        deskripsi TEXT NOT NULL,
        langkah TEXT NOT NULL DEFAULT '',
        waktu TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bugs_profile ON bug_reports(profile, id)',
    );
  }

  Future<void> _createV1(DatabaseExecutor db) async {
    await db.execute('''
          CREATE TABLE profiles (
            name TEXT PRIMARY KEY
          )
        ''');
    await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY,
            profile TEXT NOT NULL,
            jenis TEXT NOT NULL,
            tanggal TEXT NOT NULL,
            kategori TEXT NOT NULL,
            investasiSub TEXT NOT NULL DEFAULT '',
            cryptoToken TEXT NOT NULL DEFAULT '',
            metodePembayaran TEXT NOT NULL DEFAULT 'Cash',
            detailBank TEXT NOT NULL DEFAULT '',
            tujuanBank TEXT NOT NULL DEFAULT '',
            keterangan TEXT NOT NULL,
            nominal INTEGER NOT NULL,
            buktiPath TEXT NOT NULL DEFAULT ''
          )
        ''');
    await db.execute('''
          CREATE TABLE bills (
            id INTEGER PRIMARY KEY,
            profile TEXT NOT NULL,
            nama TEXT NOT NULL,
            nominal INTEGER NOT NULL,
            tanggal TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'belum'
          )
        ''');
    await db.execute('''
          CREATE TABLE debts (
            id INTEGER PRIMARY KEY,
            profile TEXT NOT NULL,
            creatorName TEXT NOT NULL DEFAULT '',
            partnerName TEXT NOT NULL,
            jenis TEXT NOT NULL,
            tipeTempo TEXT NOT NULL DEFAULT 'tanpa_tempo',
            tenorBulan INTEGER,
            cicilanKe INTEGER,
            tanggal TEXT NOT NULL,
            nominal INTEGER NOT NULL,
            keterangan TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'belum',
            syncCode TEXT NOT NULL DEFAULT '',
            buktiPath TEXT NOT NULL DEFAULT ''
          )
        ''');
    await db.execute('''
          CREATE TABLE activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profile TEXT NOT NULL,
            waktu TEXT NOT NULL,
            deskripsi TEXT NOT NULL
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_trx_profile ON transactions(profile, tanggal)',
    );
    await db.execute('CREATE INDEX idx_bills_profile ON bills(profile)');
    await db.execute('CREATE INDEX idx_debts_profile ON debts(profile)');
    await db.execute(
      'CREATE INDEX idx_logs_profile ON activity_logs(profile, id)',
    );
  }

  // ---------- Profiles ----------
  Future<List<String>> getProfiles() async {
    final db = await database;
    final rows = await db.query('profiles', orderBy: 'rowid ASC');
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<void> insertProfile(String name) async {
    final db = await database;
    await db.insert('profiles', {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Ganti nama profil: pindahkan semua baris data profil lama ke nama baru.
  /// (Cerminan simpanEditNamaProfil() di web.)
  Future<void> renameProfile(String oldName, String newName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'profiles',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      for (final table in [
        'transactions',
        'bills',
        'debts',
        'activity_logs',
        'bug_reports',
      ]) {
        await txn.update(
          table,
          {'profile': newName},
          where: 'profile = ?',
          whereArgs: [oldName],
        );
      }
    });
  }

  // ---------- Transactions ----------
  Future<List<AppTransaction>> getTransactions(String profile) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'profile = ?',
      whereArgs: [profile],
      orderBy: 'tanggal DESC, id DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<void> insertTransaction(AppTransaction t) async {
    final db = await database;
    await db.insert(
      'transactions',
      t.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(AppTransaction t) async {
    final db = await database;
    await db.update(
      'transactions',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Bills ----------
  Future<List<Bill>> getBills(String profile) async {
    final db = await database;
    final rows = await db.query(
      'bills',
      where: 'profile = ?',
      whereArgs: [profile],
      orderBy: 'tanggal ASC, id ASC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  Future<void> insertBill(Bill b) async {
    final db = await database;
    await db.insert(
      'bills',
      b.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBill(Bill b) async {
    final db = await database;
    await db.update('bills', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> deleteBill(int id) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Debts ----------
  Future<List<Debt>> getDebts(String profile) async {
    final db = await database;
    final rows = await db.query(
      'debts',
      where: 'profile = ?',
      whereArgs: [profile],
      orderBy: 'tanggal ASC, id ASC',
    );
    return rows.map(Debt.fromMap).toList();
  }

  Future<void> insertDebt(Debt d) async {
    final db = await database;
    await db.insert(
      'debts',
      d.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDebt(Debt d) async {
    final db = await database;
    await db.update('debts', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteDebt(int id) async {
    final db = await database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Activity logs (maks 50 per profil, seperti web) ----------
  Future<List<ActivityLog>> getLogs(String profile) async {
    final db = await database;
    final rows = await db.query(
      'activity_logs',
      where: 'profile = ?',
      whereArgs: [profile],
      orderBy: 'id DESC',
      limit: 50,
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<void> insertLog(ActivityLog log) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('activity_logs', log.toMap());
      // Jaga maks 50 entri: hapus yang paling lama.
      await txn.rawDelete(
        'DELETE FROM activity_logs WHERE profile = ? AND id NOT IN '
        '(SELECT id FROM activity_logs WHERE profile = ? ORDER BY id DESC LIMIT 50)',
        [log.profile, log.profile],
      );
    });
  }

  // ---------- Bug reports (tersimpan lokal, tanpa server) ----------
  Future<List<BugReport>> getBugReports(String profile) async {
    final db = await database;
    final rows = await db.query(
      'bug_reports',
      where: 'profile = ?',
      whereArgs: [profile],
      orderBy: 'id DESC',
    );
    return rows.map(BugReport.fromMap).toList();
  }

  Future<int> insertBugReport(BugReport b) async {
    final db = await database;
    return db.insert('bug_reports', b.toMap());
  }

  Future<void> deleteBugReport(int id) async {
    final db = await database;
    await db.delete('bug_reports', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Antrean sync Supabase ----------
  Future<void> enqueueSync(
    String tableName,
    int rowId,
    String operation,
    String payload,
  ) async {
    final db = await database;
    await db.insert('sync_queue', {
      'tableName': tableName,
      'rowId': rowId,
      'operation': operation,
      'payload': payload,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue({int limit = 200}) async {
    final db = await database;
    return db.query('sync_queue', orderBy: 'id ASC', limit: limit);
  }

  Future<void> deleteSyncEntries(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawDelete(
      'DELETE FROM sync_queue WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> syncQueueCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
    return (rows.first['c'] as int?) ?? 0;
  }
}
