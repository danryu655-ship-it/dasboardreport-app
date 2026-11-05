import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';

/// Split bill — kalkulator patungan saja (web tidak menyimpan hasil).
/// Total ÷ jumlah orang; tampilkan "Total X untuk N orang. Y / orang."
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final _nameCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '2');
  int? _perPerson;
  int? _total;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  void _calculate(AppState state) {
    final total = parseNominal(_totalCtrl.text);
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (total <= 0 || count <= 0) {
      showAppSnack(context, state.t('split_invalid'), isError: true);
      return;
    }
    setState(() {
      _total = total;
      _perPerson = (total / count).round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState();
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          state.t('split_title'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: state.t('split_name'),
                  hintText: state.t('split_name_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _totalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: state.t('amount_label'),
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: state.t('split_people'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: state.t('split_calculate'),
                onPressed: () => _calculate(state),
              ),
              if (_perPerson != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.navDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      if (_nameCtrl.text.trim().isNotEmpty)
                        Text(
                          'PATUNGAN: ${_nameCtrl.text.trim().toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        formatRupiah(_perPerson!),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        state.t('split_result_per'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.t('split_result_total', {
                          'amount': formatRupiah(_total!),
                          'n': count.toString(),
                        }),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
