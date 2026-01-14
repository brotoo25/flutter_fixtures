import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';

class RecorderExamplePage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const RecorderExamplePage({
    super.key,
    required this.navigatorKey,
  });

  @override
  State<RecorderExamplePage> createState() => _RecorderExamplePageState();
}

class _RecorderExamplePageState extends State<RecorderExamplePage> {
  String responseCode = "";
  String responseData = "";
  String selectedFixture = "";
  late FixtureRecorder recorder;
  late Dio dio;
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializeDio();
  }

  void _initializeRecorder() {
    recorder = FixtureRecorder(storage: JsonFileSessionStorage());
    recorder.addListener(() {
      setState(() {}); // Rebuild when recorder mode changes
    });
  }

  void _initializeDio() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      FixturesInterceptor(
        dataQuery: RecordableDataQuery(
          delegate: DioDataQuery(),
          recorder: recorder,
          source: 'dio',
        ),
        dataSelectorView: FixturesDialogView(
          context: widget.navigatorKey.currentContext!,
        ),
        dataSelector: DataSelectorType.pick(),
        dataSelectorDelay: DataSelectorDelay.moderate,
      ),
    );
  }

  String _prettifyJson(dynamic data) {
    try {
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          return data;
        }
      }
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  Future<void> _makeRequest() async {
    try {
      _requestCount++;
      final response = await dio.post('/login');

      // Extract fixture identifier from response
      String fixtureId = 'unknown';
      if (response.data is Map && response.data['_fixture'] != null) {
        fixtureId = response.data['_fixture'];
      }

      setState(() {
        responseCode = response.statusCode.toString();
        responseData = _prettifyJson(response.data);
        selectedFixture = fixtureId;
      });
    } catch (e) {
      setState(() {
        responseCode = 'Error';
        responseData = e.toString();
        selectedFixture = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recorder Info Card
                Card(
                  color: _getRecorderModeColor(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getRecorderModeIcon(),
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recorder Status: ${_getRecorderModeText()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (recorder.mode == RecorderMode.recording) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Recorded: ${recorder.recordingBufferSize} events',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                        if (recorder.mode == RecorderMode.playback &&
                            recorder.currentSession != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Session: ${recorder.currentSession!.name}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Progress: ${recorder.playbackIndex}/${recorder.totalEvents}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: recorder.totalEvents > 0
                                ? recorder.playbackIndex / recorder.totalEvents
                                : 0,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                const Text(
                  'Recorder Example',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recording: Blue FAB → Start Recording → Make requests → Red FAB → Save\n'
                  'Playback: Blue FAB → Select session → Make requests (auto-plays in order)',
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),

                // Single Request Button
                Center(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _makeRequest,
                        icon: const Icon(Icons.send),
                        label: const Text('Make Request'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Request count: $_requestCount',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Response Display
                if (responseCode.isNotEmpty) ...[
                  const Text(
                    'Last Response:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedFixture.isNotEmpty)
                            Text(
                              'Fixture: $selectedFixture',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          Text(
                            'Status: $responseCode',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(responseData),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Recorder Overlay Widget
          RecorderOverlayWidget(
            recorder: recorder,
            isMockMode: true,
          ),
        ],
      ),
    );
  }

  Color _getRecorderModeColor() {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return Colors.grey;
      case RecorderMode.recording:
        return Colors.red;
      case RecorderMode.playback:
        return Colors.green;
    }
  }

  IconData _getRecorderModeIcon() {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return Icons.fiber_manual_record_outlined;
      case RecorderMode.recording:
        return Icons.fiber_manual_record;
      case RecorderMode.playback:
        return Icons.play_arrow;
    }
  }

  String _getRecorderModeText() {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return 'Idle';
      case RecorderMode.recording:
        return 'Recording';
      case RecorderMode.playback:
        return 'Playing Back';
    }
  }

  @override
  void dispose() {
    recorder.dispose();
    super.dispose();
  }
}
