import 'package:flutter/material.dart';

import '../../../../core/models/host_profile_model.dart';

class HostCard extends StatelessWidget {
  const HostCard({
    super.key,
    required this.host,
    required this.onTap,
  });

  final HostProfileModel host;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: host.avatarUrl != null
                    ? NetworkImage(host.avatarUrl!)
                    : null,
                child: host.avatarUrl == null
                    ? Icon(Icons.person, size: 36, color: Colors.grey.shade600)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          host.displayName ?? 'Host',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (host.rating != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          Text(
                            host.rating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    if (host.bio != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        host.bio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                    if (host.categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: host.categories
                            .take(3)
                            .map((c) => Chip(
                                  label: Text(
                                    c,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      host.priceLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
