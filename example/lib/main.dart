import 'package:flutter/material.dart';

import 'basic_example.dart';
import 'advanced_example.dart';

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
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Flutter Fixtures Example'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Basic'),
                Tab(text: 'Advanced'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              BasicExamplePage(navigatorKey: MyApp.navigatorKey),
              AdvancedExamplePage(navigatorKey: MyApp.navigatorKey),
            ],
          ),
        ),
      ),
    );
  }
}
