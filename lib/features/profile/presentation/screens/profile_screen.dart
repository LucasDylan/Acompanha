import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final myProfile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return _buildLoggedOut(context);
          }
          return myProfile.when(
            data: (profile) => _buildProfile(context, ref, user, profile),
            loading: () => const AppLoading(),
            error: (e, _) => _buildProfile(context, ref, user, null),
          );
        },
        loading: () => const AppLoading(),
        error: (e, _) => _buildLoggedOut(context),
      ),
    );
  }

  Widget _buildLoggedOut(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Sign in to view your profile',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    dynamic profile,
  ) {
    final hasHostProfile = profile != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Icon(Icons.person, size: 56, color: Colors.grey.shade400)
                      : null,
                ),
                if (hasHostProfile && (profile.photos.isNotEmpty))
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? user.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          if (!hasHostProfile) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Become a Host',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Offer your time for coffee, mentorship, or other meetings.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/edit-profile'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create host profile'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: InkWell(
                onTap: () => context.push('/edit-profile'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            profile.displayName ?? 'Host',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Icon(Icons.edit),
                        ],
                      ),
                      if (profile.bio != null) ...[
                        const SizedBox(height: 8),
                        Text(profile.bio!),
                      ],
                      if (profile.categories.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: profile.categories
                              .map((c) => Chip(label: Text(c)))
                              .toList(),
                        ),
                      ],
                      if (profile.pricePerHour != null) ...[
                        const SizedBox(height: 8),
                        Text(profile.priceLabel),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
