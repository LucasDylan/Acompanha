import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/routes/app_router.dart';
import 'core/theme/app_theme.dart';

const _ptBR = Locale('pt', 'BR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load Brazilian date symbols so DateFormat renders months/weekdays in pt-BR.
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  runApp(const ProviderScope(child: AcompanhaApp()));
}

class AcompanhaApp extends ConsumerWidget {
  const AcompanhaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Acompanha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: _ptBR,
      supportedLocales: const [_ptBR],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
