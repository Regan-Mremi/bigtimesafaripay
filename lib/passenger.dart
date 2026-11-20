import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';
import 'track.dart';

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key});
  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: [const HomeTab(), const TicketsTab(), const TrackPanel()][tab],
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: 'My Tickets'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Track Parcel'),
        ]),
      );
}

// STEP 1: Greeting + where do you want to go
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String origin = 'Any', q = '';
  late final Future<Map> f = load();

  Future<Map> load() async {
    final me = await sb.from('profiles').select('full_name').eq('id', sb.auth.currentUser!.id).maybeSingle();
    final rows = await sb.from('trip_listing').select();
    return {'name': (me?['full_name'] ?? '') as String, 'rows': rows};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map>(
        future: f,
        builder: (_, s) {
          if (!s.hasData) return loader;
          final rows = List<Map>.from(s.data!['rows']);
          final first = (s.data!['name'] as String).trim().split(' ').first;
          final origins = ['Any', ...{for (final r in rows) r['origin'] as String}];
          final shown = rows.where((r) => origin == 'Any' || r['origin'] == origin).toList();
          final dests = <String, List<Map>>{};
          for (final r in shown) {
            dests.putIfAbsent(r['destination'], () => []).add(r);
          }
          final names = dests.keys.where((d) => d.toLowerCase().contains(q.toLowerCase())).toList()..sort();
          return ListView(padding: EdgeInsets.zero, children: [
            Header(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Hello, ${first.isEmpty ? 'there' : first} 👋', style: serif(28, Colors.white))),
                  IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: () => sb.auth.signOut()),
                ]),
                const SizedBox(height: 6),
                const Text('Where do you want to go?', style: TextStyle(color: gold, fontSize: 17)),
                const SizedBox(height: 16),
                TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Search destination', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Travelling from', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [for (final o in origins) ChoiceChip(label: Text(o), selected: origin == o, selectedColor: gold.withValues(alpha: 0.35), onSelected: (_) => setState(() => origin = o))]),
                const SizedBox(height: 18),
                Text('Destinations', style: serif(20)),
                const SizedBox(height: 10),
                if (names.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No upcoming trips found'))),
                for (final d in names)
                  Tile(
                    leading: badge(Icons.location_on),
                    title: d,
                    sub: '${dests[d]!.length} departure(s) available',
                    trailing: const Icon(Icons.chevron_right, color: gold),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompaniesPage(dest: d, rows: dests[d]!))),
                  ),
              ]),
            ),
          ]);
        },
      );
}

// STEP 2: choose bus company
class CompaniesPage extends StatelessWidget {
  final String dest;
  final List<Map> rows;
  const CompaniesPage({super.key, required this.dest, required this.rows});
  @override
  Widget build(BuildContext context) {
    final by = <String, List<Map>>{};
    for (final r in rows) {
      by.putIfAbsent(r['owner_id'], () => []).add(r);
    }
    return Scaffold(
      appBar: AppBar(title: Text('To $dest')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Choose bus company', style: serif(20)),
        const SizedBox(height: 12),
        for (final g in by.values)
          Tile(
            leading: CircleAvatar(radius: 24, backgroundColor: gold, child: Text((g.first['company'] as String).isEmpty ? '?' : (g.first['company'] as String)[0].toUpperCase(), style: serif(20))),
            title: g.first['company'],
            sub: '${g.length} departure(s) • from ${tzs.format(g.map((e) => e['price'] as int).reduce((a, b) => a < b ? a : b))}',
            trailing: const Icon(Icons.chevron_right, color: gold),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusesPage(company: g.first['company'], rows: g))),
          ),
      ]),
    );
  }
}

// STEP 3: choose bus (name + plate)
class BusesPage extends StatelessWidget {
  final String company;
  final List<Map> rows;
  const BusesPage({super.key, required this.company, required this.rows});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(company)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Choose your bus', style: serif(20)),
          const SizedBox(height: 12),
          for (final t in rows)
            Tile(
              leading: badge(Icons.directions_bus),
              title: t['bus_name'] ?? 'Bus',
              sub: '${t['origin']} → ${t['destination']}\n${dtFmt.format(DateTime.parse(t['departs_at']).toLocal())}',
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(tzs.format(t['price']), style: serif(15)),
                const SizedBox(height: 6),
                chip(t['plate'] ?? '', gold),
              ]),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeatPage(trip: t))),
            ),
        ]),
      );
}

// STEP 4: choose seat + pay
class SeatPage extends StatefulWidget {
  final Map trip;
  const SeatPage({super.key, required this.trip});
  @override
  State<SeatPage> createState() => _SeatPageState();
}

class _SeatPageState extends State<SeatPage> {
  int? seat;
  Set<int> taken = {};
  final phone = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    sb.rpc('taken_seats', params: {'p_trip': widget.trip['trip_id']}).then((r) {
      if (mounted) setState(() => taken = {for (final x in (r as List)) x as int});
    });
  }

  Future<void> pay() async {
    if (phone.text.trim().length < 9) return snack('Enter your mobile money number');
    setState(() => busy = true);
    try {
      final id = await sb.rpc('book_seat', params: {'p_trip': widget.trip['trip_id'], 'p_seat': seat});
      await sb.functions.invoke('start-payment', body: {'booking_id': id, 'phone': phone.text.trim()});
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.phone_android, color: gold, size: 40),
          title: const Text('Approve payment'),
          content: const Text('A payment request was sent to your phone. Enter your PIN to confirm. Your ticket will appear in My Tickets once paid.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      snack(e.toString().contains('SEAT_TAKEN') ? 'Sorry, that seat was just taken. Pick another.' : '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget seatBox(int n, int total) {
    if (n > total) return const SizedBox(width: 46, height: 46);
    final t = taken.contains(n), sel = seat == n;
    return GestureDetector(
      onTap: t ? null : () => setState(() => seat = n),
      child: Container(
        width: 46, height: 46, alignment: Alignment.center,
        decoration: BoxDecoration(color: t ? Colors.grey.shade300 : sel ? gold : Colors.white, border: Border.all(color: t ? Colors.grey : navy, width: sel ? 2 : 1), borderRadius: BorderRadius.circular(10)),
        child: t ? const Icon(Icons.close, size: 18, color: Colors.grey) : Text('$n', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
      ),
    );
  }

  Widget legend(Color c, String t) => Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: c, border: Border.all(color: navy), borderRadius: BorderRadius.circular(4))), const SizedBox(width: 6), Text(t, style: const TextStyle(fontSize: 12))]);

  @override
  Widget build(BuildContext context) {
    final t = widget.trip, total = t['seats'] as int, rowsN = (total / 4).ceil();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your seat')),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(14), decoration: cardDeco(),
          child: Row(children: [
            badge(Icons.directions_bus),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t['bus_name']}', style: serif(17)),
              Text('Plate number: ${t['plate']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${t['origin']} → ${t['destination']} • ${dtFmt.format(DateTime.parse(t['departs_at']).toLocal())}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ])),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [legend(Colors.white, 'Available'), legend(gold, 'Selected'), legend(Colors.grey.shade300, 'Taken')]),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFE8D2), borderRadius: BorderRadius.circular(28), border: Border.all(color: navy, width: 2)),
            child: ListView(children: [
              const Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.only(right: 8, bottom: 10), child: Icon(Icons.airline_seat_recline_extra, color: navy))),
              for (var r = 0; r < rowsN; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    seatBox(r * 4 + 1, total), const SizedBox(width: 10), seatBox(r * 4 + 2, total),
                    const SizedBox(width: 36),
                    seatBox(r * 4 + 3, total), const SizedBox(width: 10), seatBox(r * 4 + 4, total),
                  ]),
                ),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: navy.withValues(alpha: 0.12), blurRadius: 16)]),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile money number', prefixIcon: Icon(Icons.phone_android))),
            const SizedBox(height: 12),
            FilledButton(onPressed: seat == null || busy ? null : pay, child: Text(seat == null ? 'Select a seat' : 'Pay ${tzs.format(t['price'])} • Seat $seat')),
          ])),
        ),
      ]),
    );
  }
}

class TicketsTab extends StatelessWidget {
  const TicketsTab({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: sb.from('bookings').select('*, trips(origin, destination, departs_at, buses(name, plate))').eq('passenger_id', sb.auth.currentUser!.id).order('created_at', ascending: false),
        builder: (_, s) {
          final list = (s.data as List?) ?? [];
          return ListView(padding: EdgeInsets.zero, children: [
            Header(child: Text('My Tickets', style: serif(26, Colors.white))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: !s.hasData ? const Center(child: CircularProgressIndicator()) : list.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No tickets yet'))) : Column(children: [
                for (final b in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14), decoration: cardDeco(),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(14), width: double.infinity,
                        decoration: const BoxDecoration(color: navy, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                        child: Row(children: [
                          Expanded(child: Text('${b['trips']['origin']} → ${b['trips']['destination']}', style: serif(17, Colors.white))),
                          chip(b['status'] == 'paid' ? 'PAID' : 'PENDING', b['status'] == 'paid' ? Colors.greenAccent : gold),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${b['trips']['buses']['name']} • ${b['trips']['buses']['plate']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(dtFmt.format(DateTime.parse(b['trips']['departs_at']).toLocal()), style: const TextStyle(color: Colors.black54)),
                          const Divider(height: 24),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Seat ${b['seat_no']}', style: serif(18)),
                            Text(b['receipt_no'] ?? 'Awaiting payment', style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w600)),
                            Text(tzs.format(b['amount']), style: serif(16)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      );
}
