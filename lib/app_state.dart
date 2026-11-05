import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'db.dart';
import 'format.dart';
import 'models.dart';
import 'prefs.dart';
import 'strings.dart';

/// State aplikasi — ChangeNotifier tunggal (provider).
/// Cerminan variabel global web: accounts, activeAccount, transaksi,
/// daftarTagihan, daftarPiutangSQL, currentLang, isPrivacyMode, idleTime.
class AppState extends ChangeNotifier {
  static const idleLockMinutes = 5; // sama seperti web: kunci setelah 5 mnt idle

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
  }

  Future<void> _loadProfileData() async {
    final p = activeProfile;
    if (p == null) return;
    final db = DatabaseHelper.instance;
    transactions = await db.getTransactions(p);
    bills = await db.getBills(p);
    debts = await db.getDebts(p);
    logs = await db.getLogs(p);
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
    if (DateTime.now().difference(_lastInteraction).inMinutes >= idleLockMinutes) {
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
    final waktu = DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(DateTime.now());
    await DatabaseHelper.instance
        .insertLog(ActivityLog(profile: p, waktu: waktu, deskripsi: deskripsi));
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
    }).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  Timer? _idleTimer;

  /// Mulai timer idle 1 menit (cek tiap menit, seperti web).
  void startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 1), (_) => checkIdleLock());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}
