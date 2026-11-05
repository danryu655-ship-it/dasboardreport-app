import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Layar sambutan profil pertama — cerminan modal #modalWelcome di web.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  Future<void> _start() async {
    final name = _controller.text.trim();
    final state = context.read<AppState>();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('name_empty'))));
      return;
    }
    setState(() => _busy = true);
    await state.createProfile(name);
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_circle_rounded,
                size: 44,
                color: AppColors.black,
              ),
              const SizedBox(height: 8),
              Text(
                state.t('welcome_title'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                state.t('welcome_sub'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: state.t('welcome_name_hint'),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _start,
                  child: Text(state.t('start_now')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
