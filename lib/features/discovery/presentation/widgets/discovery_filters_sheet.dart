import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/category_meta.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/discovery_repository.dart';
import '../../providers/discovery_provider.dart';

class DiscoveryFiltersSheet extends ConsumerStatefulWidget {
  const DiscoveryFiltersSheet({super.key});

  @override
  ConsumerState<DiscoveryFiltersSheet> createState() =>
      _DiscoveryFiltersSheetState();
}

class _DiscoveryFiltersSheetState extends ConsumerState<DiscoveryFiltersSheet> {
  late List<String> _categories;
  late bool _trainersOnly;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(discoveryFiltersProvider);
    _categories = List.of(existing.categories);
    _trainersOnly = existing.trainersOnly;
    _minController.text = _price(existing.minPrice);
    _maxController.text = _price(existing.maxPrice);
    _locationController.text = existing.location ?? '';
  }

  String _price(double? v) => v == null ? '' : v.toStringAsFixed(0);

  double? _parse(String v) => double.tryParse(v.replaceAll(',', '.').trim());

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _apply() {
    final location = _locationController.text.trim();
    ref.read(discoveryFiltersProvider.notifier).state = DiscoveryFilters(
      categories: _categories,
      minPrice: _parse(_minController.text),
      maxPrice: _parse(_maxController.text),
      location: location.isEmpty ? null : location,
      trainersOnly: _trainersOnly,
    );
    Navigator.pop(context);
  }

  void _clear() {
    setState(() {
      _categories = [];
      _trainersOnly = false;
      _minController.clear();
      _maxController.clear();
      _locationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtros', style: t.titleLarge),
                    TextButton(onPressed: _clear, child: const Text('Limpar')),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [
                    Text('Tipo de encontro', style: t.titleSmall),
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
                            selected
                                ? _categories.remove(c.slug)
                                : _categories.add(c.slug);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    Text('Preço por hora (R\$)', style: t.titleSmall),
                    const SizedBox(height: AppSpacing.x8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Mínimo',
                              prefixText: 'R\$ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x16),
                        Expanded(
                          child: TextField(
                            controller: _maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Máximo',
                              prefixText: 'R\$ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    TextField(
                      controller: _locationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        hintText: 'Ex.: São Paulo',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Só personal trainers'),
                      subtitle: const Text('Profissionais com plano Pro'),
                      value: _trainersOnly,
                      onChanged: (v) => setState(() => _trainersOnly = v),
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    AppButton(label: 'Aplicar filtros', onPressed: _apply),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
