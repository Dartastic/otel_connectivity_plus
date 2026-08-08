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
adds a `network.connectivity_change` event with the registry
`network.connection.type` attribute to whatever span is currently
active.

## Registry value mapping

The registry defines `network.connection.type` as a single value
from `wifi` / `wired` / `cell` / `unavailable` / `unknown` — the
raw connectivity_plus names are not registry values. This package
maps them:

| connectivity_plus | emitted |
|---|---|
| `wifi` | `wifi` |
| `ethernet` | `wired` |
| `mobile` | `cell` |
| `none` (or empty list) | `unavailable` |
| `vpn` / `bluetooth` / `other` | `unknown` (no registry value) |

connectivity_plus reports a *list* of active transports; the
primary one is chosen wifi > wired > cell (a VPN rides on one of
the physical transports — when the physical transport is also
reported, it wins).

The event *name* `network.connectivity_change` is a SIG-proposal
candidate (the registry has no connectivity-change event yet); the
attribute on it is pure registry semconv.

Connectivity changes are intentionally **events on the active
span**, not standalone spans — a long-lived connectivity span
isn't meaningful, but a "user lost wifi in the middle of
checkout" event in the checkout trace is gold.

Suppression: `runWithoutConnectivityInstrumentation`.

## License

Apache 2.0
