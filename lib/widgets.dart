import 'package:flutter/material.dart';

import 'app_state.dart';
import 'format.dart';
import 'models.dart';
import 'theme.dart';

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

  const TransactionTile({
    super.key,
    required this.trx,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInc = trx.isPemasukan;
    final icon = isInc ? Icons.arrow_downward_rounded : categoryIcon(trx.kategori);

    var subInfo = trx.kategori;
    if (trx.kategori == 'Investasi' && trx.investasiSub.isNotEmpty) {
      subInfo = 'Investasi • ${trx.investasiSub}';
      if (trx.investasiSub == 'Crypto' && trx.cryptoToken.isNotEmpty) {
        subInfo += ' (${trx.cryptoToken})';
      }
    }
    var metodeText = trx.metodePembayaran.isNotEmpty ? ' • ${trx.metodePembayaran}' : '';
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
                  Text(trx.keterangan,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text('$subInfo$metodeText',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 3),
                  Text(
                    formatTanggalPendek(parseIsoDate(trx.tanggal)),
                    style: GoogleFontsLike.muted10(context),
                  ),
                ],
              ),
            ),
            Text(
              amountText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isInc ? AppColors.green : AppColors.black,
                  ),
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
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              trailing ??
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
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
          shape: const CircleBorder(
              side: BorderSide(color: AppColors.border)),
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
        if (badge != null)
          Positioned(top: 6, right: 6, child: badge!),
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
      title: Text(state.t('more_title'),
          style: Theme.of(context).textTheme.titleLarge),
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
