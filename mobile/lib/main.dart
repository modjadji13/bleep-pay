import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'state/auth_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BleepPayApp(),
    ),
  );
}

class BleepPayApp extends ConsumerWidget {
  const BleepPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Bleep Pay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00F5A0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xFF050509),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 390,
                height: 844,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: auth.token != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
