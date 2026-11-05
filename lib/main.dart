import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Locale id-ID untuk format tanggal/Rupiah (cerminan Intl web).
  await initializeDateFormatting('id_ID', null);
  runApp(const DasboardReportApp());
}

class DasboardReportApp extends StatelessWidget {
  const DasboardReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider dibuat di sini (bukan di main) agar setiap entry point
    // — aplikasi maupun widget test — selalu punya AppState di atas RootGate.
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'DasboardReport',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootGate(),
      ),
    );
  }
}

/// Gerbang awal: inisialisasi state → welcome (tanpa profil) →
/// kunci PIN (bila ada) → shell utama.
/// Listener di root mereset timer idle di setiap interaksi (cerminan web).
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = context.read<AppState>().init().then((_) {
      if (mounted) {
        context.read<AppState>().startIdleTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.purple),
            ),
          );
        }
        return Consumer<AppState>(
          builder: (context, state, _) {
            Widget child;
            if (state.profiles.isEmpty || state.activeProfile == null) {
              child = const WelcomeScreen();
            } else if (state.isLocked) {
              child = const LockScreen(mode: 'verify');
            } else {
              child = const HomeShell();
            }
            return Listener(
              onPointerDown: (_) => state.touch(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}
