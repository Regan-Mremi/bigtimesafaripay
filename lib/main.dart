import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'passenger.dart';
import 'owner.dart';
import 'splash.dart';
import 'auth.dart';


const supabaseUrl = 'https://vkojjsnpxrwqvqwmdalf.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrb2pqc25weHJ3cXZxd21kYWxmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA1MzA2MzEsImV4cCI6MjEwNjEwNjYzMX0.FqQewZEzXiIevt12HNygCRQToKpuMxIicrHYz5jafPI';
final sb = Supabase.instance.client;

const navy = Color(0xFF0B2545);
const gold = Color(0xFFC9A227);
const cream = Color(0xFFF7F3E8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const BasiApp());
}

class BasiApp extends StatelessWidget {
  const BasiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Basi Tiketi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          
          colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: gold),
          appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, centerTitle: true),
          cardTheme: CardThemeData(color: Colors.white, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0x22C9A227)))),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48))),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
        ),
        home: const SplashPage(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (_, __) {
          if (sb.auth.currentSession == null) return const WelcomeScreen();
          return FutureBuilder(
            future: sb.from('profiles').select('role').eq('id', sb.auth.currentUser!.id).maybeSingle(),
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator(color: navy)));
              return s.data?['role'] == 'owner' ? const OwnerHome() : const PassengerHome();
            },
          );
        },
      );
}
