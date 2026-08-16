import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/discovery_repository.dart';
import '../../providers/discovery_provider.dart';

class DiscoveryFiltersSheet extends ConsumerStatefulWidget {
  const DiscoveryFiltersSheet({super.key});

  @override
  ConsumerState<DiscoveryFiltersSheet> createState() =>
      _DiscoveryFiltersSheetState();
}

class _DiscoveryFiltersSheetState extends ConsumerState<DiscoveryFiltersSheet> {
  List<String> _categories = [];
  double? _minPrice;
  double? _maxPrice;
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(discoveryFiltersProvider);
    if (existing != null) {
      _categories = List.from(existing.categories ?? []);
      _minPrice = existing.minPrice;
      _maxPrice = existing.maxPrice;
      _locationController.text = existing.location ?? '';
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(discoveryFiltersProvider.notifier).state = DiscoveryFilters(
      categories: _categories.isEmpty ? null : _categories,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
    );
    ref.invalidate(discoveryHostsProvider);
    Navigator.pop(context);
  }

  void _clear() {
    setState(() {
      _categories = [];
      _minPrice = null;
      _maxPrice = null;
      _locationController.clear();
    });
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_categories.contains(cat)) {
        _categories.remove(cat);
      } else {
        _categories.add(cat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: _clear,
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Categorias',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: AppConstants.meetingCategories.map((cat) {
                        return FilterChip(
                          label: Text(cat),
                          selected: _categories.contains(cat),
                          onSelected: (_) => _toggleCategory(cat),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Preço por hora (R\$)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _minPrice?.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Mín',
                              hintText: '0',
                            ),
                            onChanged: (v) =>
                                _minPrice = double.tryParse(v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _maxPrice?.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Máx',
                              hintText: '100',
                            ),
                            onChanged: (v) =>
                                _maxPrice = double.tryParse(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _apply,
                      child: const Text('Aplicar filtros'),
                    ),
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
