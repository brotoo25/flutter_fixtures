import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';

class AdvancedExamplePage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const AdvancedExamplePage({super.key, required this.navigatorKey});

  @override
  State<AdvancedExamplePage> createState() => _AdvancedExamplePageState();
}

class _AdvancedExamplePageState extends State<AdvancedExamplePage> {
  late Dio dio;

  String _selectedScenario = 'health';
  String _selectedSelectorType = 'Pick';

  String responseCode = '';
  String responseData = '';
  String responseFilePath = '';
  String requestedUrl = '';
  String errorText = '';

  @override
  void initState() {
    super.initState();
    _initializeDio();
  }

  void _initializeDio() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.clear();
    dio.interceptors.add(
      FixturesInterceptor(
        dataQuery: DioDataQuery(),
        dataSelectorView: FixturesDialogView(
          context: widget.navigatorKey.currentContext!,
        ),
        dataSelector: _getDataSelectorType(),
      ),
    );
  }

  DataSelectorType _getDataSelectorType() {
    switch (_selectedSelectorType) {
      case 'Random':
        return DataSelectorType.random();
      case 'Default':
        return DataSelectorType.defaultValue();
      case 'Pick':
        return DataSelectorType.pick();
      default:
        return DataSelectorType.random();
    }
  }

  void _changeSelectorType(String? value) {
    if (value != null) {
      setState(() {
        _selectedSelectorType = value;
      });
      _initializeDio();
    }
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

      // Convert to pretty JSON
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      // If prettification fails, return string representation
      return data.toString();
    }
  }

  Future<void> _makeApiRequest() async {
    setState(() {
      responseCode = '';
      responseData = '';
      responseFilePath = '';
      requestedUrl = '';
      errorText = '';
    });

    try {
      late Response response;
      late String fullUrl;
      final baseUrl = dio.options.baseUrl;

      switch (_selectedScenario) {
        case 'health':
          fullUrl = '$baseUrl/health';
          response = await dio.get('/health');
          break;
        case 'user':
          final queryParams = {'id': '456'};
          final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          fullUrl = '$baseUrl/users?$queryString';
          response = await dio.get('/users', queryParameters: queryParams);
          break;
        case 'report':
          final queryParams = {'type': 'sales', 'format': 'pdf'};
          final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          fullUrl = '$baseUrl/reports?$queryString';
          response = await dio.get('/reports', queryParameters: queryParams);
          break;
        case 'search':
          final queryParams = {'q': 'flutter', 'page': '1'};
          final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          fullUrl = '$baseUrl/search?$queryString';
          response = await dio.get('/search', queryParameters: queryParams);
          break;
        case 'file':
          final queryParams = {'category': 'images', 'filename': 'logo.png'};
          final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          fullUrl = '$baseUrl/files?$queryString';
          response = await dio.get('/files', queryParameters: queryParams);
          break;
        case 'invalid':
          fullUrl = '$baseUrl/nonexistent';
          response = await dio.get('/nonexistent');
          break;
        default:
          throw Exception('Unknown scenario: $_selectedScenario');
      }

      String filePath = '';
      if (response.headers.map.containsKey('x-fixture-file-path')) {
        filePath = response.headers.value('x-fixture-file-path') ?? '';
      }

      setState(() {
        responseCode = response.statusCode?.toString() ?? '';
        responseData = _prettifyJson(response.data);
        responseFilePath = filePath;
        requestedUrl = fullUrl;
      });
    } catch (e) {
      setState(() {
        responseCode = 'Error';
        responseData = '';
        responseFilePath = '';
        requestedUrl = '';
        errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selector Type:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedSelectorType,
              onChanged: _changeSelectorType,
              items: const [
                DropdownMenuItem(value: 'Random', child: Text('Random')),
                DropdownMenuItem(value: 'Default', child: Text('Default')),
                DropdownMenuItem(value: 'Pick', child: Text('Pick')),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Advanced Wildcard Pattern Testing:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Each scenario demonstrates a different fixture matching pattern:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text('• Health Check: Exact match (Priority 1)', style: TextStyle(fontSize: 12)),
                  Text('• User Profile: Single wildcard (Priority 3)',
                      style: TextStyle(fontSize: 12)),
                  Text('• Report: Double wildcard (Priority 3)', style: TextStyle(fontSize: 12)),
                  Text('• Search Results: Mustache pattern (Priority 4)',
                      style: TextStyle(fontSize: 12)),
                  Text('• File Download: Fallback mustache (Priority 5)',
                      style: TextStyle(fontSize: 12)),
                  Text('• Invalid API: No match (Error handling)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // API Scenario Selection
            const Text(
              'API Scenario:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedScenario,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'health', child: Text('Health Check (Exact Match)')),
                DropdownMenuItem(value: 'user', child: Text('User Profile (Single Wildcard)')),
                DropdownMenuItem(value: 'report', child: Text('Report (Double Wildcard)')),
                DropdownMenuItem(value: 'search', child: Text('Search Results (Mustache Pattern)')),
                DropdownMenuItem(value: 'file', child: Text('File Download (Fallback Mustache)')),
                DropdownMenuItem(value: 'invalid', child: Text('Invalid API (No Match)')),
              ],
              onChanged: (v) => setState(() => _selectedScenario = v ?? 'health'),
            ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _makeApiRequest,
                icon: const Icon(Icons.api),
                label: const Text('Test API Scenario'),
              ),
            ),
            const SizedBox(height: 24),
            if (errorText.isNotEmpty) ...[
              const Text(
                'Error:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorText,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
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
                      if (requestedUrl.isNotEmpty) ...[
                        const Text(
                          'Requested URL:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          requestedUrl,
                          style: const TextStyle(color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (responseFilePath.isNotEmpty) ...[
                        const Text(
                          'File Path:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          responseFilePath,
                          style: const TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                      ],
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
