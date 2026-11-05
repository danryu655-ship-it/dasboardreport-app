import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'format.dart';
import 'models.dart';
import 'theme.dart';

/// Akses AppState dari context (dipakai semua layar fase 2).
extension WatchAppState on BuildContext {
  AppState watchAppState() => watch<AppState>();
}

/// Snackbar aplikasi (hijau sukses / merah error, ala alert web).
void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.danger : AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Dialog konfirmasi (ala confirm() web). Mengembalikan true bila pengguna
/// menekan tombol konfirmasi.
Future<bool?> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDestructive ? AppColors.danger : AppColors.purple,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Tombol utama aplikasi — cerminan .btn-primary web (ungu, radius 14).
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Ikon Material yang setara dengan Material Symbols Rounded di web.
IconData categoryIcon(String kategori) {
  switch (kategori) {
    case 'Makan & Minum':
      return Icons.restaurant_rounded;
    case 'Transportasi':
      return Icons.directions_car_rounded;
    case 'Belanja':
      return Icons.shopping_bag_rounded;
    case 'Hiburan':
      return Icons.movie_rounded;
    case 'Kesehatan':
      return Icons.medical_services_rounded;
    case 'Investasi':
      return Icons.trending_up_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

/// Item transaksi — cerminan `createTrxItem()` di web:
/// ikon 44 (radius 14), nama tebal 13, kategori muted 11, tanggal muted 10,
/// nominal kanan tebal 13 (hijau + untuk pemasukan, hitam - untuk pengeluaran).
class TransactionTile extends StatelessWidget {
  final AppTransaction trx;
  final AppState state;
  final VoidCallback? onTap;

  /// Bila diisi, tampil tombol hapus kecil di kanan (dipakai daftar
  /// dashboard & Wallet; sheet rincian bulan tidak menampilkannya).
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.trx,
    required this.state,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isInc = trx.isPemasukan;
    final icon = isInc
        ? Icons.arrow_downward_rounded
        : categoryIcon(trx.kategori);

    var subInfo = trx.kategori;
    if (trx.kategori == 'Investasi' && trx.investasiSub.isNotEmpty) {
      subInfo = 'Investasi • ${trx.investasiSub}';
      if (trx.investasiSub == 'Crypto' && trx.cryptoToken.isNotEmpty) {
        subInfo += ' (${trx.cryptoToken})';
      }
    }
    var metodeText = trx.metodePembayaran.isNotEmpty
        ? ' • ${trx.metodePembayaran}'
        : '';
    if (trx.detailBank.isNotEmpty) {
      metodeText += trx.tujuanBank.isNotEmpty
          ? ' (${trx.detailBank} ➔ ${trx.tujuanBank})'
          : ' (${trx.detailBank})';
    }

    final amountText = state.isPrivacyMode
        ? '•••'
        : '${isInc ? '+' : '-'}${formatRupiah(trx.nominal)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isInc ? const Color(0xFFE8F5E9) : AppColors.gray,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isInc ? AppColors.green : AppColors.black,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trx.keterangan,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$subInfo$metodeText',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatTanggalPendek(parseIsoDate(trx.tanggal)),
                    style: GoogleFontsLike.muted10(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isInc ? AppColors.green : AppColors.black,
                  ),
                ),
                if (onDelete != null)
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper kecil untuk teks muted 10 (tanggal item).
class GoogleFontsLike {
  static TextStyle muted10(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ) ??
      const TextStyle(fontSize: 10, color: AppColors.muted);
}

/// Kartu ringkasan ala web ("folder card"): warna kategori, potongan putih di
/// atas, ikon, label, nominal. Radius 20, tap → callback.
class SummaryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String amount;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.amount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header seksi: judul tebal 15 + tautan muted 12 (web: .section-header).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.linkLabel,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (linkLabel != null)
          InkWell(
            onTap: onLinkTap,
            child: Text(
              linkLabel!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Baris pengaturan ala web (.settings-item): abu radius 14.
class SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gray,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol bulat ikon ala web (.btn-icon-circle): 40, border abu.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Widget? badge;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.white,
          shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: AppColors.black),
            ),
          ),
        ),
        if (badge != null) Positioned(top: 6, right: 6, child: badge!),
      ],
    );
  }
}

/// Dialog "hadir di fase berikutnya" untuk aksi yang belum diimplementasikan.
Future<void> showComingSoon(BuildContext context, AppState state) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        state.t('more_title'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: Text(state.t('coming_phase')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(state.t('close')),
        ),
      ],
    ),
  );
}
