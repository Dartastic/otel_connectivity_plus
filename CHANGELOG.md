# Changelog

## [0.2.0] - 2026-08-08

### Changed

- `network.connection.type` now uses the upstream API's `Network`
  enum key and emits the registry value set (`wifi` / `wired` /
  `cell` / `unavailable` / `unknown`) instead of comma-joined raw
  connectivity_plus names (`wifi,mobile`, `ethernet`, `none`, ...),
  which were not registry-conformant. Mapping: `mobile`→`cell`,
  `ethernet`→`wired`, `none`/empty→`unavailable`,
  `vpn`/`bluetooth`/`other`→`unknown`; primary transport chosen
  wifi > wired > cell when several are active.
- The event name is exposed as the `connectivityChangeEventName`
  constant and documented as a SIG-proposal candidate (the registry
  has no connectivity-change event yet).
- Dependency floors raised to `dartastic_opentelemetry ^1.1.0-beta.12` and
  `dartastic_opentelemetry_api ^1.0.0-rc.1`. The previous floors declared
  compatibility with API versions that predate the semconv enums this
  package uses and could not actually resolve-and-compile.
- `repository` URL corrected to the canonical `Dartastic` org casing so
  pub.dev repository verification succeeds.

### Added

- `recordConnectivityResults(results)` — records a
  `network.connectivity_change` event on the active span with
  `network.connection.type` carrying the registry connection type.
- `listenConnectivityTraced(...)` — subscribes to
  `Connectivity.onConnectivityChanged` and emits events on the
  active span per change. Returns the StreamSubscription.
- `tracedCheckConnectivity()` — one-shot check that opens a
  CLIENT span recording the result.
- Zone-scoped suppression
  (`runWithoutConnectivityInstrumentation` / async variant).
- 4 tests covering active-span event recording, the registry value
  mapping, the no-span graceful path, and suppression scope.
