import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Manajemen profil — cerminan modal #modalAkun di web:
/// ubah nama profil aktif, daftar profil tersimpan (ketuk untuk pindah),
/// buat profil baru. Ditampilkan sebagai layar penuh (adaptasi mobile).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _editNameController;
  final _newNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editNameController = TextEditingController(
      text: context.read<AppState>().activeProfile ?? '',
    );
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _saveRename() async {
    final state = context.read<AppState>();
    final newName = _editNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('name_empty'))));
      return;
    }
    if (newName == state.activeProfile) {
      Navigator.of(context).pop();
      return;
    }
    if (state.profiles.contains(newName)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('name_exists'))));
      return;
    }
    final ok = await state.renameActiveProfile(newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? state.t('name_saved') : state.t('name_exists')),
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _createProfile() async {
    final state = context.read<AppState>();
    final name = _newNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('name_empty'))));
      return;
    }
    if (state.profiles.contains(name)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('name_exists'))));
      return;
    }
    await state.createProfile(name);
    if (!mounted) return;
    _newNameController.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(state.t('settings_profile')),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.t('edit_profile_name'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _editNameController,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveRename,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(state.t('save_name_change')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.t('saved_profiles'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...state.profiles.map((name) {
              final isActive = name == state.activeProfile;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.gray,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () async {
                      await state.switchProfile(name);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: isActive
                            ? Border.all(color: AppColors.black, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (isActive)
                            const Icon(
                              Icons.check_rounded,
                              color: AppColors.green,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _newNameController,
              decoration: InputDecoration(
                hintText: state.t('create_new_profile'),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createProfile(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gray,
                  foregroundColor: AppColors.black,
                ),
                child: Text(state.t('create_new_profile')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
