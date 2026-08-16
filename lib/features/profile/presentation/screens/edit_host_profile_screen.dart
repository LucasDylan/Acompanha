import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../providers/profile_provider.dart';
import '../widgets/photo_picker.dart';

class EditHostProfileScreen extends ConsumerStatefulWidget {
  const EditHostProfileScreen({super.key});

  static const name = 'edit_host_profile';

  @override
  ConsumerState<EditHostProfileScreen> createState() =>
      _EditHostProfileScreenState();
}

class _EditHostProfileScreenState extends ConsumerState<EditHostProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;

  List<String> _selectedCategories = [];
  final List<File> _localPhotos = [];
  List<String> _existingPhotoUrls = [];
  bool _hasPrepopulated = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _locationController = TextEditingController();
    _priceController = TextEditingController();
  }

  void _prepopulateFromProfile(dynamic profile) {
    if (profile == null || _hasPrepopulated) return;
    _hasPrepopulated = true;
    _nameController.text = profile.displayName ?? '';
    _bioController.text = profile.bio ?? '';
    _locationController.text = profile.location ?? '';
    _priceController.text = profile.pricePerHour?.toString() ?? '';
    _selectedCategories = List.from(profile.categories);
    _existingPhotoUrls = List.from(profile.photos);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 80,
      limit: AppConstants.maxPhotosPerProfile - _localPhotos.length - _existingPhotoUrls.length,
    );
    if (images.isNotEmpty) {
      setState(() {
        _localPhotos.addAll(
          images.map((x) => File(x.path)),
        );
      });
    }
  }

  void _removeLocalPhoto(int index) {
    setState(() => _localPhotos.removeAt(index));
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final formNotifier = ref.read(profileFormProvider.notifier);

    // The backend /me/ endpoint upserts, so the same call both creates a new
    // host profile and saves edits to an existing one.
    final saved = await formNotifier.saveMyProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim().isNotEmpty
          ? _bioController.text.trim()
          : null,
      categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
      pricePerHour: double.tryParse(_priceController.text),
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
    );

    if (saved != null) {
      for (final f in _localPhotos) {
        await formNotifier.uploadPhoto(saved.id, f);
      }
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil salvo')),
        );
        context.pop();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(profileFormProvider).error ??
                'Não foi possível salvar o perfil.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(profileFormProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    _prepopulateFromProfile(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile != null ? 'Editar perfil' : 'Criar perfil de anfitrião'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: formState.isLoading ? null : _save,
            child: formState.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PhotoPicker(
                localPhotos: _localPhotos,
                existingUrls: _existingPhotoUrls,
                onPick: _pickPhotos,
                onRemoveLocal: _removeLocalPhoto,
                maxCount: AppConstants.maxPhotosPerProfile,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome de exibição',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio curta',
                  alignLabelWithHint: true,
                ),
                maxLength: AppConstants.maxBioLength,
              ),
              const SizedBox(height: 16),
              Text(
                'Categorias',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppConstants.meetingCategories.map((cat) {
                  final selected = _selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => _toggleCategory(cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Preço por hora (R\$)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (double.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Cidade',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
