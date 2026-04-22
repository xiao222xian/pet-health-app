import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/pet_profile_screen.dart';
import '../features/profile/pet_form_screen.dart';
import '../features/profile/medical_records_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/timeline/event_form_screen.dart';
import '../features/health_log/health_log_screen.dart';
import '../features/consult/consult_screen.dart';
import '../features/account/account_screen.dart';

// Listenable that triggers GoRouter to re-evaluate redirects on auth state change
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream() {
    Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }
}

final _routerRefresh = _GoRouterRefreshStream();

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _routerRefresh,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/auth';
    if (!isLoggedIn && !isAuthRoute) return '/auth';
    if (isLoggedIn && isAuthRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const PetProfileScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/health', builder: (_, __) => const HealthLogScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/consult', builder: (_, __) => const ConsultScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/timeline', builder: (_, __) => const TimelineScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/pet/new', builder: (_, __) => const PetFormScreen()),
    GoRoute(
      path: '/pet/edit/:id',
      builder: (_, state) => PetFormScreen(petId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/medical/:petId',
      builder: (_, state) =>
          MedicalRecordsScreen(petId: state.pathParameters['petId']!),
    ),
    GoRoute(
      path: '/timeline/new/:petId',
      builder: (_, state) =>
          EventFormScreen(petId: state.pathParameters['petId']!),
    ),
    GoRoute(
      path: '/timeline/edit/:eventId',
      builder: (_, state) =>
          EventFormScreen(eventId: state.pathParameters['eventId']!),
    ),
  ],
);
