import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main.dart';

final tzs = NumberFormat.currency(locale: 'en', symbol: 'TSh ', decimalDigits: 0);
final dtFmt = DateFormat('EEE d MMM • HH:mm');
TextStyle serif(double s, [Color c = navy]) => TextStyle(fontFamily: 'Georgia', fontSize: s, fontWeight: FontWeight.bold, color: c);

Color statusColor(String s) => {'received': Colors.blueGrey, 'onboard': Colors.blue, 'dropped': Colors.green, 'missed': Colors.red}[s] ?? Colors.grey;
String statusLabel(String s) => {'received': 'Received', 'onboard': 'On the bus', 'dropped': 'Delivered', 'missed': 'Missed drop-off'}[s] ?? s;

Widget chip(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.6))),
      child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );

Widget badge(IconData i) => CircleAvatar(radius: 24, backgroundColor: navy, child: Icon(i, color: gold));

BoxDecoration cardDeco([Color c = Colors.white]) => BoxDecoration(color: c, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: navy.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 5))]);

class Header extends StatelessWidget {
  final Widget child;
  const Header({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [navy, Color(0xFF1D4E89)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
        child: child,
      );
}

class Tile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  const Tile({super.key, required this.leading, required this.title, this.sub, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Ink(
          decoration: cardDeco(),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                leading,
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: serif(16)),
                  if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: const TextStyle(color: Colors.black54, fontSize: 13))),
                ])),
                if (trailing != null) trailing!,
              ]),
            ),
          ),
        ),
      );
}

const loader = Center(child: CircularProgressIndicator(color: navy));
