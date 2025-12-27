import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';

class SqfliteExamplePage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const SqfliteExamplePage({super.key, required this.navigatorKey});

  @override
  State<SqfliteExamplePage> createState() => _SqfliteExamplePageState();
}

class _SqfliteExamplePageState extends State<SqfliteExamplePage> {
  String _selectedTable = 'users';
  String _selectedSelectorType = 'Pick';

  String responseData = '';
  String fixtureInfo = '';
  String errorText = '';

  /// Creates a DatabaseAdapter configured with current settings.
  ///
  /// The key benefit of DatabaseAdapter is that you can swap implementations:
  /// - In development/testing: use FixtureDatabaseAdapter (returns mock data)
  /// - In production: use RealDatabaseAdapter (wraps real sqflite Database)
  ///
  /// Your repository/DAO code stays the same!
  DatabaseAdapter _createDatabase() {
    // Use FixtureDatabaseAdapter for development
    return FixtureDatabaseAdapter(
      dataQuery: SqfliteDataQuery(),
      dataSelector: _getDataSelectorType(),
      dataSelectorView: FixturesDialogView(
        context: widget.navigatorKey.currentContext!,
      ),
      delay: DataSelectorDelay.fast,
    );

    // In production, you would use:
    // return RealDatabaseAdapter(await openDatabase('app.db'));
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
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  Future<void> _queryDatabase() async {
    setState(() {
      responseData = '';
      fixtureInfo = '';
      errorText = '';
    });

    try {
      // Create a fixture database - works just like sqflite's Database!
      final db = _createDatabase();

      // Query the database using sqflite-like API
      // This is exactly how you'd query a real sqflite database:
      //   final rows = await db.query('users');
      final rows = await db.query(_selectedTable);

      setState(() {
        fixtureInfo =
            'db.query(\'$_selectedTable\')\nReturned ${rows.length} rows';
        responseData = _prettifyJson(rows);
      });
    } catch (e) {
      setState(() {
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
            // Info box
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DatabaseAdapter - Runtime Swappable',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'DatabaseAdapter provides a common interface for both real and fixture databases:',
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• FixtureDatabaseAdapter → mock data\n'
                    '• RealDatabaseAdapter → real sqflite\n'
                    '• Same API: query, insert, update, delete',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Inject DatabaseAdapter in your repos - swap at runtime!',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector Type
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
            const SizedBox(height: 16),

            // Table Selection
            const Text(
              'Database Table:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedTable,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'users', child: Text('users')),
                DropdownMenuItem(value: 'products', child: Text('products')),
                DropdownMenuItem(value: 'orders', child: Text('orders')),
              ],
              onChanged: (v) => setState(() => _selectedTable = v ?? 'users'),
            ),
            const SizedBox(height: 24),

            // Query Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _queryDatabase,
                icon: const Icon(Icons.storage),
                label: const Text('Query Database'),
              ),
            ),
            const SizedBox(height: 24),

            // Error Display
            if (errorText.isNotEmpty) ...[
              const Text(
                'Error:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
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

            // Results Display
            if (responseData.isNotEmpty) ...[
              const Text(
                'Query Result:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fixtureInfo.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fixtureInfo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
