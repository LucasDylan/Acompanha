import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../widgets/slot_picker.dart';

class HostDetailScreen extends ConsumerWidget {
  const HostDetailScreen({
    super.key,
    required this.hostId,
  });

  final String hostId;

  static const name = 'host_detail';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    HostProfileModel? host;

    if (hostId.startsWith('m')) {
      final list = ref.watch(discoveryHostsProvider).valueOrNull;
      host = list?.where((h) => h.id == hostId).firstOrNull;
    } else {
      host = ref.watch(hostProfileProvider(hostId)).valueOrNull;
    }

    if (host == null) {
      if (hostId.startsWith('m')) {
        return Scaffold(
          appBar: AppBar(title: const Text('Host')),
          body: ref.watch(discoveryHostsProvider).when(
                data: (list) {
                  final h = list.where((x) => x.id == hostId).firstOrNull;
                  return h != null
                      ? _HostDetailContent(host: h)
                      : Center(child: Text('Host not found: $hostId'));
                },
                loading: () => const AppLoading(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Host')),
        body: ref.watch(hostProfileProvider(hostId)).when(
              data: (h) => _HostDetailContent(host: h),
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(host.displayName ?? 'Host')),
      body: _HostDetailContent(host: host),
    );
  }
}

class _HostDetailContent extends StatelessWidget {
  const _HostDetailContent({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: host.avatarUrl != null
                  ? Image.network(host.avatarUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade300,
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.grey.shade500,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        host.displayName ?? 'Host',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (host.rating != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                        Text(
                            '${host.rating!.toStringAsFixed(1)} (${host.reviewCount})'),
                      ],
                    ],
                  ),
                  if (host.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(host.location!),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    host.priceLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (host.bio != null) Text(host.bio!),
                  if (host.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: host.categories
                          .map((c) => Chip(label: Text(c)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Available times',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SlotPicker(
                    hostId: host.id,
                    host: host,
                    onSlotSelected: (slot) {
                      context.push(
                        '/host/${host.id}/booking',
                        extra: slot,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}
