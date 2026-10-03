import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/category_meta.dart';
import '../../../../core/models/host_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../widgets/photo_picker.dart';

/// Create or edit the user's paid-meetings listing.
class EditHostProfileScreen extends ConsumerWidget {
  const EditHostProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return profile.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Não foi possível carregar seu perfil',
          message: e.toString(),
          tone: EmptyStateTone.error,
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(myProfileProvider),
        ),
      ),
      data: (profile) => _HostProfileForm(profile: profile),
    );
  }
}

class _HostProfileForm extends ConsumerStatefulWidget {
  const _HostProfileForm({required this.profile});

  final HostProfileModel? profile;

  @override
  ConsumerState<_HostProfileForm> createState() => _HostProfileFormState();
}

class _HostProfileFormState extends ConsumerState<_HostProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _price = TextEditingController();
  final _categories = <String>[];
  final _newPhotos = <File>[];
  late List<String> _existingPhotos;
  bool _active = true;
  bool _saving = false;
  String? _categoryError;

  bool get _isNew => widget.profile == null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final user = ref.read(authStateProvider).valueOrNull;
    _name.text = p?.displayName ?? user?.displayName ?? '';
    _bio.text = p?.bio ?? '';
    _location.text = p?.location ?? '';
    _price.text = p?.pricePerHour?.toStringAsFixed(0) ?? '';
    _categories.addAll(p?.categories ?? const []);
    _existingPhotos = List.of(p?.photos ?? const []);
    _active = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
    _price.dispose();
    super.dispose();
  }

  int get _photoCount => _existingPhotos.length + _newPhotos.length;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final remaining = AppConstants.maxPhotosPerProfile - _photoCount;
    if (remaining <= 0) return;
    final images = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
      limit: remaining > 1 ? remaining : null,
    );
    if (images.isEmpty) return;
    setState(() {
      _newPhotos.addAll(images.take(remaining).map((x) => File(x.path)));
    });
  }

  Future<void> _removeExisting(String url) async {
    final profile = widget.profile;
    if (profile == null) return;
    try {
      await ref.read(profileRepositoryProvider).deletePhoto(profile.id, url);
      setState(() => _existingPhotos.remove(url));
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  double? get _priceValue =>
      double.tryParse(_price.text.replaceAll(',', '.').trim());

  Future<void> _save() async {
    setState(() => _categoryError =
        _categories.isEmpty ? 'Escolha pelo menos um tipo de encontro' : null);
    if (!_formKey.currentState!.validate() || _categoryError != null) return;

    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    try {
      final saved = await repo.saveMyProfile(
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        categories: _categories,
        pricePerHour: _priceValue!,
        location: _location.text.trim(),
        isActive: _isNew ? null : _active,
      );
      var failedUploads = 0;
      for (final file in _newPhotos) {
        try {
          await repo.uploadPhoto(saved.id, file);
        } catch (_) {
          failedUploads++;
        }
      }
      ref.invalidate(myProfileProvider);
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      _snack(failedUploads == 0
          ? (_isNew ? 'Perfil de anfitrião criado! Agora publique seus horários.' : 'Perfil salvo')
          : 'Perfil salvo, mas $failedUploads foto(s) não foram enviadas.');
      if (_isNew) {
        context.pushReplacement('/manage-availability');
      } else {
        context.pop();
      }
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Criar perfil de anfitrião' : 'Editar anúncio'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x20),
          children: [
            PhotoPicker(
              localPhotos: _newPhotos,
              existingUrls: _existingPhotos,
              onPick: _pickPhotos,
              onRemoveLocal: (i) => setState(() => _newPhotos.removeAt(i)),
              onRemoveExisting: _removeExisting,
              maxCount: AppConstants.maxPhotosPerProfile,
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
                  v == null || v.trim().isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: AppSpacing.x16),
            TextFormField(
              controller: _bio,
              maxLines: 4,
              maxLength: AppConstants.maxBioLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Sobre você',
                hintText: 'Conte o que você oferece e como costuma ser o encontro.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            Text('Tipos de encontro', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: meetingCategories.map((c) {
                final selected = _categories.contains(c.slug);
                return FilterChip(
                  avatar: Icon(c.icon, size: 16),
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    selected ? _categories.remove(c.slug) : _categories.add(c.slug);
                    _categoryError = null;
                  }),
                );
              }).toList(),
            ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x6),
                child: Text(_categoryError!,
                    style: t.bodySmall?.copyWith(color: AppColors.error)),
              ),
            const SizedBox(height: AppSpacing.x24),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preço por hora',
                prefixText: 'R\$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final price = _priceValue;
                if (v == null || v.trim().isEmpty) return 'Informe o preço por hora';
                if (price == null || price < 1) return 'Valor inválido';
                if (price > 10000) return 'Máximo de R\$ 10.000 por hora';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.x16),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Cidade',
                hintText: 'Ex.: São Paulo, SP',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            if (!_isNew) ...[
              const SizedBox(height: AppSpacing.x12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Anúncio visível'),
                subtitle: Text(_active
                    ? 'Aparece na busca e aceita reservas.'
                    : 'Pausado: ninguém encontra nem reserva.'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
            const SizedBox(height: AppSpacing.x24),
            AppButton(
              label: _isNew ? 'Criar perfil' : 'Salvar',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
