# otel_connectivity_plus example

```dart
// example/lib/main.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter/material.dart';
import 'package:otel_connectivity_plus/otel_connectivity_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Bring up OTel before runApp so trace context is already
  //    flowing when the first widget builds.
  await OTel.initialize(
    serviceName: 'connectivity-demo',
  );

  // 2. One long-lived listener for the whole app: every
  //    connectivity transition becomes a `network.connectivity_change`
  //    event on whatever span is active at that moment — "user lost
  //    wifi in the middle of checkout" lands inside the checkout
  //    trace, exactly where you want it.
  final sub = listenConnectivityTraced();

  runApp(const MyApp());

  // (on shutdown) sub.cancel();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _checkNow(BuildContext context) async {
    // ✨ Span: `connectivity.check` (CLIENT)
    //
    //    One-shot check that records the registry
    //    `network.connection.type` value (`wifi` / `wired` / `cell` /
    //    `unavailable` / `unknown`) on its own span.
    final results = await tracedCheckConnectivity();

    if (results.contains(ConnectivityResult.none) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are offline')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _checkNow(context),
          child: const Text('Check connectivity'),
        ),
      ),
    );
  }
}
```

## Trace shape

```
POST /checkout                       (your span)
  network.connectivity_change        (event on the active span)
    network.connection.type: cell    (wifi dropped mid-request)

connectivity.check                   (CLIENT span, one-shot check)
  network.connection.type: wifi
```

Connectivity changes are intentionally **events on the active span**,
not standalone spans. The low-level helper
`recordConnectivityResults(results)` is available when you already
hold results; `runWithoutConnectivityInstrumentation` /
`...Async` suppress the instrumentation for a scoped block.
