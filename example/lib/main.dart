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

  /// Fired by the app bar's clear action on the Recorder tab; the recorder
  /// page listens and clears its request log.
  static final ValueNotifier<int> recorderClearSignal = ValueNotifier(0);

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fixtures',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      home: DefaultTabController(
        length: 4,
        child: Builder(builder: (context) {
          final tabController = DefaultTabController.of(context);
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: const Text('Flutter Fixtures Example'),
              actions: [
                // Recorder-tab-only action: clear the request log.
                AnimatedBuilder(
                  animation: tabController,
                  builder: (context, _) => tabController.index == 3
                      ? IconButton(
                          tooltip: 'Clear request log',
                          icon: const Icon(Icons.delete_sweep_outlined),
                          onPressed: () => MyApp.recorderClearSignal.value++,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
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
                RecorderExamplePage(
                  navigatorKey: MyApp.navigatorKey,
                  clearSignal: MyApp.recorderClearSignal,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
