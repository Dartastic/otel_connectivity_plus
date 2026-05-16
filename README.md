# otel_connectivity_plus

OpenTelemetry instrumentation for
[`package:connectivity_plus`](https://pub.dev/packages/connectivity_plus).

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:otel_connectivity_plus/otel_connectivity_plus.dart';

// One-shot check (returns a CLIENT span)
final results = await tracedCheckConnectivity();

// Long-lived listener (adds an event to the active span on each change)
final sub = listenConnectivityTraced();
```

`recordConnectivityResults(results)` is the low-level helper —
adds a `network.connectivity_change` event with
`network.connection.type` (e.g. `wifi,mobile`) to whatever span
is currently active.

Connectivity changes are intentionally **events on the active
span**, not standalone spans — a long-lived connectivity span
isn't meaningful, but a "user lost wifi in the middle of
checkout" event in the checkout trace is gold.

Suppression: `runWithoutConnectivityInstrumentation`.

## License

Apache 2.0
