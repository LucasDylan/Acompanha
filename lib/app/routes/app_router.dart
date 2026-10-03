import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/host_profile_model.dart';
import '../../core/models/slot_model.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/presentation/screens/booking_confirm_screen.dart';
import '../../features/booking/presentation/screens/host_detail_screen.dart';
import '../../features/bookings/presentation/screens/bookings_screen.dart';
import '../../features/chat/models/conversation_model.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/discovery/presentation/screens/discovery_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/profile/presentation/screens/edit_host_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_my_profile_screen.dart';
import '../../features/profile/presentation/screens/help_screen.dart';
import '../../features/profile/presentation/screens/manage_availability_screen.dart';
import '../../features/profile/presentation/screens/privacy_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/register_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import 'shell_scaffold.dart';

// Root navigator key for routes outside the shell
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Individual navigator keys for each shell branch
final _discoveryNavigatorKey = GlobalKey<NavigatorState>();
final _matchesNavigatorKey = GlobalKey<NavigatorState>();
final _bookingsNavigatorKey = GlobalKey<NavigatorState>();
final _messagesNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

const _authRoutes = {'/login', '/register', '/forgot-password'};

/// What the booking-confirmation screen needs, passed as the route's `extra`.
class BookingDraft {
  const BookingDraft({required this.host, required this.slot});

  final HostProfileModel host;
  final SlotModel slot;
}

/// Pings the router whenever the session changes, so its redirect re-runs
/// without rebuilding the router itself (which would reset navigation and
/// tear down the screen a login error should be shown on).
class _AuthChanges extends ChangeNotifier {
  _AuthChanges(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authChanges = _AuthChanges(ref);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;

      // Still restoring the saved session (or it failed and can be retried).
      if (!auth.hasValue) return location == '/splash' ? null : '/splash';

      final loggedIn = auth.value != null;
      if (location == '/splash') return loggedIn ? '/' : '/login';
      if (!loggedIn) return _authRoutes.contains(location) ? null : '/login';
      if (_authRoutes.contains(location)) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
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
          StatefulShellBranch(
            navigatorKey: _discoveryNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DiscoveryScreen(),
              ),
            ],
          ),
          // The free "train together" flow
          StatefulShellBranch(
            navigatorKey: _matchesNavigatorKey,
            routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _bookingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const BookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _messagesNavigatorKey,
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
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
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/host/:hostId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final hostId = state.pathParameters['hostId'] ?? '';
          return HostDetailScreen(
            hostId: hostId,
            initial: state.extra as HostProfileModel?,
          );
        },
      ),
      GoRoute(
        path: '/host/:hostId/booking',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            BookingConfirmScreen(draft: state.extra as BookingDraft?),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          return ChatScreen(
            conversationId: conversationId,
            initial: state.extra as ConversationModel?,
          );
        },
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditMyProfileScreen(),
      ),
      GoRoute(
        path: '/host-profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditHostProfileScreen(),
      ),
      GoRoute(
        path: '/manage-availability',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ManageAvailabilityScreen(),
      ),
      GoRoute(
        path: '/help',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PrivacyScreen(),
      ),
    ],
  );
});
