// lib/services/live_track_stream.dart
//
// Live tracking for the customer app: the same Server-Sent Events stream the web tracking page
// uses (/api/public/track/{code}/{ticket}/stream). Each driver position is pushed the moment
// their phone reports it - no polling. Reconnects on its own after a network drop.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'authentication_service.dart';

class LiveEvent {
  final String name; // ready | position | status | eta
  final Map<String, dynamic> data;
  LiveEvent(this.name, this.data);
}

class LiveTrackStream {
  final String companyCode;
  final String ticketNo;
  LiveTrackStream(this.companyCode, this.ticketNo);

  final _events = StreamController<LiveEvent>.broadcast();
  Stream<LiveEvent> get events => _events.stream;

  http.Client? _client;
  StreamSubscription<String>? _lines;
  Timer? _retry;
  bool _closed = false;

  String get _base =>
      '${AuthenticationService.apiBaseUrl}/public/track/${Uri.encodeComponent(companyCode)}/${Uri.encodeComponent(ticketNo)}';

  void start() => _connect();

  Future<void> _connect() async {
    if (_closed) return;
    _client?.close();
    final client = _client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse('$_base/stream'))..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        // 404 = the car is no longer requested / on its way - nothing to follow.
        if (response.statusCode != 404) _scheduleRetry();
        return;
      }
      String? name;
      final data = StringBuffer();
      _lines = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.isEmpty) {
          if (name != null && data.isNotEmpty) {
            try {
              _events.add(LiveEvent(name!, jsonDecode(data.toString()) as Map<String, dynamic>));
            } catch (_) {}
          }
          name = null;
          data.clear();
        } else if (line.startsWith('event:')) {
          name = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trim());
        }
      }, onDone: _scheduleRetry, onError: (_) => _scheduleRetry(), cancelOnError: true);
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), _connect);
  }

  /// Route driven so far (empty until the car is on its way).
  Future<List<List<double>>> trail() async {
    try {
      final res = await http.get(Uri.parse('$_base/trail')).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return (jsonDecode(res.body) as List)
          .map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
          .toList();
    } catch (_) {
      return [];
    }
  }

  void close() {
    _closed = true;
    _retry?.cancel();
    _lines?.cancel();
    _client?.close();
    _events.close();
  }
}
