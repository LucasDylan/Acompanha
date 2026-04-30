import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../providers/discovery_provider.dart';
import '../widgets/host_card.dart';
import '../widgets/discovery_filters_sheet.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(discoveryHostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const DiscoveryFiltersSheet(),
            ),
          ),
        ],
      ),
      body: hostsAsync.when(
        data: (hosts) {
          if (hosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No hosts found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            );
          }
          return _HostList(hosts: hosts);
        },
        loading: () => const AppLoading(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(discoveryHostsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostList extends StatelessWidget {
  const _HostList({required this.hosts});

  final List<HostProfileModel> hosts;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HostCard(
            host: host,
            onTap: () => context.push('/host/${host.id}'),
          ),
        );
      },
    );
  }
}
