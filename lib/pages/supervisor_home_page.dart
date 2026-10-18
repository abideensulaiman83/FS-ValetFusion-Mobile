// lib/pages/supervisor_home_page.dart
//
// SUPERVISOR home: when off duty, the list of assigned sites with a "Check in" button each (GPS
// fix sent, distance from the site shown). When checked in, a duty card - site, time on duty,
// on site / left site - and "Check out", which asks for a short checklist and notes. Recent visits
// underneath. SupervisorTracker keeps reporting the position in the background meanwhile.
import 'package:flutter/material.dart';
import '../services/authentication_service.dart';
import '../services/supervisor_service.dart';
import '../services/supervisor_tracker.dart';

const List<String> kSupervisorChecklist = [
  'Valet team present and in uniform',
  'Queue and drop-off under control',
  'Key box secure and in order',
  'Podium / desk clean and tidy',
  'Equipment and tickets available',
  'No open guest complaints',
];

class SupervisorHomePage extends StatefulWidget {
  const SupervisorHomePage({super.key});

  @override
  State<SupervisorHomePage> createState() => _SupervisorHomePageState();
}

class _SupervisorHomePageState extends State<SupervisorHomePage> {
  final _api = SupervisorService();
  final _tracker = SupervisorTracker.instance;
  List<SupervisorVisit> _history = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _tracker.start();
      _history = await _api.myVisits();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _checkIn(SupervisorSite site) async {
    setState(() => _busy = true);
    try {
      final fix = await SupervisorTracker.currentFix();
      final me = _tracker.me.value;
      if (fix == null && (me?.requireGps ?? true)) {
        _snack('Turn on location (GPS) and allow it for ValetFusion to check in.', error: true);
        return;
      }
      final v = await _api.checkIn(site.id, lat: fix?.latitude, lng: fix?.longitude, accuracyM: fix?.accuracy);
      _snack(v.checkInOnSite == false
          ? 'Checked in at ${site.name} - note: you are ${v.checkInDistanceM} m from the site.'
          : 'Checked in at ${site.name}.');
      await _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut(SupervisorVisit visit) async {
    final result = await showModalBottomSheet<_CheckOutResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckOutSheet(siteName: visit.locationName),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      final fix = await SupervisorTracker.currentFix();
      await _api.checkOut(lat: fix?.latitude, lng: fix?.longitude, checklist: result.checklist, notes: result.notes);
      _snack('Checked out of ${visit.locationName}.');
      await _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await AuthenticationService().logoutApi();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  String _dur(int min) => min < 60 ? '$min min' : '${min ~/ 60} h ${min % 60} min';
  String _time(DateTime d) => '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ValueListenableBuilder<SupervisorMe?>(
                      valueListenable: _tracker.me,
                      builder: (context, me, _) => ValueListenableBuilder<SupervisorVisit?>(
                        valueListenable: _tracker.visit,
                        builder: (context, visit, _) => ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text('Hello, ${me?.name ?? ''}', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            if (visit != null) _dutyCard(visit) else ..._siteCards(me),
                            const SizedBox(height: 24),
                            Text('Recent visits', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            if (_history.isEmpty) const Text('No visits yet.'),
                            ..._history.map((v) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(v.status == 'OPEN' ? Icons.timelapse : Icons.check_circle_outline),
                                  title: Text(v.locationName),
                                  subtitle: Text('${_time(v.checkInAt)} · ${_dur(v.durationMinutes)}'
                                      '${v.offSiteMinutes > 0 ? ' · away ${_dur(v.offSiteMinutes)}' : ''}'),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _dutyCard(SupervisorVisit v) {
    final away = v.lastOnSite == false;
    final color = away ? Colors.orange : Colors.green;
    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(away ? Icons.directions_walk : Icons.location_on, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text('On duty at ${v.locationName}', style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 8),
            Text('Since ${_time(v.checkInAt)} (${_dur(DateTime.now().difference(v.checkInAt).inMinutes)})'),
            if (v.lastDistanceM != null)
              Text(away ? 'You are ${v.lastDistanceM} m away from the site.' : 'At the site (${v.lastDistanceM} m).',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Your location is shared with head office until you check out. Keep the app running.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _checkOut(v),
                icon: const Icon(Icons.logout),
                label: const Text('Check out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _siteCards(SupervisorMe? me) {
    final sites = me?.sites ?? const <SupervisorSite>[];
    if (sites.isEmpty) {
      return const [Text('No sites are assigned to you yet. Ask your manager to assign your sites on the portal.')];
    }
    return [
      const Text('Choose the site you are at to check in:'),
      const SizedBox(height: 8),
      ...sites.map((s) => Card(
            child: ListTile(
              leading: const Icon(Icons.apartment),
              title: Text(s.name),
              subtitle: Text(s.lat == null ? 'Site position not set' : (s.code ?? '')),
              trailing: FilledButton(onPressed: _busy ? null : () => _checkIn(s), child: const Text('Check in')),
            ),
          )),
    ];
  }
}

class _CheckOutResult {
  final Map<String, bool> checklist;
  final String notes;
  _CheckOutResult(this.checklist, this.notes);
}

class _CheckOutSheet extends StatefulWidget {
  final String siteName;
  const _CheckOutSheet({required this.siteName});

  @override
  State<_CheckOutSheet> createState() => _CheckOutSheetState();
}

class _CheckOutSheetState extends State<_CheckOutSheet> {
  final Map<String, bool> _answers = {for (final item in kSupervisorChecklist) item: true};
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Check out of ${widget.siteName}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Untick anything that was not OK.'),
              ...kSupervisorChecklist.map((item) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _answers[item],
                    title: Text(item),
                    onChanged: (v) => setState(() => _answers[item] = v ?? false),
                  )),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes / incidents (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, _CheckOutResult(_answers, _notes.text)),
                child: const Text('Check out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
