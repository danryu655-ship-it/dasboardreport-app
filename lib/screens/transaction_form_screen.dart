import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ocr_service.dart';

/// Form tambah / edit transaksi — cerminan form web (modal Catat Transaksi).
/// Aturan web: jenis default pengeluaran; kategori mengikuti jenis; sub
/// investasi hanya bila kategori Investasi; token crypto hanya bila sub
/// Crypto; daftar bank mengikuti metode; bank tujuan hanya pengeluaran +
/// Transfer Bank; bukti upload hanya bila metode bukan Cash; edit mengisi
/// ulang semua field dan mempertahankan bukti lama bila tidak ada file baru.
class TransactionFormScreen extends StatefulWidget {
  final AppTransaction? existing;
  const TransactionFormScreen({super.key, this.existing});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

/// Formatter input nominal: hanya digit, tampil dengan pemisah ribuan.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final value = int.tryParse(digits) ?? 0;
    final formatted = formatThousands(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  late String _jenis;
  late DateTime _tanggal;
  late String _kategori;
  String _investasiSub = '';
  String _cryptoToken = '';
  late String _metode;
  String _detailBank = '';
  String _tujuanBank = '';
  final _keteranganCtrl = TextEditingController();
  final _nominalCtrl = TextEditingController();
  String? _buktiPath;
  bool _saving = false;
  bool _scanning = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _jenis = e?.jenis ?? 'pengeluaran';
    _tanggal = e != null ? parseIsoDate(e.tanggal) : DateTime.now();
    _kategori =
        e?.kategori ??
        (_jenis == 'pemasukan'
            ? AppConstants.kategoriPemasukan.first
            : AppConstants.kategoriPengeluaran.first);
    _investasiSub = e?.investasiSub ?? '';
    _cryptoToken = e?.cryptoToken ?? '';
    _metode = e?.metodePembayaran ?? 'Cash';
    _detailBank = e?.detailBank ?? '';
    _tujuanBank = e?.tujuanBank ?? '';
    _keteranganCtrl.text = e?.keterangan ?? '';
    _nominalCtrl.text = e != null ? formatThousands(e.nominal) : '';
    _buktiPath = e?.buktiPath.isEmpty == true ? null : e?.buktiPath;
  }

  @override
  void dispose() {
    _keteranganCtrl.dispose();
    _nominalCtrl.dispose();
    super.dispose();
  }

  List<String> get _kategoriList => _jenis == 'pemasukan'
      ? AppConstants.kategoriPemasukan
      : AppConstants.kategoriPengeluaran;

  List<String> get _bankList {
    switch (_metode) {
      case 'Transfer Bank':
        return AppConstants.daftarBankTransfer;
      case 'Credit Card':
        return AppConstants.daftarCreditCard;
      case 'Paylater':
        return AppConstants.daftarPaylater;
      default:
        // Cerminan web (index.html ~2903): metode lain (QR/QRIS) memakai
        // daftar bank transfer. Sebelumnya default [] membuat
        // `_bankList.first` melempar "Bad state: No element" saat metode QR
        // dipilih (laporan user 2026-11-06 23:43).
        return AppConstants.daftarBankTransfer;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final buktiDir = Directory('${dir.path}/bukti');
    if (!await buktiDir.exists()) await buktiDir.create(recursive: true);
    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch;
    final dest = File('${buktiDir.path}/$id.jpg');
    await File(file.path).copy(dest.path);
    setState(() => _buktiPath = dest.path);
  }

  Future<void> _scanReceipt(AppState state) async {
    if (_scanning) return;
    if (!OcrService.isAvailable) {
      showAppSnack(context, state.t('scan_unavailable'), isError: true);
      return;
    }
    setState(() => _scanning = true);
    try {
      final result = await OcrService.scanFromGallery();
      if (!mounted) return;
      if (result == null) {
        // Pengguna membatalkan pemilihan gambar.
        return;
      }
      if (result.text.isEmpty) {
        showAppSnack(context, state.t('scan_failed'), isError: true);
        return;
      }
      final parsed = parseReceiptText(result.text);
      setState(() {
        if (parsed.nominal != null) {
          _nominalCtrl.text = formatThousands(parsed.nominal!);
        }
        if (parsed.tanggal != null) _tanggal = parsed.tanggal!;
        if (parsed.metode != null) _metode = parsed.metode!;
        if (parsed.bank != null) _detailBank = parsed.bank!;
        if (parsed.keterangan != null) {
          _keteranganCtrl.text = parsed.keterangan!;
        }
        if (parsed.metode != null || parsed.bank != null) {
          _jenis = 'pengeluaran';
          _kategori = 'Lainnya';
        }
      });
      showAppSnack(context, state.t('scan_done'));
    } catch (e) {
      if (mounted) {
        showAppSnack(context, '${state.t('scan_failed')} $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save(AppState state) async {
    if (_saving) return;
    final nominal = parseNominal(_nominalCtrl.text);
    final keterangan = _keteranganCtrl.text.trim();
    if (nominal <= 0) {
      showAppSnack(context, state.t('nominal_invalid'), isError: true);
      return;
    }
    if (keterangan.isEmpty) {
      showAppSnack(context, state.t('required_field'), isError: true);
      return;
    }
    setState(() => _saving = true);
    final trx = AppTransaction(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      profile: state.activeProfile ?? '',
      jenis: _jenis,
      tanggal: toIsoDate(_tanggal),
      kategori: _kategori,
      investasiSub: _kategori == 'Investasi' ? _investasiSub : '',
      cryptoToken: _kategori == 'Investasi' && _investasiSub == 'Crypto'
          ? _cryptoToken
          : '',
      metodePembayaran: _metode,
      detailBank: _metode == 'Cash' ? '' : _detailBank,
      tujuanBank: _jenis == 'pengeluaran' && _metode == 'Transfer Bank'
          ? _tujuanBank
          : '',
      keterangan: keterangan,
      nominal: nominal,
      buktiPath: _buktiPath ?? '',
    );
    if (_isEdit) {
      await state.updateTransaction(trx);
    } else {
      await state.addTransaction(trx);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(AppState state) async {
    final ok = await showAppConfirm(
      context,
      title: state.t('delete'),
      message: state.t('delete_trx_confirm'),
      confirmLabel: state.t('delete'),
      isDestructive: true,
    );
    if (ok != true) return;
    await state.deleteTransaction(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final showBukti = _metode != 'Cash';
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          _isEdit ? state.t('trx_edit') : state.t('modal_record_trx'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              onPressed: () => _delete(state),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Jenis: Pengeluaran / Pemasukan (ala type-switch web).
              Container(
                decoration: BoxDecoration(
                  color: AppColors.gray,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _typeOption(state, 'pengeluaran'),
                    _typeOption(state, 'pemasukan'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tanggal.
              _label(state.t('date')),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('d MMMM yyyy', 'id_ID').format(_tanggal),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Nominal.
              _label(state.t('amount_label')),
              const SizedBox(height: 6),
              TextField(
                controller: _nominalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  hintText: state.t('nominal_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              // Kategori.
              _label(state.t('category')),
              const SizedBox(height: 6),
              _dropdown(
                value: _kategori,
                items: _kategoriList,
                onChanged: (v) => setState(() {
                  _kategori = v!;
                  if (_kategori != 'Investasi') {
                    _investasiSub = '';
                    _cryptoToken = '';
                  }
                }),
              ),
              // Sub investasi (hanya bila kategori Investasi).
              if (_kategori == 'Investasi') ...[
                const SizedBox(height: 16),
                _label('Investasi'),
                const SizedBox(height: 6),
                _dropdown(
                  value: _investasiSub.isEmpty
                      ? AppConstants.investasiSub.first
                      : _investasiSub,
                  items: AppConstants.investasiSub,
                  onChanged: (v) => setState(() {
                    _investasiSub = v!;
                    if (_investasiSub != 'Crypto') _cryptoToken = '';
                  }),
                ),
              ],
              // Token crypto (hanya bila sub Crypto).
              if (_kategori == 'Investasi' && _investasiSub == 'Crypto') ...[
                const SizedBox(height: 16),
                _label('Token Crypto'),
                const SizedBox(height: 6),
                _dropdown(
                  value: _cryptoToken.isEmpty
                      ? AppConstants.cryptoTokens.first
                      : _cryptoToken,
                  items: AppConstants.cryptoTokens,
                  onChanged: (v) => setState(() => _cryptoToken = v!),
                ),
              ],
              const SizedBox(height: 16),
              // Metode pembayaran.
              _label(state.t('payment_method')),
              const SizedBox(height: 6),
              _dropdown(
                value: _metode,
                items: AppConstants.metodePembayaran,
                onChanged: (v) => setState(() {
                  _metode = v!;
                  // Cerminan web: select bank langsung terisi opsi pertama
                  // dari daftar metode baru, jadi yang tampil = yang tersimpan.
                  _detailBank = _bankList.isNotEmpty ? _bankList.first : '';
                  _tujuanBank = '';
                }),
              ),
              // Bank asal (bila metode bukan Cash).
              if (_metode != 'Cash') ...[
                const SizedBox(height: 16),
                _label(state.t('source_bank')),
                const SizedBox(height: 6),
                _dropdown(
                  value: _detailBank.isEmpty ? _bankList.first : _detailBank,
                  items: _bankList,
                  onChanged: (v) => setState(() => _detailBank = v!),
                ),
              ],
              // Bank tujuan (hanya pengeluaran + Transfer Bank).
              if (_jenis == 'pengeluaran' && _metode == 'Transfer Bank') ...[
                const SizedBox(height: 16),
                _label(state.t('destination_bank')),
                const SizedBox(height: 6),
                _dropdown(
                  value: _tujuanBank.isEmpty
                      ? AppConstants.daftarBankTransfer.first
                      : _tujuanBank,
                  items: AppConstants.daftarBankTransfer,
                  onChanged: (v) => setState(() => _tujuanBank = v!),
                ),
              ],
              const SizedBox(height: 16),
              // Keterangan.
              _label(state.t('description')),
              const SizedBox(height: 6),
              TextField(
                controller: _keteranganCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: state.t('note_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(fontSize: 15),
              ),
              // Bukti foto (hanya bila metode bukan Cash).
              if (showBukti) ...[
                const SizedBox(height: 16),
                _label(state.t('proof')),
                const SizedBox(height: 6),
                if (_buktiPath != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_buktiPath!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 120,
                            color: AppColors.gray,
                            alignment: Alignment.center,
                            child: Text(state.t('proof_attached')),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _buktiPath = null),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickProof,
                    icon: const Icon(Icons.image_rounded),
                    label: Text(state.t('proof_pick')),
                  ),
              ],
              const SizedBox(height: 20),
              // Scan struk (OCR).
              OutlinedButton.icon(
                onPressed: _scanning ? null : () => _scanReceipt(state),
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_rounded),
                label: Text(
                  _scanning ? state.t('scan_reading') : state.t('scan_receipt'),
                ),
              ),
              const SizedBox(height: 12),
              // Simpan.
              AppButton(
                label: state.t('save'),
                onPressed: _saving ? null : () => _save(state),
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeOption(AppState state, String jenis) {
    final selected = _jenis == jenis;
    final label = jenis == 'pemasukan' ? state.t('income') : state.t('expense');
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _jenis = jenis;
          _kategori = _kategoriList.first;
          _investasiSub = '';
          _cryptoToken = '';
          _tujuanBank = '';
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected ? AppShadows.soft : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.black : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Guard: daftar kosong tidak boleh melempar "Bad state: No element"
    // via `items.first` (pernah terjadi saat metode QR, 2026-11-06).
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('—', style: TextStyle(fontSize: 15)),
      );
    }
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
