import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/fitness.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../matches/providers/matches_provider.dart';

/// The user's own profile: what gym mates and hosts see about them.
class EditMyProfileScreen extends ConsumerStatefulWidget {
  const EditMyProfileScreen({super.key});

  @override
  ConsumerState<EditMyProfileScreen> createState() =>
      _EditMyProfileScreenState();
}

class _EditMyProfileScreenState extends ConsumerState<EditMyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _age = TextEditingController();
  String _level = 'beginner';
  final _workouts = <String>{};
  final _days = <String>{};
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      _name.text = user.displayName ?? '';
      _bio.text = user.bio ?? '';
      _age.text = user.age?.toString() ?? '';
      _level = user.fitnessLevel ?? 'beginner';
      _workouts.addAll(user.workoutTypes);
      _days.addAll(user.availableDays);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _age.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(authStateProvider.notifier).uploadAvatar(File(picked.path));
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authStateProvider.notifier).updateProfile({
        'display_name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'age': int.tryParse(_age.text.trim()),
        'fitness_level': _level,
        // Keep the app's canonical order rather than tap order.
        'workout_types':
            Fitness.workoutTypes.where(_workouts.contains).toList(),
        'available_days': Fitness.weekDays.where(_days.contains).toList(),
      });
      ref.invalidate(gymMembersProvider);
      if (!mounted) return;
      _snack('Perfil atualizado');
      context.pop();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploadingPhoto ? null : _pickPhoto,
                child: Stack(
                  children: [
                    AppAvatar(url: user?.avatarUrl, name: user?.name, radius: 48),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.brand,
                        child: _uploadingPhoto
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x24),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome de exibição',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Digite seu nome' : null,
            ),
            const SizedBox(height: AppSpacing.x16),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: AppConstants.maxBioLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Sobre você',
                hintText: 'Ex.: Treino de manhã, foco em hipertrofia.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextFormField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Idade (opcional)',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final age = int.tryParse(v.trim());
                if (age == null || age < 16 || age > 100) {
                  return 'Idade entre 16 e 100';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.x24),
            Text('Nível de treino', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            SegmentedButton<String>(
              segments: [
                for (final entry in Fitness.levels.entries)
                  ButtonSegment(value: entry.key, label: Text(entry.value)),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: AppSpacing.x24),
            Text('O que você treina', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                for (final w in Fitness.workoutTypes)
                  FilterChip(
                    label: Text(w),
                    selected: _workouts.contains(w),
                    onSelected: (sel) => setState(
                      () => sel ? _workouts.add(w) : _workouts.remove(w),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x24),
            Text('Dias em que costuma treinar', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                for (final d in Fitness.weekDays)
                  FilterChip(
                    label: Text(d),
                    selected: _days.contains(d),
                    onSelected: (sel) =>
                        setState(() => sel ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x32),
            AppButton(label: 'Salvar', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
