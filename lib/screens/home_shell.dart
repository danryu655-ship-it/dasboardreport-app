import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'placeholder_screen.dart';

/// App shell — bottom navigation ala mobile (bukan nav web):
/// bar gelap mengambang bentuk pil + FAB putih di tengah.
/// Tab dipertahankan dengan IndexedStack (seperti tab web show/hide).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cek kunci idle saat kembali dari background (web: timer 1 menit).
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().checkIdleLock();
    }
  }

  void _goTo(int index) => setState(() => _currentIndex = index);

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required AppState state,
  }) {
    final active = _currentIndex == index;
    return InkWell(
      onTap: () => _goTo(index),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? Colors.white : AppColors.muted,
            ),
            if (active) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            onGoWallet: () => _goTo(1),
            onGoReport: () => _goTo(2),
          ),
          const PlaceholderScreen(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Wallet',
            subtitle: 'Riwayat lengkap, filter & grafik',
          ),
          const PlaceholderScreen(
            icon: Icons.pie_chart_rounded,
            title: 'Report',
            subtitle: 'Alokasi & rincian kategori',
          ),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.navDark,
            borderRadius: BorderRadius.circular(36),
            boxShadow: AppShadows.nav,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: state.t('nav_home'),
                index: 0,
                state: state,
              ),
              _navItem(
                icon: Icons.account_balance_wallet_rounded,
                label: state.t('nav_wallet'),
                index: 1,
                state: state,
              ),
              Material(
                color: AppColors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  onTap: () => showComingSoon(context, state),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.add_rounded,
                        size: 26, color: AppColors.black),
                  ),
                ),
              ),
              _navItem(
                icon: Icons.pie_chart_rounded,
                label: state.t('nav_report'),
                index: 2,
                state: state,
              ),
              _navItem(
                icon: Icons.hexagon_rounded,
                label: state.t('nav_more'),
                index: 3,
                state: state,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
