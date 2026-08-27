import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures_recorder_dio/flutter_fixtures_recorder_dio.dart';
import 'package:path_provider/path_provider.dart';

/// Demonstrates the recorder module: capture real traffic from
/// jsonplaceholder.typicode.com, save it as a named session, then replay it
/// with networking cut off — the flow used for product demos and offline
/// simulations.
class RecorderExamplePage extends StatefulWidget {
  const RecorderExamplePage({super.key});

  @override
  State<RecorderExamplePage> createState() => _RecorderExamplePageState();
}

class _RecorderExamplePageState extends State<RecorderExamplePage> {
  FixtureRecorder? recorder;
  late Dio dio;

  String responseCode = "";
  String responseData = "";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // File-backed sessions survive app restarts; web has no file system,
    // so recordings there live for the app's lifetime only.
    final RecordingSessionStore store;
    if (kIsWeb) {
      store = MemoryRecordingSessionStore();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      store = FileRecordingSessionStore('${dir.path}/fixture_recordings');
    }
    final fixtureRecorder = FixtureRecorder(store: store);

    dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
    dio.interceptors.add(RecorderInterceptor(recorder: fixtureRecorder));

    setState(() => recorder = fixtureRecorder);
  }

  Future<void> _request(Future<Response> Function() send) async {
    try {
      final response = await send();
      setState(() {
        responseCode = response.statusCode.toString();
        responseData = _prettifyJson(response.data);
      });
    } catch (e) {
      setState(() {
        responseCode = 'Error';
        responseData = e.toString();
      });
    }
  }

  String _prettifyJson(dynamic data) {
    try {
      if (data is String) data = jsonDecode(data);
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recorder = this.recorder;
    if (recorder == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RecorderToolbar(recorder: recorder),
            const SizedBox(height: 8),
            const Text(
              'Start a recording, make some requests, save the session. '
              'Then pick it from the sessions list to replay the same '
              'responses in the same order — no network needed.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _request(() => dio.get('/todos/1')),
                  icon: const Icon(Icons.download),
                  label: const Text('GET /todos/1'),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _request(() => dio.get('/users', queryParameters: {
                            '_limit': '3',
                          })),
                  icon: const Icon(Icons.people),
                  label: const Text('GET /users'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _request(() => dio.post('/posts', data: {
                        'title': 'Recorded post',
                        'body': 'Captured by flutter_fixtures_recorder',
                        'userId': 1,
                      })),
                  icon: const Icon(Icons.upload),
                  label: const Text('POST /posts'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (responseCode.isNotEmpty) ...[
              const Text(
                'Response:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Code:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(responseCode),
                      const SizedBox(height: 8),
                      const Text(
                        'Data:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          responseData,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
