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

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/auth';
    if (!isLoggedIn && !isAuthRoute) return '/auth';
    if (isLoggedIn && isAuthRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
    ShellRoute(
      builder: (context, state, child) => HomeScreen(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const PetProfileScreen()),
        GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
        GoRoute(path: '/health', builder: (_, __) => const HealthLogScreen()),
        GoRoute(path: '/consult', builder: (_, __) => const ConsultScreen()),
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
  ],
);
