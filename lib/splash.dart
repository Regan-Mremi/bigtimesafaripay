import 'package:flutter/material.dart';
import 'main.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final bus = CurvedAnimation(parent: c, curve: const Interval(0, 0.6, curve: Curves.easeOutCubic));
    final text = CurvedAnimation(parent: c, curve: const Interval(0.5, 1, curve: Curves.easeIn));
    return Scaffold(
      backgroundColor: navy,
      body: AnimatedBuilder(
        animation: c,
        builder: (_, __) => Stack(children: [
          Positioned(left: 0, right: 0, top: MediaQuery.of(context).size.height * 0.58, child: Container(height: 3, color: gold.withValues(alpha: 0.5 * bus.value))),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.58 - 74,
            left: -100 + (w / 2 - 20) * bus.value + (w / 2) * 0 - 0,
            child: Opacity(opacity: bus.value.clamp(0, 1), child: const Icon(Icons.directions_bus_filled, size: 80, color: gold)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 220),
              child: Opacity(
                opacity: text.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - text.value)),
                  child: const Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Basi Tiketi', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                    SizedBox(height: 8),
                    Text('SAFIRI KWA UHAKIKA', style: TextStyle(color: gold, letterSpacing: 4, fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ),
          Positioned(bottom: 60, left: 0, right: 0, child: Opacity(opacity: text.value, child: const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: gold, strokeWidth: 2))))),
        ]),
      ),
    );
  }
}
