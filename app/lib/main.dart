import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const PetHealthApp());
}

class PetHealthApp extends StatelessWidget {
  const PetHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      routerConfig: router,
      theme: AppTheme.theme,
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
    );
  }
}
