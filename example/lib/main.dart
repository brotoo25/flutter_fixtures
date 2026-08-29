import 'package:flutter/material.dart';

import 'advanced_example.dart';
import 'basic_example.dart';
import 'recorder_example.dart';
import 'sqflite_example.dart';

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
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Flutter Fixtures Example'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Basic'),
                Tab(text: 'Advanced'),
                Tab(text: 'SQLite'),
                Tab(text: 'Recorder'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              BasicExamplePage(navigatorKey: MyApp.navigatorKey),
              AdvancedExamplePage(navigatorKey: MyApp.navigatorKey),
              SqfliteExamplePage(navigatorKey: MyApp.navigatorKey),
              RecorderExamplePage(navigatorKey: MyApp.navigatorKey),
            ],
          ),
        ),
      ),
    );
  }
}
