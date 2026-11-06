import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'db.dart';
import 'format.dart';
import 'models.dart';
import 'prefs.dart';
import 'strings.dart';
import 'sync/sync_service.dart';

/// State aplikasi — ChangeNotifier tunggal (provider).
/// Cerminan variabel global web: accounts, activeAccount, transaksi,
/// daftarTagihan, daftarPiutangSQL, currentLang, isPrivacyMode, idleTime.
class AppState extends ChangeNotifier {
  static const idleLockMinutes =
      5; // sama seperti web: kunci setelah 5 mnt idle

  bool _initialized = false;
  bool get initialized => _initialized;

  List<String> profiles = [];
  String? activeProfile;
  String lang = 'id';

  /// Mode privasi (sesi saja, seperti variabel JS web — tidak disimpan).
  bool isPrivacyMode = false;

  /// Kunci PIN aktif (ditampilkan bila profil punya PIN dan belum diverifikasi).
  bool isLocked = false;

  List<AppTransaction> transactions = [];
  List<Bill> bills = [];
  List<Debt> debts = [];
  List<ActivityLog> logs = [];
  List<BugReport> bugReports = [];

  /// Layanan sync cloud (offline-first; no-op bila belum terkonfigurasi).
  SyncService get sync => SyncService.instance;

  DateTime _lastInteraction = DateTime.now();

  String t(String key, [Map<String, String>? params]) =>
      AppStrings.get(lang, key, params);

  /// Dipanggil di setiap interaksi pengguna (reset timer idle).
  void touch() => _lastInteraction = DateTime.now();

  Future<void> init() async {
    lang = await PrefsHelper.getLang();
    profiles = await DatabaseHelper.instance.getProfiles();
    activeProfile = await PrefsHelper.getActiveProfile();
    if (activeProfile != null && !profiles.contains(activeProfile)) {
      activeProfile = profiles.isEmpty ? null : profiles.first;
    }
    if (activeProfile != null) {
      await _loadProfileData();
      // Kunci saat buka bila profil punya PIN (cerminan cekPinSaatBukaAplikasi).
      final pin = await PrefsHelper.getPin(activeProfile!);
      isLocked = pin != null && pin.isNotEmpty;
    }
    _initialized = true;
    notifyListeners();
    // Sync cloud: fire-and-forget — tidak boleh menghambat buka aplikasi.
    // Bila belum terkonfigurasi, SyncService langsung disabled (no-op).
    unawaited(SyncService.instance.init());
  }

  Future<void> _loadProfileData() async {
    final p = activeProfile;
    if (p == null) return;
    final db = DatabaseHelper.instance;
    transactions = await db.getTransactions(p);
    bills = await db.getBills(p);
    debts = await db.getDebts(p);
    logs = await db.getLogs(p);
    bugReports = await db.getBugReports(p);
  }

  Future<void> reload() async {
    await _loadProfileData();
    notifyListeners();
  }

  // ---------- Profil ----------
  Future<void> createProfile(String name) async {
    final db = DatabaseHelper.instance;
    await db.insertProfile(name);
    profiles = await db.getProfiles();
    await switchProfile(name);
    await SyncService.instance.recordChange('profiles', 0, 'upsert', {
      'name': name,
    });
    await addLog(t('profile_created'));
  }

  Future<void> switchProfile(String name) async {
    activeProfile = name;
    await PrefsHelper.setActiveProfile(name);
    await _loadProfileData();
    final pin = await PrefsHelper.getPin(name);
    isLocked = pin != null && pin.isNotEmpty;
    touch();
    notifyListeners();
  }

  /// Ganti nama profil aktif (pindahkan semua data + PIN + log).
  Future<bool> renameActiveProfile(String newName) async {
    final old = activeProfile;
    if (old == null || newName.isEmpty) return false;
    if (profiles.contains(newName)) return false;
    await DatabaseHelper.instance.renameProfile(old, newName);
    await PrefsHelper.movePin(old, newName);
    profiles = await DatabaseHelper.instance.getProfiles();
    activeProfile = newName;
    await PrefsHelper.setActiveProfile(newName);
    await SyncService.instance.recordChange('profiles', 0, 'delete', {
      'name': old,
    });
    await SyncService.instance.recordChange('profiles', 0, 'upsert', {
      'name': newName,
    });
    await addLog(t('profile_renamed', {'old': old, 'name': newName}));
    await _loadProfileData();
    notifyListeners();
    return true;
  }

  // ---------- PIN ----------
  Future<bool> verifyPin(String pin) async {
    final p = activeProfile;
    if (p == null) return false;
    final saved = await PrefsHelper.getPin(p);
    if (saved != null && saved == pin) {
      isLocked = false;
      touch();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Mode 'set': PIN kosong = hapus PIN; 4 digit = simpan (cerminan web).
  Future<void> savePin(String pin) async {
    final p = activeProfile;
    if (p == null) return;
    if (pin.isEmpty) {
      await PrefsHelper.removePin(p);
      await addLog(t('pin_removed'));
    } else if (pin.length == 4) {
      await PrefsHelper.setPin(p, pin);
      await addLog(t('pin_saved'));
    }
    notifyListeners();
  }

  /// Reset darurat: ketik ulang nama profil (cerminan resetPinDarurat).
  Future<bool> emergencyResetPin(String typedName) async {
    final p = activeProfile;
    if (p == null) return false;
    if (typedName == p) {
      await PrefsHelper.removePin(p);
      isLocked = false;
      await addLog('PIN Keamanan di-reset darurat');
      await _loadProfileData();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> hasPin() async {
    final p = activeProfile;
    if (p == null) return false;
    final pin = await PrefsHelper.getPin(p);
    return pin != null && pin.isNotEmpty;
  }

  /// Kunci ulang bila idle >= 5 menit dan profil punya PIN.
  Future<void> checkIdleLock() async {
    final p = activeProfile;
    if (p == null || isLocked) return;
    if (DateTime.now().difference(_lastInteraction).inMinutes >=
        idleLockMinutes) {
      if (await hasPin()) {
        isLocked = true;
        notifyListeners();
      }
    }
  }

  void lockNow() {
    isLocked = true;
    notifyListeners();
  }

  // ---------- Bahasa & privasi ----------
  Future<void> toggleLang() async {
    lang = lang == 'id' ? 'en' : 'id';
    await PrefsHelper.setLang(lang);
    notifyListeners();
  }

  void togglePrivacy() {
    isPrivacyMode = !isPrivacyMode;
    notifyListeners();
  }

  // ---------- Log aktivitas ----------
  Future<void> addLog(String deskripsi) async {
    final p = activeProfile;
    if (p == null) return;
    final waktu = DateFormat(
      'd MMM yyyy, HH.mm',
      'id_ID',
    ).format(DateTime.now());
    await DatabaseHelper.instance.insertLog(
      ActivityLog(profile: p, waktu: waktu, deskripsi: deskripsi),
    );
    logs = await DatabaseHelper.instance.getLogs(p);
    notifyListeners();
  }

  // ---------- Hitungan dashboard (sama persis dengan web) ----------
  int get balance {
    var total = 0;
    for (final t in transactions) {
      total += t.isPemasukan ? t.nominal : -t.nominal;
    }
    return total;
  }

  int get monthIncome {
    final now = DateTime.now();
    var total = 0;
    for (final t in transactions) {
      final d = parseIsoDate(t.tanggal);
      if (t.isPemasukan && d.month == now.month && d.year == now.year) {
        total += t.nominal;
      }
    }
    return total;
  }

  int get monthExpense {
    final now = DateTime.now();
    var total = 0;
    for (final t in transactions) {
      final d = parseIsoDate(t.tanggal);
      if (!t.isPemasukan && d.month == now.month && d.year == now.year) {
        total += t.nominal;
      }
    }
    return total;
  }

  List<Bill> get unpaidBills => bills.where((b) => !b.isLunas).toList();

  /// Saldo bersih hutang/piutang (kartu oranye dashboard):
  /// total piutang belum lunas − total hutang belum lunas.
  int get netReceivable {
    var hutang = 0;
    var piutang = 0;
    for (final d in debts) {
      if (d.isLunas) continue;
      if (d.isPiutang) {
        piutang += d.nominal;
      } else {
        hutang += d.nominal;
      }
    }
    return piutang - hutang;
  }

  /// 5 transaksi terbaru (urut tanggal desc).
  List<AppTransaction> get recentTransactions {
    final sorted = List<AppTransaction>.from(transactions)
      ..sort((a, b) {
        final cmp = b.tanggal.compareTo(a.tanggal);
        return cmp != 0 ? cmp : b.id.compareTo(a.id);
      });
    return sorted.take(5).toList();
  }

  /// Transaksi bulan berjalan berdasarkan jenis (untuk sheet rincian kartu).
  List<AppTransaction> monthTransactions(String jenis) {
    final now = DateTime.now();
    return transactions.where((t) {
      final d = parseIsoDate(t.tanggal);
      return t.jenis == jenis && d.month == now.month && d.year == now.year;
    }).toList()..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  // ---------- Transaksi (fase 2) ----------
  Future<void> addTransaction(AppTransaction trx) async {
    await DatabaseHelper.instance.insertTransaction(trx);
    await SyncService.instance.recordChange(
      'transactions',
      trx.id,
      'upsert',
      trx.toMap(),
    );
    await addLog(t('trx_log_added', {'name': trx.keterangan}));
    await _loadProfileData();
    notifyListeners();
  }

  Future<void> updateTransaction(AppTransaction trx) async {
    await DatabaseHelper.instance.updateTransaction(trx);
    await SyncService.instance.recordChange(
      'transactions',
      trx.id,
      'upsert',
      trx.toMap(),
    );
    await addLog(t('trx_log_updated', {'name': trx.keterangan}));
    await _loadProfileData();
    notifyListeners();
  }

  Future<void> deleteTransaction(int id) async {
    final trx = transactions.where((t) => t.id == id).firstOrNull;
    await DatabaseHelper.instance.deleteTransaction(id);
    await SyncService.instance.recordChange('transactions', id, 'delete', {
      'id': id,
    });
    if (trx != null) {
      await addLog(t('trx_log_deleted', {'name': trx.keterangan}));
    }
    await _loadProfileData();
    notifyListeners();
  }

  // ---------- Tagihan (fase 2) ----------
  Future<void> addBill(Bill bill) async {
    await DatabaseHelper.instance.insertBill(bill);
    await SyncService.instance.recordChange(
      'bills',
      bill.id,
      'upsert',
      bill.toMap(),
    );
    await addLog(t('bill_log_added', {'name': bill.nama}));
    await _loadProfileData();
    notifyListeners();
  }

  Future<void> deleteBill(int id) async {
    final bill = bills.where((b) => b.id == id).firstOrNull;
    await DatabaseHelper.instance.deleteBill(id);
    await SyncService.instance.recordChange('bills', id, 'delete', {'id': id});
    if (bill != null) {
      await addLog(t('bill_log_deleted', {'name': bill.nama}));
    }
    await _loadProfileData();
    notifyListeners();
  }

  /// Bayar tagihan — cerminan tandaiSelesaiTagihan() di web: buat transaksi
  /// pengeluaran otomatis "Bayar Tagihan: [nama]" (Tagihan Bulanan, Cash,
  /// tanggal hari ini) lalu tandai tagihan sudah.
  Future<void> payBill(int id) async {
    final bill = bills.where((b) => b.id == id).firstOrNull;
    if (bill == null || bill.isLunas) return;
    final auto = AppTransaction(
      id: DateTime.now().millisecondsSinceEpoch,
      profile: bill.profile,
      jenis: 'pengeluaran',
      tanggal: toIsoDate(DateTime.now()),
      kategori: 'Tagihan Bulanan',
      metodePembayaran: 'Cash',
      keterangan: 'Bayar Tagihan: ${bill.nama}',
      nominal: bill.nominal,
    );
    await DatabaseHelper.instance.insertTransaction(auto);
    await SyncService.instance.recordChange(
      'transactions',
      auto.id,
      'upsert',
      auto.toMap(),
    );
    final paid = Bill(
      id: bill.id,
      profile: bill.profile,
      nama: bill.nama,
      nominal: bill.nominal,
      tanggal: bill.tanggal,
      status: 'sudah',
    );
    await DatabaseHelper.instance.updateBill(paid);
    await SyncService.instance.recordChange(
      'bills',
      paid.id,
      'upsert',
      paid.toMap(),
    );
    await addLog(t('bill_log_settled', {'name': bill.nama}));
    await _loadProfileData();
    notifyListeners();
  }

  // ---------- Utang / piutang (fase 2) ----------
  Future<void> addDebt(Debt debt) async {
    await DatabaseHelper.instance.insertDebt(debt);
    await SyncService.instance.recordChange(
      'debts',
      debt.id,
      'upsert',
      debt.toMap(),
    );
    await addLog(t('debt_log_added', {'name': debt.partnerName}));
    await _loadProfileData();
    notifyListeners();
  }

  Future<void> deleteDebt(int id) async {
    final debt = debts.where((d) => d.id == id).firstOrNull;
    await DatabaseHelper.instance.deleteDebt(id);
    await SyncService.instance.recordChange('debts', id, 'delete', {'id': id});
    if (debt != null) {
      await addLog(
        t('debt_log_deleted', {'jenis': debt.jenis, 'name': debt.partnerName}),
      );
    }
    await _loadProfileData();
    notifyListeners();
  }

  /// Satu seri utang/piutang cicilan — keputusan user 2026-11-06
  /// ("hapus satu seri sekaligus").
  ///
  /// Identitas seri BUKAN syncCode: baik web maupun aplikasi selama ini
  /// memberi kode BARU di tiap cicilan (web: `sync_code` baru saat buat
  /// cicilan berikutnya; aplikasi: `createNextInstallment` memanggil
  /// `_newSyncCode()`), dan baris pertama dari form punya syncCode '' —
  /// jadi pengelompokan berdasarkan kode tidak pernah menyatukan satu
  /// seri. Yang benar-benar sama di semua cicilan satu seri adalah
  /// identitas pinjaman: profil, pihak, jenis, tenor, nominal,
  /// keterangan, dan tipeTempo 'cicilan'. Baris tanpa tempo selalu
  /// seri berisi dirinya sendiri.
  ///
  /// Batasan yang disengaja: dua pinjaman cicilan yang identik persis
  /// (orang, jenis, tenor, nominal, dan keterangan sama) dianggap satu
  /// seri — dialog konfirmasi menampilkan jumlah baris + total nominal
  /// sebagai pengaman terakhir sebelum hapus.
  static List<Debt> seriesOf(List<Debt> all, Debt target) {
    if (target.tipeTempo != 'cicilan') return [target];
    return all
        .where(
          (d) =>
              d.tipeTempo == 'cicilan' &&
              d.profile == target.profile &&
              d.partnerName == target.partnerName &&
              d.jenis == target.jenis &&
              d.tenorBulan == target.tenorBulan &&
              d.nominal == target.nominal &&
              d.keterangan == target.keterangan,
        )
        .toList();
  }

  /// Seri dari satu baris (dalam daftar profil aktif).
  List<Debt> debtSeriesOf(Debt debt) => seriesOf(debts, debt);

  /// Hapus SATU SERI sekaligus: semua baris seri (aktif + sudah lunas)
  /// dihapus lokal, dan tiap baris masuk antrean sync sebagai 'delete'
  /// sehingga masing-masing mendapat tombstone sendiri di `sync_deletes`
  /// saat push (tidak ada baris seri yang tertinggal di server).
  /// Mengembalikan jumlah baris yang dihapus (0 bila id tidak ditemukan).
  Future<int> deleteDebtSeries(int id) async {
    final target = debts.where((d) => d.id == id).firstOrNull;
    if (target == null) return 0;
    final series = debtSeriesOf(target);
    for (final d in series) {
      await DatabaseHelper.instance.deleteDebt(d.id);
      await SyncService.instance.recordChange('debts', d.id, 'delete', {
        'id': d.id,
      });
    }
    await addLog(
      t('debt_log_deleted_series', {
        'jenis': target.jenis,
        'name': target.partnerName,
        'n': '${series.length}',
      }),
    );
    await _loadProfileData();
    notifyListeners();
    return series.length;
  }

  // ---------- Impor Excel (laporan user 2026-11-06) ----------
  /// Impor batch dari file Excel/CSV: setiap baris draft (id 0 dari parser)
  /// mendapat id BARU — file ekspor tidak membawa id, dan id baru tidak
  /// pernah menabrak id yang sudah ada. Tiap baris masuk antrean sync
  /// seperti data biasa (upsert). Mengembalikan jumlah baris yang diimpor.
  Future<int> importTransactions(List<AppTransaction> drafts) async {
    if (drafts.isEmpty) return 0;
    var nextId = _nextFreshId(transactions.map((t) => t.id));
    var count = 0;
    for (final d in drafts) {
      final row = AppTransaction(
        id: nextId++,
        profile: activeProfile ?? '',
        jenis: d.jenis,
        tanggal: d.tanggal,
        kategori: d.kategori,
        metodePembayaran: d.metodePembayaran,
        keterangan: d.keterangan,
        nominal: d.nominal,
      );
      await DatabaseHelper.instance.insertTransaction(row);
      await SyncService.instance.recordChange(
        'transactions',
        row.id,
        'upsert',
        row.toMap(),
      );
      count++;
    }
    await addLog(t('import_log_trx', {'n': '$count'}));
    await _loadProfileData();
    notifyListeners();
    return count;
  }

  Future<int> importDebts(List<Debt> drafts) async {
    if (drafts.isEmpty) return 0;
    var nextId = _nextFreshId(debts.map((d) => d.id));
    var count = 0;
    for (final d in drafts) {
      final row = Debt(
        id: nextId++,
        profile: activeProfile ?? '',
        creatorName: activeProfile ?? '',
        partnerName: d.partnerName,
        jenis: d.jenis,
        tipeTempo: 'tanpa_tempo',
        tenorBulan: null,
        cicilanKe: null,
        tanggal: d.tanggal,
        nominal: d.nominal,
        keterangan: d.keterangan,
        status: d.status,
        syncCode: '',
      );
      await DatabaseHelper.instance.insertDebt(row);
      await SyncService.instance.recordChange(
        'debts',
        row.id,
        'upsert',
        row.toMap(),
      );
      count++;
    }
    await addLog(t('import_log_debt', {'n': '$count'}));
    await _loadProfileData();
    notifyListeners();
    return count;
  }

  /// Id segar untuk impor batch: lebih besar dari "sekarang" dan dari semua
  /// id yang sudah ada, supaya tidak pernah menabrak baris lama.
  int _nextFreshId(Iterable<int> existing) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxId = existing.isEmpty
        ? 0
        : existing.reduce((a, b) => a > b ? a : b);
    return now > maxId ? now : maxId + 1;
  }

  /// Selesaikan utang/piutang — cerminan tandaiSelesaiPiutang() di web:
  /// buat transaksi otomatis (piutang menjadi pemasukan "Pelunasan Piutang",
  /// utang menjadi pengeluaran "Pelunasan Hutang", kategori Lainnya, Cash,
  /// tanggal hari ini) lalu tandai sudah.
  /// Mengembalikan true bila cicilan berikutnya BISA dibuat
  /// (cicilan ke saat ini masih di bawah tenor) — UI menanyakan ke pengguna.
  Future<bool> settleDebt(int id) async {
    final debt = debts.where((d) => d.id == id).firstOrNull;
    if (debt == null || debt.isLunas) return false;
    final auto = AppTransaction(
      id: DateTime.now().millisecondsSinceEpoch,
      profile: debt.profile,
      jenis: debt.isPiutang ? 'pemasukan' : 'pengeluaran',
      tanggal: toIsoDate(DateTime.now()),
      kategori: 'Lainnya',
      metodePembayaran: 'Cash',
      keterangan: debt.isPiutang
          ? 'Pelunasan Piutang: ${debt.partnerName}'
          : 'Pelunasan Hutang: ${debt.partnerName}',
      nominal: debt.nominal,
    );
    await DatabaseHelper.instance.insertTransaction(auto);
    await SyncService.instance.recordChange(
      'transactions',
      auto.id,
      'upsert',
      auto.toMap(),
    );
    final done = Debt(
      id: debt.id,
      profile: debt.profile,
      creatorName: debt.creatorName,
      partnerName: debt.partnerName,
      jenis: debt.jenis,
      tipeTempo: debt.tipeTempo,
      tenorBulan: debt.tenorBulan,
      cicilanKe: debt.cicilanKe,
      tanggal: debt.tanggal,
      nominal: debt.nominal,
      keterangan: debt.keterangan,
      status: 'sudah',
      syncCode: debt.syncCode,
      buktiPath: debt.buktiPath,
    );
    await DatabaseHelper.instance.updateDebt(done);
    await SyncService.instance.recordChange(
      'debts',
      done.id,
      'upsert',
      done.toMap(),
    );
    await addLog(
      t('debt_log_settled', {'jenis': debt.jenis, 'name': debt.partnerName}),
    );
    await _loadProfileData();
    notifyListeners();
    return debt.tipeTempo == 'cicilan' &&
        (debt.cicilanKe ?? 0) < (debt.tenorBulan ?? 0);
  }

  /// Buat cicilan berikutnya otomatis (tanggal +1 bulan, cicilan_ke+1,
  /// kode seri diwarisi dari induk) — cerminan web saat pengguna
  /// menjawab "Ya". Sejak 2026-11-06 cicilan baru MEWARISI syncCode induk
  /// (bukan kode baru) supaya satu seri punya satu kode; bila induk
  /// belum punya kode, satu kode baru dibuat dan diisi ke induk juga.
  Future<void> createNextInstallment(int settledId) async {
    final debt = debts.where((d) => d.id == settledId).firstOrNull;
    if (debt == null) return;
    if (debt.tipeTempo != 'cicilan') return;
    final nextKe = (debt.cicilanKe ?? 0) + 1;
    if (nextKe > (debt.tenorBulan ?? 0)) return;
    final nextDate = parseIsoDate(debt.tanggal);
    final due = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
    var seriesCode = debt.syncCode;
    if (seriesCode.isEmpty) {
      seriesCode = _newSyncCode();
      final healed = Debt(
        id: debt.id,
        profile: debt.profile,
        creatorName: debt.creatorName,
        partnerName: debt.partnerName,
        jenis: debt.jenis,
        tipeTempo: debt.tipeTempo,
        tenorBulan: debt.tenorBulan,
        cicilanKe: debt.cicilanKe,
        tanggal: debt.tanggal,
        nominal: debt.nominal,
        keterangan: debt.keterangan,
        status: debt.status,
        syncCode: seriesCode,
        buktiPath: debt.buktiPath,
      );
      await DatabaseHelper.instance.updateDebt(healed);
      await SyncService.instance.recordChange(
        'debts',
        healed.id,
        'upsert',
        healed.toMap(),
      );
    }
    final next = Debt(
      id: DateTime.now().millisecondsSinceEpoch + 1,
      profile: debt.profile,
      creatorName: debt.creatorName,
      partnerName: debt.partnerName,
      jenis: debt.jenis,
      tipeTempo: 'cicilan',
      tenorBulan: debt.tenorBulan,
      cicilanKe: nextKe,
      tanggal: toIsoDate(due),
      nominal: debt.nominal,
      keterangan: debt.keterangan,
      status: 'belum',
      syncCode: seriesCode,
      buktiPath: debt.buktiPath,
    );
    await DatabaseHelper.instance.insertDebt(next);
    await SyncService.instance.recordChange(
      'debts',
      next.id,
      'upsert',
      next.toMap(),
    );
    await addLog(t('debt_log_added', {'name': debt.partnerName}));
    await _loadProfileData();
    notifyListeners();
  }

  /// Kode sinkronisasi UTG-XXXXXX (cerminan generateSyncCode() di web;
  /// di v1/v2 disimpan lokal saja, tanpa sinkronisasi server).
  String _newSyncCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    var seed = now;
    final buf = StringBuffer('UTG-');
    for (var i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  // ---------- Laporan bug (fase 2, tersimpan lokal) ----------
  Future<void> addBugReport(BugReport report) async {
    final id = await DatabaseHelper.instance.insertBugReport(report);
    final saved = BugReport(
      id: id,
      profile: report.profile,
      fitur: report.fitur,
      severity: report.severity,
      judul: report.judul,
      deskripsi: report.deskripsi,
      langkah: report.langkah,
      waktu: report.waktu,
      createdAt: report.createdAt,
    );
    await SyncService.instance.recordChange(
      'bug_reports',
      id,
      'upsert',
      saved.toMap(),
    );
    await addLog(
      'Mengirim Laporan Bug [${report.fitur} - ${report.severity}]: ${report.judul}',
    );
    await _loadProfileData();
    notifyListeners();
  }

  Future<void> deleteBugReport(int id) async {
    await DatabaseHelper.instance.deleteBugReport(id);
    await SyncService.instance.recordChange('bug_reports', id, 'delete', {
      'id': id,
    });
    await _loadProfileData();
    notifyListeners();
  }

  // ---------- Helper Wallet (fase 2) ----------
  /// Transaksi bulan tertentu (urut tanggal desc) — untuk Wallet.
  List<AppTransaction> transactionsForMonth(int year, int month) {
    return transactions.where((t) {
      final d = parseIsoDate(t.tanggal);
      return d.year == year && d.month == month;
    }).toList()..sort((a, b) {
      final cmp = b.tanggal.compareTo(a.tanggal);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });
  }

  /// Total pengeluaran harian dalam sebulan (untuk grafik garis Wallet).
  Map<int, int> dailyExpense(int year, int month) {
    final map = <int, int>{};
    for (final t in transactions) {
      final d = parseIsoDate(t.tanggal);
      if (!t.isPemasukan && d.year == year && d.month == month) {
        map[d.day] = (map[d.day] ?? 0) + t.nominal;
      }
    }
    return map;
  }

  /// Transaksi Wallet dengan filter pencarian / rentang tanggal / jenis.
  /// jenis: 'semua' | 'pemasukan' | 'pengeluaran' (piutang ditangani terpisah).
  List<AppTransaction> walletTransactions({
    String search = '',
    String? from,
    String? to,
    String jenis = 'semua',
  }) {
    final q = search.trim().toLowerCase();
    return transactions.where((t) {
      if (jenis != 'semua' && t.jenis != jenis) return false;
      if (from != null && from.isNotEmpty && t.tanggal.compareTo(from) < 0) {
        return false;
      }
      if (to != null && to.isNotEmpty && t.tanggal.compareTo(to) > 0) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.keterangan.toLowerCase().contains(q) ||
          t.kategori.toLowerCase().contains(q);
    }).toList()..sort((a, b) {
      final cmp = b.tanggal.compareTo(a.tanggal);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });
  }

  /// Utang/piutang untuk filter Wallet: 'semua' hanya yang belum lunas,
  /// 'piutang' menampilkan semua (cerminan renderSemuaTransaksi di web).
  List<Debt> walletDebts({
    String search = '',
    String? from,
    String? to,
    String jenis = 'semua',
  }) {
    final q = search.trim().toLowerCase();
    return debts.where((d) {
      if (jenis == 'semua' && d.isLunas) return false;
      if (from != null && from.isNotEmpty && d.tanggal.compareTo(from) < 0) {
        return false;
      }
      if (to != null && to.isNotEmpty && d.tanggal.compareTo(to) > 0) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.partnerName.toLowerCase().contains(q) ||
          d.keterangan.toLowerCase().contains(q) ||
          d.jenis.toLowerCase().contains(q);
    }).toList()..sort((a, b) {
      final cmp = b.tanggal.compareTo(a.tanggal);
      return cmp != 0 ? cmp : b.id.compareTo(a.id);
    });
  }

  // ---------- Helper Report (fase 2) ----------
  /// Periode (YYYY-MM) yang punya pengeluaran, terbaru dulu.
  List<String> get expensePeriods {
    final set = <String>{};
    for (final t in transactions) {
      if (t.isPemasukan) continue;
      final d = parseIsoDate(t.tanggal);
      set.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Kategori pengeluaran yang ada.
  List<String> get expenseCategories {
    final set = <String>{};
    for (final t in transactions) {
      if (!t.isPemasukan) set.add(t.kategori);
    }
    return set.toList()..sort();
  }

  /// Transaksi pengeluaran terfilter periode + kategori (urut tanggal desc).
  List<AppTransaction> reportTransactions({
    String periode = 'semua',
    String kategori = 'semua',
  }) {
    return transactions.where((t) {
      if (t.isPemasukan) return false;
      if (kategori != 'semua' && t.kategori != kategori) return false;
      if (periode != 'semua') {
        final d = parseIsoDate(t.tanggal);
        final p = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        if (p != periode) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  /// Agregasi untuk donut: bila kategori 'semua' → per kategori;
  /// bila satu kategori dipilih → per keterangan (cerminan renderLaporan).
  Map<String, int> reportAggregation({
    String periode = 'semua',
    String kategori = 'semua',
  }) {
    final map = <String, int>{};
    for (final t in reportTransactions(periode: periode, kategori: kategori)) {
      final key = kategori == 'semua' ? t.kategori : t.keterangan;
      map[key] = (map[key] ?? 0) + t.nominal;
    }
    return map;
  }

  Timer? _idleTimer;

  /// Mulai timer idle 1 menit (cek tiap menit, seperti web).
  void startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkIdleLock(),
    );
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}
