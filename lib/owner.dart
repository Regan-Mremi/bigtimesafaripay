import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'ui.dart';

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(['Dashboard', 'Fleet & Trips', 'Parcels', 'Alerts'][tab]), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => sb.auth.signOut())]),
        body: [const Dashboard(), const FleetPage(), const ParcelsPage(), const AlertsPage()][tab],
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
          NavigationDestination(icon: Icon(Icons.insights), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.directions_bus), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Parcels'),
          NavigationDestination(icon: Icon(Icons.notifications_active), label: 'Alerts'),
        ]),
      );
}

Widget statBox(String label, String value, IconData icon) => Expanded(
      child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(14), decoration: cardDeco(), child: Column(children: [Icon(icon, color: gold), const SizedBox(height: 6), Text(value, style: serif(17)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))])),
    );

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  Future<Map> load() async {
    final uid = sb.auth.currentUser!.id;
    final w = await sb.from('wallets').select('balance').eq('owner_id', uid).maybeSingle();
    final led = await sb.from('ledger').select('kind, amount').eq('owner_id', uid);
    final tickets = await sb.from('bookings').select('amount, receipt_no, seat_no, trips(origin, destination)').eq('status', 'paid').order('created_at', ascending: false).limit(30);
    final parcels = await sb.from('parcels').select('id').eq('owner_id', uid);
    int sum(String k) => led.where((e) => e['kind'] == k).fold<int>(0, (a, e) => a + (e['amount'] as int));
    return {'balance': w?['balance'] ?? 0, 'earned': sum('ticket_owner_credit'), 'fees': sum('platform_fee_ticket') + sum('platform_fee_parcel'), 'tickets': tickets, 'parcels': parcels.length};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: load(),
        builder: (_, s) {
          if (!s.hasData) return loader;
          final d = s.data!;
          return ListView(padding: const EdgeInsets.all(10), children: [
            Container(
              padding: const EdgeInsets.all(20), margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy, Color(0xFF1D4E89)]), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Wallet balance', style: TextStyle(color: gold)),
                Text(tzs.format(d['balance']), style: serif(30, Colors.white)),
                const Text('Parcel fees (TSh 200 each) are deducted from this balance', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            Row(children: [statBox('Earned', tzs.format(d['earned']), Icons.trending_up), statBox('Platform fees', tzs.format(d['fees']), Icons.receipt_long)]),
            Row(children: [statBox('Tickets sold', '${(d['tickets'] as List).length}', Icons.confirmation_number), statBox('Parcels', '${d['parcels']}', Icons.inventory_2)]),
            Padding(padding: const EdgeInsets.fromLTRB(8, 16, 8, 8), child: Text('Recent tickets', style: serif(18))),
            for (final t in d['tickets'] as List) Tile(leading: badge(Icons.confirmation_number), title: '${t['trips']['origin']} → ${t['trips']['destination']}', sub: '${t['receipt_no']} • Seat ${t['seat_no']}', trailing: Text(tzs.format(t['amount']), style: serif(14))),
          ]);
        },
      );
}

// Buses + trips + stops
class FleetPage extends StatefulWidget {
  const FleetPage({super.key});
  @override
  State<FleetPage> createState() => _FleetPageState();
}

class _FleetPageState extends State<FleetPage> {
  Future<Map> load() async {
    final uid = sb.auth.currentUser!.id;
    return {
      'buses': await sb.from('buses').select().eq('owner_id', uid),
      'trips': await sb.from('trips').select('*, buses!inner(name, plate, owner_id)').eq('buses.owner_id', uid).order('departs_at', ascending: false),
    };
  }

  Future<void> addBus() async {
    final n = TextEditingController(), p = TextEditingController(), s = TextEditingController(text: '50');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Add bus'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Bus name')),
        const SizedBox(height: 8),
        TextField(controller: p, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Plate number (e.g. T123 ABC)')),
        const SizedBox(height: 8),
        TextField(controller: s, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of seats')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    ));
    if (ok != true) return;
    try {
      await sb.from('buses').insert({'owner_id': sb.auth.currentUser!.id, 'name': n.text.trim(), 'plate': p.text.trim().toUpperCase(), 'seats': int.tryParse(s.text) ?? 50});
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    setState(() {});
  }

  Future<void> addTrip(List buses) async {
    if (buses.isEmpty) return toast(context, 'Add a bus first');
    final o = TextEditingController(), d = TextEditingController(), pr = TextEditingController(), st = TextEditingController();
    String bus = buses.first['id'];
    DateTime? when;
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (_, set) => AlertDialog(
      title: const Text('New trip'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: bus, decoration: const InputDecoration(labelText: 'Bus'), items: [for (final b in buses) DropdownMenuItem(value: b['id'] as String, child: Text('${b['name']} • ${b['plate']}'))], onChanged: (v) => set(() => bus = v!)),
        const SizedBox(height: 8),
        TextField(controller: o, decoration: const InputDecoration(labelText: 'From')),
        const SizedBox(height: 8),
        TextField(controller: d, decoration: const InputDecoration(labelText: 'To (final destination)')),
        const SizedBox(height: 8),
        TextField(controller: pr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ticket price (TSh)')),
        const SizedBox(height: 8),
        TextField(controller: st, decoration: const InputDecoration(labelText: 'Stops in order, comma separated', hintText: 'Morogoro, Dodoma, Singida')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule),
          label: Text(when == null ? 'Pick departure time' : DateFormat('d MMM yyyy, HH:mm').format(when!)),
          onPressed: () async {
            final day = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (day == null || !context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 6, minute: 0));
            if (t != null) set(() => when = DateTime(day.year, day.month, day.day, t.hour, t.minute));
          },
        ),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
    )));
    if (ok != true) return;
    if (when == null || o.text.trim().isEmpty || d.text.trim().isEmpty || int.tryParse(pr.text) == null) return toast(context, 'Fill in all trip details');
    try {
      final t = await sb.from('trips').insert({'bus_id': bus, 'origin': o.text.trim(), 'destination': d.text.trim(), 'departs_at': when!.toUtc().toIso8601String(), 'price': int.parse(pr.text)}).select().single();
      final names = [...st.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty), d.text.trim()];
      await sb.from('trip_stops').insert([for (final (i, n) in names.indexed) {'trip_id': t['id'], 'name': n, 'stop_order': i + 1}]);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map>(
        future: load(),
        builder: (_, s) {
          if (!s.hasData) return loader;
          final buses = s.data!['buses'] as List, trips = s.data!['trips'] as List;
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(backgroundColor: gold, onPressed: () => addTrip(buses), icon: const Icon(Icons.add_road), label: const Text('New trip')),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [Expanded(child: Text('My buses', style: serif(20))), TextButton.icon(onPressed: addBus, icon: const Icon(Icons.add), label: const Text('Add bus'))]),
              if (buses.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No buses yet')),
              for (final b in buses) Tile(leading: badge(Icons.directions_bus), title: b['name'] ?? 'Bus', sub: '${b['plate']} • ${b['seats']} seats'),
              const SizedBox(height: 10),
              Text('Trips', style: serif(20)),
              const SizedBox(height: 10),
              for (final t in trips)
                Tile(
                  leading: badge(Icons.route),
                  title: '${t['origin']} → ${t['destination']}',
                  sub: '${t['buses']['plate']} • ${dtFmt.format(DateTime.parse(t['departs_at']).toLocal())}\n${tzs.format(t['price'])}',
                  trailing: t['status'] == 'scheduled'
                      ? FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 38)), onPressed: () async { await sb.rpc('start_trip', params: {'p_trip': t['id']}); if (mounted) { toast(context, 'Trip started. Parcels are now on the bus.'); setState(() {}); } }, child: const Text('Depart'))
                      : chip('Departed', Colors.green),
                ),
              const SizedBox(height: 70),
            ]),
          );
        },
      );
}

// Parcel arrangement per destination stop
class ParcelsPage extends StatefulWidget {
  const ParcelsPage({super.key});
  @override
  State<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends State<ParcelsPage> {
  Map? trip;
  Future<List> trips() => sb.from('trips').select('id, origin, destination, departs_at, buses!inner(owner_id)').eq('buses.owner_id', sb.auth.currentUser!.id).order('departs_at', ascending: false);

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: trips(),
        builder: (_, s) {
          if (!s.hasData) return loader;
          final list = s.data as List;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<Map>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select trip'),
                items: [for (final t in list) DropdownMenuItem(value: t, child: Text('${t['origin']} → ${t['destination']}  ${DateFormat('d MMM HH:mm').format(DateTime.parse(t['departs_at']).toLocal())}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => trip = v),
              ),
            ),
            Expanded(child: trip == null ? const Center(child: Text('Choose a trip to manage parcels')) : TripParcels(key: ValueKey(trip!['id']), tripId: trip!['id'])),
          ]);
        },
      );
}

class TripParcels extends StatefulWidget {
  final String tripId;
  const TripParcels({super.key, required this.tripId});
  @override
  State<TripParcels> createState() => _TripParcelsState();
}

class _TripParcelsState extends State<TripParcels> {
  Future<Map> load() async => {
        'stops': await sb.from('trip_stops').select().eq('trip_id', widget.tripId).order('stop_order'),
        'parcels': await sb.from('parcels').select().eq('trip_id', widget.tripId).order('created_at'),
      };

  Future<void> addParcel(List stops) async {
    if (stops.isEmpty) return toast(context, 'This trip has no stops');
    final c = List.generate(5, (_) => TextEditingController());
    String? stop = stops.first['id'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, set) => AlertDialog(
        title: const Text('New parcel'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('A TSh 200 platform fee is deducted from your wallet. The receipt is issued after that.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          for (final (i, l) in ['Sender name', 'Sender phone', 'Receiver name', 'Receiver phone', 'Description'].indexed) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c[i], keyboardType: (i == 1 || i == 3) ? TextInputType.phone : null, decoration: InputDecoration(labelText: l))),
          DropdownButtonFormField<String>(initialValue: stop, decoration: const InputDecoration(labelText: 'Drop-off point'), items: [for (final s in stops) DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))], onChanged: (v) => set(() => stop = v)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Register'))],
      )),
    );
    if (ok != true) return;
    try {
      final receipt = await sb.rpc('register_parcel', params: {'p_trip': widget.tripId, 'p_sender': c[0].text, 'p_sphone': c[1].text, 'p_receiver': c[2].text, 'p_rphone': c[3].text, 'p_desc': c[4].text, 'p_stop': stop});
      if (mounted) await showDialog(context: context, builder: (_) => AlertDialog(icon: const Icon(Icons.check_circle, color: Colors.green, size: 40), title: const Text('Parcel registered'), content: Text('Receipt: $receipt\nGive this number to the sender so they can track it.'), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    } catch (e) {
      if (mounted) toast(context, e.toString().contains('INSUFFICIENT') ? 'Wallet balance too low for the TSh 200 fee' : '$e');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: load(),
        builder: (_, s) {
          if (!s.hasData) return loader;
          final stops = s.data!['stops'] as List, parcels = s.data!['parcels'] as List;
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(backgroundColor: gold, onPressed: () => addParcel(stops), icon: const Icon(Icons.add), label: const Text('Add parcel')),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
              for (final st in stops) ...[
                Row(children: [
                  Expanded(child: Text('${st['stop_order']}. ${st['name']}', style: serif(17))),
                  st['passed'] == true
                      ? chip('Passed', Colors.grey)
                      : TextButton.icon(icon: const Icon(Icons.flag), label: const Text('Passed stop'), onPressed: () async {
                          final n = await sb.rpc('mark_stop_passed', params: {'p_stop': st['id']});
                          if (mounted) { toast(context, n > 0 ? '$n parcel(s) NOT dropped. See Alerts.' : 'Stop marked as passed'); setState(() {}); }
                        }),
                ]),
                if (parcels.where((p) => p['drop_stop_id'] == st['id']).isEmpty) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('No parcels for this stop', style: TextStyle(color: Colors.black45))),
                for (final p in parcels.where((p) => p['drop_stop_id'] == st['id']))
                  Tile(
                    leading: badge(Icons.inventory_2),
                    title: '${p['description']} → ${p['receiver_name']}',
                    sub: '${p['receipt_no']} • ${p['receiver_phone']}',
                    trailing: p['status'] == 'dropped'
                        ? chip('Delivered', Colors.green)
                        : Column(mainAxisSize: MainAxisSize.min, children: [chip(statusLabel(p['status']), statusColor(p['status'])), TextButton(onPressed: () async { await sb.rpc('drop_parcel', params: {'p_parcel': p['id']}); setState(() {}); }, child: const Text('Mark dropped'))]),
                  ),
              ],
            ]),
          );
        },
      );
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: sb.from('notifications').stream(primaryKey: ['id']).eq('owner_id', sb.auth.currentUser!.id).order('created_at'),
        builder: (_, s) {
          final items = (s.data ?? []).reversed.toList();
          if (items.isEmpty) return const Center(child: Text('No alerts'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final n in items)
              Tile(leading: CircleAvatar(radius: 24, backgroundColor: (n['title'] as String? ?? '').startsWith('Parcel') ? Colors.red.shade50 : Colors.amber.shade50, child: Icon((n['title'] as String? ?? '').startsWith('Parcel') ? Icons.warning_amber : Icons.info_outline, color: (n['title'] as String? ?? '').startsWith('Parcel') ? Colors.red : Colors.orange)), title: n['title'] ?? '', sub: n['body'] ?? ''),
          ]);
        },
      );
}
