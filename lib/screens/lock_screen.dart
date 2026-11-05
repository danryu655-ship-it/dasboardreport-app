import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Layar kunci PIN — cerminan modal PIN web:
/// mode 'verify' (buka app / idle) dan 'set' (pengaturan).
/// Keypad numerik ala mobile; verifikasi otomatis saat 4 digit terisi
/// (mode verify) atau lewat tombol Konfirmasi (mode set).
/// Reset darurat: ketik ulang nama profil.
class LockScreen extends StatefulWidget {
  final String mode; // 'verify' | 'set'
  final VoidCallback? onUnlocked;

  const LockScreen({super.key, required this.mode, this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _busy = false;

  bool get _isVerify => widget.mode == 'verify';

  void _pressDigit(String d) {
    if (_busy || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_isVerify && _pin.length == 4) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy) return;
    final state = context.read<AppState>();
    if (_isVerify) {
      if (_pin.isEmpty) return;
      setState(() => _busy = true);
      final ok = await state.verifyPin(_pin);
      setState(() => _busy = false);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked?.call();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.t('pin_wrong'))));
        setState(() => _pin = '');
      }
    } else {
      // Mode set: kosong = hapus PIN; 4 digit = simpan (cerminan web).
      if (_pin.isNotEmpty && _pin.length != 4) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN harus 4 digit')));
        return;
      }
      await state.savePin(_pin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _pin.isEmpty ? state.t('pin_removed') : state.t('pin_saved'),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _showEmergencyReset() async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          state.t('pin_reset_title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.t('pin_reset_hint', {'name': state.activeProfile ?? ''}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Nama Profil'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(state.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(state.t('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await state.emergencyResetPin(controller.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? state.t('pin_reset_ok') : state.t('pin_reset_fail')),
      ),
    );
    if (ok) widget.onUnlocked?.call();
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < _pin.length;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.black : AppColors.gray,
            border: Border.all(
              color: filled ? AppColors.black : AppColors.border,
            ),
          ),
        );
      }),
    );
  }

  Widget _keyButton(String label, {VoidCallback? onTap, IconData? icon}) {
    return Material(
      color: AppColors.gray,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 26, color: AppColors.black)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
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
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.lock_rounded, size: 40, color: AppColors.black),
              const SizedBox(height: 8),
              Text(
                _isVerify
                    ? state.t('pin_title_verify')
                    : state.t('pin_title_set'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _isVerify ? state.t('pin_sub_verify') : state.t('pin_sub_set'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildDots(),
              const SizedBox(height: 36),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _keyButton('1', onTap: () => _pressDigit('1')),
                        _keyButton('2', onTap: () => _pressDigit('2')),
                        _keyButton('3', onTap: () => _pressDigit('3')),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _keyButton('4', onTap: () => _pressDigit('4')),
                        _keyButton('5', onTap: () => _pressDigit('5')),
                        _keyButton('6', onTap: () => _pressDigit('6')),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _keyButton('7', onTap: () => _pressDigit('7')),
                        _keyButton('8', onTap: () => _pressDigit('8')),
                        _keyButton('9', onTap: () => _pressDigit('9')),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 72),
                        _keyButton('0', onTap: () => _pressDigit('0')),
                        _keyButton(
                          '',
                          icon: Icons.backspace_outlined,
                          onTap: _backspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(state.t('confirm')),
                ),
              ),
              if (_isVerify) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showEmergencyReset,
                  child: Text(
                    state.t('forgot_pin'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              if (!_isVerify) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(state.t('cancel')),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
