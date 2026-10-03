import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/presentation/screens/booking_confirm_screen.dart';
import '../../features/booking/presentation/screens/host_detail_screen.dart';
import '../../features/bookings/presentation/screens/bookings_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/discovery/presentation/screens/discovery_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/profile/presentation/screens/edit_host_profile_screen.dart';
import '../../features/profile/presentation/screens/manage_availability_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/register_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../core/models/slot_model.dart';
import 'shell_scaffold.dart';

// Root navigator key for routes outside the shell
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Individual navigator keys for each shell branch
final _discoveryNavigatorKey = GlobalKey<NavigatorState>();
final _matchesNavigatorKey = GlobalKey<NavigatorState>();
final _bookingsNavigatorKey = GlobalKey<NavigatorState>();
final _messagesNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoggingIn = state.uri.toString() == '/login' ||
          state.uri.toString() == '/register' ||
          state.uri.toString() == '/forgot-password';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      // Auth routes - outside shell, use root navigator
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Discovery
          StatefulShellBranch(
            navigatorKey: _discoveryNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DiscoveryScreen(),
              ),
            ],
          ),
          // Branch 1: Matches — the free "train together" flow
          StatefulShellBranch(
            navigatorKey: _matchesNavigatorKey,
            routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesScreen(),
              ),
            ],
          ),
          // Branch 2: Bookings
          StatefulShellBranch(
            navigatorKey: _bookingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const BookingsScreen(),
              ),
            ],
          ),
          // Branch 3: Messages
          StatefulShellBranch(
            navigatorKey: _messagesNavigatorKey,
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          // Branch 4: Profile
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Routes outside shell - use root navigator
      // Search — opened from the Discover header (it used to occupy the tab
      // that now holds Matches).
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      // Host detail - receives hostId parameter
      GoRoute(
        path: '/host/:hostId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final hostId = state.pathParameters['hostId'] ?? '';
          return HostDetailScreen(hostId: hostId);
        },
      ),
      // Booking confirmation - receives hostId parameter and slot via extra
      GoRoute(
        path: '/host/:hostId/booking',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final hostId = state.pathParameters['hostId'] ?? '';
          final slot = state.extra as SlotModel?;
          return BookingConfirmScreen(hostId: hostId, slot: slot);
        },
      ),
      // Chat screen - receives conversationId parameter
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          return ChatScreen(conversationId: conversationId);
        },
      ),
      // Edit profile - outside shell
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditHostProfileScreen(),
      ),
      GoRoute(
        path: '/manage-availability',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ManageAvailabilityScreen(),
      ),
    ],
  );
});
