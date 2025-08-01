import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';

class BasicExamplePage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const BasicExamplePage({
    super.key,
    required this.navigatorKey,
  });

  @override
  State<BasicExamplePage> createState() => _BasicExamplePageState();
}

class _BasicExamplePageState extends State<BasicExamplePage> {
  String responseCode = "";
  String responseData = "";
  String responseFilePath = "";

  String _selectedSelectorType = 'Pick';
  late Dio dio;

  @override
  void initState() {
    super.initState();
    _initializeDio();
  }

  void _initializeDio() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
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

  Future<void> _makeRequest() async {
    try {
      final response = await dio.post(
        '/login',
        data: {'username': 'admin', 'password': '123456'},
      );

      // Extract file path from response headers if available
      String filePath = '';
      if (response.headers.map.containsKey('x-fixture-file-path')) {
        filePath = response.headers.value('x-fixture-file-path') ?? '';
      }

      setState(() {
        responseCode = response.statusCode.toString();
        responseData = response.data.toString();
        responseFilePath = filePath;
      });
    } catch (e) {
      setState(() {
        responseCode = 'Error';
        responseData = e.toString();
        responseFilePath = '';
      });
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _makeRequest,
              icon: const Icon(Icons.http),
              label: const Text('Make Request'),
            ),
          ),
        ],
      ),
    );
  }
}
