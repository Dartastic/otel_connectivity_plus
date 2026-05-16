# Changelog

## [0.1.0-beta.1-wip]

### Added

- `recordConnectivityResults(results)` — records a
  `network.connectivity_change` event on the active span with
  `network.connection.type` listing active connectivity types.
- `listenConnectivityTraced(...)` — subscribes to
  `Connectivity.onConnectivityChanged` and emits events on the
  active span per change. Returns the StreamSubscription.
- `tracedCheckConnectivity()` — one-shot check that opens a
  CLIENT span recording the result.
- Zone-scoped suppression
  (`runWithoutConnectivityInstrumentation` / async variant).
- 3 tests covering active-span event recording, the no-span
  graceful path, and suppression scope.
