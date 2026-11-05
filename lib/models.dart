/// Model data — mencerminkan struktur JSON localStorage web app.
/// Nama field dipertahankan sedekat mungkin dengan web agar mudah dipetakan.
class AppTransaction {
  final int id; // ms epoch (Date.now() di web)
  final String profile;
  final String jenis; // 'pemasukan' | 'pengeluaran'
  final String tanggal; // YYYY-MM-DD
  final String kategori;
  final String investasiSub; // '' bila bukan Investasi
  final String cryptoToken; // '' bila bukan Crypto
  final String
  metodePembayaran; // Cash / Transfer Bank / QR / Credit Card / Paylater
  final String detailBank; // bank asal / sumber
  final String tujuanBank; // bank tujuan (pengeluaran + Transfer Bank)
  final String keterangan; // merchant / catatan
  final int nominal; // Rupiah
  final String buktiPath; // path file bukti lokal (fase 2); '' bila tidak ada

  const AppTransaction({
    required this.id,
    required this.profile,
    required this.jenis,
    required this.tanggal,
    required this.kategori,
    this.investasiSub = '',
    this.cryptoToken = '',
    this.metodePembayaran = 'Cash',
    this.detailBank = '',
    this.tujuanBank = '',
    required this.keterangan,
    required this.nominal,
    this.buktiPath = '',
  });

  bool get isPemasukan => jenis == 'pemasukan';

  Map<String, dynamic> toMap() => {
    'id': id,
    'profile': profile,
    'jenis': jenis,
    'tanggal': tanggal,
    'kategori': kategori,
    'investasiSub': investasiSub,
    'cryptoToken': cryptoToken,
    'metodePembayaran': metodePembayaran,
    'detailBank': detailBank,
    'tujuanBank': tujuanBank,
    'keterangan': keterangan,
    'nominal': nominal,
    'buktiPath': buktiPath,
  };

  factory AppTransaction.fromMap(Map<String, dynamic> m) => AppTransaction(
    id: m['id'] as int,
    profile: m['profile'] as String? ?? '',
    jenis: m['jenis'] as String,
    tanggal: m['tanggal'] as String,
    kategori: m['kategori'] as String,
    investasiSub: m['investasiSub'] as String? ?? '',
    cryptoToken: m['cryptoToken'] as String? ?? '',
    metodePembayaran: m['metodePembayaran'] as String? ?? 'Cash',
    detailBank: m['detailBank'] as String? ?? '',
    tujuanBank: m['tujuanBank'] as String? ?? '',
    keterangan: m['keterangan'] as String,
    nominal: (m['nominal'] as num).toInt(),
    buktiPath: m['buktiPath'] as String? ?? '',
  );
}

class Bill {
  final int id;
  final String profile;
  final String nama;
  final int nominal;
  final String tanggal; // jatuh tempo YYYY-MM-DD
  final String status; // 'belum' | 'sudah'

  const Bill({
    required this.id,
    required this.profile,
    required this.nama,
    required this.nominal,
    required this.tanggal,
    this.status = 'belum',
  });

  bool get isLunas => status == 'sudah';

  Map<String, dynamic> toMap() => {
    'id': id,
    'profile': profile,
    'nama': nama,
    'nominal': nominal,
    'tanggal': tanggal,
    'status': status,
  };

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
    id: m['id'] as int,
    profile: m['profile'] as String? ?? '',
    nama: m['nama'] as String,
    nominal: (m['nominal'] as num).toInt(),
    tanggal: m['tanggal'] as String,
    status: m['status'] as String? ?? 'belum',
  );
}

class Debt {
  final int id;
  final String profile;
  final String creatorName;
  final String partnerName;
  final String jenis; // 'piutang' | 'utang'
  final String tipeTempo; // 'tanpa_tempo' | 'cicilan'
  final int? tenorBulan;
  final int? cicilanKe;
  final String tanggal;
  final int nominal;
  final String keterangan;
  final String status; // 'belum' | 'sudah'
  final String
  syncCode; // format UTG-XXXXXX; v1: disimpan lokal saja, tanpa sinkronisasi
  final String buktiPath;

  const Debt({
    required this.id,
    required this.profile,
    required this.creatorName,
    required this.partnerName,
    required this.jenis,
    this.tipeTempo = 'tanpa_tempo',
    this.tenorBulan,
    this.cicilanKe,
    required this.tanggal,
    required this.nominal,
    this.keterangan = '',
    this.status = 'belum',
    this.syncCode = '',
    this.buktiPath = '',
  });

  bool get isPiutang => jenis == 'piutang';
  bool get isLunas => status == 'sudah';

  Map<String, dynamic> toMap() => {
    'id': id,
    'profile': profile,
    'creatorName': creatorName,
    'partnerName': partnerName,
    'jenis': jenis,
    'tipeTempo': tipeTempo,
    'tenorBulan': tenorBulan,
    'cicilanKe': cicilanKe,
    'tanggal': tanggal,
    'nominal': nominal,
    'keterangan': keterangan,
    'status': status,
    'syncCode': syncCode,
    'buktiPath': buktiPath,
  };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
    id: m['id'] as int,
    profile: m['profile'] as String? ?? '',
    creatorName: m['creatorName'] as String? ?? '',
    partnerName: m['partnerName'] as String,
    jenis: m['jenis'] as String,
    tipeTempo: m['tipeTempo'] as String? ?? 'tanpa_tempo',
    tenorBulan: m['tenorBulan'] as int?,
    cicilanKe: m['cicilanKe'] as int?,
    tanggal: m['tanggal'] as String,
    nominal: (m['nominal'] as num).toInt(),
    keterangan: m['keterangan'] as String? ?? '',
    status: m['status'] as String? ?? 'belum',
    syncCode: m['syncCode'] as String? ?? '',
    buktiPath: m['buktiPath'] as String? ?? '',
  );
}

class ActivityLog {
  final int? id;
  final String profile;
  final String waktu; // string tampilan, mis. "5 Nov 2026, 16.30"
  final String deskripsi;

  const ActivityLog({
    this.id,
    required this.profile,
    required this.waktu,
    required this.deskripsi,
  });

  Map<String, dynamic> toMap() => {
    'profile': profile,
    'waktu': waktu,
    'deskripsi': deskripsi,
  };

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
    id: m['id'] as int?,
    profile: m['profile'] as String? ?? '',
    waktu: m['waktu'] as String,
    deskripsi: m['deskripsi'] as String,
  );
}

class BugReport {
  final int? id;
  final String profile;
  final String fitur;
  final String severity;
  final String judul;
  final String deskripsi;
  final String langkah;
  final String waktu; // string tampilan, mis. "6 Nov 2026, 00.30"
  final int createdAt; // ms epoch

  const BugReport({
    this.id,
    required this.profile,
    required this.fitur,
    required this.severity,
    required this.judul,
    required this.deskripsi,
    this.langkah = '',
    required this.waktu,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'profile': profile,
    'fitur': fitur,
    'severity': severity,
    'judul': judul,
    'deskripsi': deskripsi,
    'langkah': langkah,
    'waktu': waktu,
    'createdAt': createdAt,
  };

  factory BugReport.fromMap(Map<String, dynamic> m) => BugReport(
    id: m['id'] as int?,
    profile: m['profile'] as String? ?? '',
    fitur: m['fitur'] as String,
    severity: m['severity'] as String,
    judul: m['judul'] as String,
    deskripsi: m['deskripsi'] as String,
    langkah: m['langkah'] as String? ?? '',
    waktu: m['waktu'] as String,
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
  );

  /// Teks laporan lengkap — siap disalin pengguna (tanpa server).
  String toShareText(String appVersion) {
    final b = StringBuffer()
      ..writeln('LAPORAN BUG — DasboardReport $appVersion')
      ..writeln('Waktu: $waktu')
      ..writeln('Profil: $profile')
      ..writeln('Fitur: $fitur')
      ..writeln('Tingkat: $severity')
      ..writeln('Judul: $judul')
      ..writeln('Deskripsi: $deskripsi');
    if (langkah.isNotEmpty) b.writeln('Langkah reproduksi:\n$langkah');
    return b.toString();
  }
}

/// Kategori & daftar bank — sama persis dengan web.
class AppConstants {
  static const List<String> kategoriPemasukan = [
    'Gaji',
    'Bonus',
    'Hasil Usaha',
    'Investasi',
    'Lainnya',
  ];
  static const List<String> kategoriPengeluaran = [
    'Makan & Minum',
    'Transportasi',
    'Tagihan Bulanan',
    'Belanja',
    'Hiburan',
    'Kesehatan',
    'Lainnya',
  ];
  static const List<String> daftarBankTransfer = [
    'Danamon',
    'BCA',
    'Mandiri',
    'MNC',
    'SeaBank',
    'BRI',
    'OVO',
    'Dana',
    'GoPay',
  ];
  static const List<String> daftarCreditCard = [
    'Mastercard',
    'Visa Card',
    'BCA Card',
    'UnionPay',
    'Amex',
  ];
  static const List<String> daftarPaylater = [
    'Paylater BCA',
    'Kredivo',
    'SPayLater',
    'GoPayLater',
    'Akulaku',
    'Traveloka PayLater',
  ];
  static const List<String> metodePembayaran = [
    'Cash',
    'Transfer Bank',
    'QR',
    'Credit Card',
    'Paylater',
  ];
  static const List<String> investasiSub = ['Saham', 'Crypto', 'Deposito'];
  static const List<String> cryptoTokens = [
    'USDT',
    'USDC',
    'BTC',
    'ETH',
    'Lainnya',
  ];

  /// Nama ikon kategori (web) → nama ikon Material Flutter yang setara.
  static String iconNameForCategory(String kategori) {
    switch (kategori) {
      case 'Makan & Minum':
        return 'restaurant';
      case 'Transportasi':
        return 'directions_car';
      case 'Belanja':
        return 'shopping_bag';
      case 'Hiburan':
        return 'movie';
      case 'Kesehatan':
        return 'medical_services';
      case 'Investasi':
        return 'trending_up';
      default:
        return 'receipt_long';
    }
  }
}
