import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plant_detection/features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
          Locale('hi'),
          Locale('fr'),
          Locale('ar'),
          Locale('bn'),
          Locale('ru'),
          Locale('pt'),
          Locale('id'),
          Locale('de'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const DetectPlantApp(),
      ),
    ),
  );
}

class DetectPlantApp extends ConsumerWidget {
  const DetectPlantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DetectPlant',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade600),
      ),
      home: const DashboardScreen(),
    );
  }
}

// Old dashboard removed, it uses lib/features/dashboard/dashboard_screen.dart now.
