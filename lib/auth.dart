import 'package:flutter/material.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget roleCard(BuildContext c, String title, String sub, IconData icon, bool owner) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AuthPage(owner: owner))),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: navy, child: Icon(icon, color: gold, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
                Text(sub, style: const TextStyle(color: Colors.black54)),
              ])),
              const Icon(Icons.chevron_right, color: gold),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  const Icon(Icons.directions_bus_filled, size: 64, color: navy),
                  const Text('Karibu!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: navy)),
                  const SizedBox(height: 6),
                  const Text('Continue as', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 24),
                  roleCard(context, 'Passenger', 'Book bus tickets easily', Icons.person, false),
                  const SizedBox(height: 14),
                  roleCard(context, 'Bus Owner', 'Manage trips, parcels & earnings', Icons.business_center, true),
                ]),
              ),
            ),
          ),
        ),
      );
}

class AuthPage extends StatefulWidget {
  final bool owner;
  const AuthPage({super.key, required this.owner});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController(), name = TextEditingController(), phone = TextEditingController(), company = TextEditingController(), payout = TextEditingController();
  bool signup = false, busy = false, hide = true;
  String network = 'M-Pesa';

  void msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.length < 6) return msg('Enter email and a password of at least 6 characters');
    if (signup && (name.text.trim().isEmpty || phone.text.trim().isEmpty)) return msg('Name and phone are required');
    if (signup && widget.owner && (company.text.trim().isEmpty || payout.text.trim().isEmpty)) return msg('Company name and payout number are required');
    setState(() => busy = true);
    try {
      if (signup) {
        final r = await sb.auth.signUp(email: email.text.trim(), password: pass.text, data: {
          'full_name': name.text.trim(),
          'phone': phone.text.trim(),
          'role': widget.owner ? 'owner' : 'passenger',
          if (widget.owner) ...{'company': company.text.trim(), 'payout_phone': payout.text.trim(), 'payout_network': network},
        });
        if (r.session == null) msg('Account created. Check your email to confirm, then sign in.');
      } else {
        await sb.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
      if (mounted && sb.auth.currentSession != null) Navigator.popUntil(context, (r) => r.isFirst);
    } on AuthException catch (e) {
      msg(e.message);
    } catch (e) {
      msg('$e');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget field(TextEditingController c, String label, {TextInputType? type, IconData? icon}) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon))));

  @override
  Widget build(BuildContext context) {
    final o = widget.owner;
    return Scaffold(
      appBar: AppBar(title: Text(o ? 'Bus Owner' : 'Passenger')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(children: [
              Icon(o ? Icons.business_center : Icons.person, size: 48, color: gold),
              const SizedBox(height: 8),
              Text(signup ? 'Create account' : 'Welcome back', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navy)),
              const SizedBox(height: 20),
              if (signup) ...[
                field(name, 'Full name', icon: Icons.badge),
                field(phone, 'Phone (07XXXXXXXX)', type: TextInputType.phone, icon: Icons.phone),
                if (o) field(company, 'Bus company name', icon: Icons.directions_bus),
              ],
              field(email, 'Email', type: TextInputType.emailAddress, icon: Icons.email),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(controller: pass, obscureText: hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)))),
              ),
              if (signup && o) ...[
                const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Where should we send your earnings?', style: TextStyle(color: navy)))),
                DropdownButtonFormField<String>(initialValue: network, decoration: const InputDecoration(labelText: 'Mobile money network'), items: [for (final n in ['M-Pesa', 'Tigo Pesa', 'Airtel Money', 'HaloPesa']) DropdownMenuItem(value: n, child: Text(n))], onChanged: (v) => setState(() => network = v!)),
                const SizedBox(height: 12),
                field(payout, 'Payout number', type: TextInputType.phone, icon: Icons.account_balance_wallet),
              ],
              const SizedBox(height: 8),
              FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(signup ? 'Register' : 'Sign in')),
              TextButton(onPressed: () => setState(() => signup = !signup), child: Text(signup ? 'Already have an account? Sign in' : 'New here? Register')),
            ]),
          ),
        ),
      ),
    );
  }
}
