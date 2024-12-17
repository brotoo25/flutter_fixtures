import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/data/dio_data_query.dart';
import 'package:flutter_fixtures/domain/data_query.dart';
import 'package:flutter_fixtures/domain/data_selector_type.dart';
import 'package:flutter_fixtures/domain/data_selector_view.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fixtures',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      home: const MyHomePage(title: 'Flutter Fixtures Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String responseCode = "";
  String responseData = "";

  late Dio dio;
  late DataQuery dataQuery;
  late DataSelectorView dataSelectorView;

  _MyHomePageState() {
    dio = Dio(BaseOptions(baseUrl: 'https://abraaolima.dev'));
    dio.interceptors.add(
      FixturesInterceptor(
        dataQuery: DioDataQuery(),
        dataSelectorView: FixturesDialogView(
          context: MyApp.navigatorKey.currentContext!,
        ),
        dataSelector: DataSelectorType.random(),
      ),
    );
  }

  Future<void> _makeRequest() async {
    final response = await dio.post(
      '/login',
      data: {'username': 'admin', 'password': '123456'},
    );

    setState(() {
      responseCode = response.statusCode.toString();
      responseData = response.data.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Data: $responseData',
            ),
            Text(
              'Response: $responseCode',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _makeRequest,
        tooltip: 'Make Request',
        child: const Icon(Icons.run_circle),
      ),
    );
  }
}
