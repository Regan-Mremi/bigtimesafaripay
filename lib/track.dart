import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';
import 'package:intl/intl.dart';

class TrackPanel extends StatefulWidget {
  const TrackPanel({super.key});
  @override
  State<TrackPanel> createState() => _TrackPanelState();
}

class _TrackPanelState extends State<TrackPanel> {
  final c = TextEditingController();
  Map? res;
  bool busy = false, searched = false;

  Future<void> search() async {
    if (c.text.trim().isEmpty) return;
    setState(() { busy = true; searched = true; });
    try {
      final r = await sb.rpc('track_parcel', params: {'p_receipt': c.text});
      res = r == null ? null : Map.from(r as Map);
    } catch (_) {
      res = null;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: EdgeInsets.zero, children: [
        Header(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Track Parcel', style: serif(26, Colors.white)),
          const SizedBox(height: 4),
          const Text('Enter the receipt number (PCL-XXXXXXXX)', style: TextStyle(color: gold)),
          const SizedBox(height: 14),
          TextField(controller: c, textCapitalization: TextCapitalization.characters, onSubmitted: (_) => search(), decoration: InputDecoration(hintText: 'PCL-1A2B3C4D', prefixIcon: const Icon(Icons.qr_code), suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: search), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none))),
        ])),
        Padding(
          padding: const EdgeInsets.all(16),
          child: busy ? const Center(child: CircularProgressIndicator()) : res == null ? (searched ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No parcel found with that number'))) : const SizedBox()) : result(res!),
        ),
      ]);

  Widget result(Map r) {
    final events = List<Map>.from(r['events'] ?? []);
    return Container(
      padding: const EdgeInsets.all(16), decoration: cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(r['receipt'], style: serif(20))), chip(statusLabel(r['status']), statusColor(r['status']))]),
        const SizedBox(height: 10),
        Text('${r['description'] ?? 'Parcel'} → ${r['receiver']}', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('${r['company']} • ${r['bus']}', style: const TextStyle(color: Colors.black54)),
        Text('${r['from']} → ${r['to']} • Drop-off: ${r['drop_stop'] ?? r['to']}', style: const TextStyle(color: Colors.black54)),
        const Divider(height: 28),
        Text('Journey', style: serif(16)),
        const SizedBox(height: 10),
        for (final e in events)
          Container(
            margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.only(left: 16, bottom: 16),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: gold, width: 2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['note'] ?? statusLabel(e['status']), style: TextStyle(fontWeight: FontWeight.w600, color: statusColor(e['status']))),
              Text(DateFormat('d MMM, HH:mm').format(DateTime.parse(e['at']).toLocal()), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
      ]),
    );
  }
}
