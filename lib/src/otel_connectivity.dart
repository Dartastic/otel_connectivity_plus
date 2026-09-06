// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'connectivity_suppression.dart';
import 'otel_guard.dart';

const _tracerName = 'otel_connectivity_plus';

/// Event name for connectivity transitions.
///
/// The OTel registry has no connectivity-change event yet; this name
/// is a SIG-proposal candidate, chosen to sit beside the registry's
/// `network.*` attribute namespace. The *attribute* on the event is
/// pure registry semconv.
const String connectivityChangeEventName = 'network.connectivity_change';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Maps connectivity_plus results onto the registry
/// `network.connection.type` value set (`wifi` / `wired` / `cell` /
/// `unavailable` / `unknown`) — the raw connectivity_plus names
/// (`mobile`, `ethernet`, `none`, ...) are NOT registry values.
///
/// connectivity_plus reports a *list* of active transports while the
/// registry attribute is a single value, so the primary transport is
/// chosen in fixed priority order: wifi > wired > cell. `vpn`,
/// `bluetooth`, and `other` have no registry value; when nothing
/// mappable is active they collapse to `unknown` (a VPN rides on one
/// of the physical transports anyway — when the physical transport
/// is also reported, that wins).
String _primaryConnectionType(List<ConnectivityResult> results) {
  if (results.isEmpty || results.contains(ConnectivityResult.none)) {
    return NetworkConnectionType.unavailable.value;
  }
  if (results.contains(ConnectivityResult.wifi)) {
    return NetworkConnectionType.wifi.value;
  }
  if (results.contains(ConnectivityResult.ethernet)) {
    return NetworkConnectionType.wired.value;
  }
  if (results.contains(ConnectivityResult.mobile)) {
    return NetworkConnectionType.cell.value;
  }
  return NetworkConnectionType.unknown.value;
}

/// Records the [results] of a connectivity check as an event named
/// [connectivityChangeEventName] on the active span, with the
/// registry attribute `network.connection.type` carrying the primary
/// transport mapped onto the registry value set (see
/// [_primaryConnectionType] for the mapping).
///
/// If no span is active, the event is dropped (no orphan spans
/// are created — connectivity changes are a poor span shape).
///
/// Never throws: an uninitialized OTel SDK drops the event instead of
/// propagating out of whatever the caller was doing (typically an
/// `onConnectivityChanged` listener).
void recordConnectivityResults(List<ConnectivityResult> results) {
  if (connectivityInstrumentationSuppressed()) return;
  final activeSpan = Context.current.span;
  if (activeSpan == null || !activeSpan.isValid) return;
  tryTelemetryEffect(() {
    activeSpan.addEventNow(
      connectivityChangeEventName,
      OTel.attributesFromMap(<String, Object>{
        Network.networkConnectionType.key: _primaryConnectionType(results),
      }),
    );
  });
}

/// Subscribes to [Connectivity.onConnectivityChanged] and emits an
/// event on the active span for every emission. Returns the
/// underlying [StreamSubscription] so callers can cancel it.
///
/// The subscription is instrumentation-only, so a stream error is
/// absorbed here rather than being reported as an unhandled error by
/// the surrounding zone.
StreamSubscription<List<ConnectivityResult>> listenConnectivityTraced({
  Connectivity? connectivity,
}) {
  final c = connectivity ?? Connectivity();
  return c.onConnectivityChanged.listen(
    recordConnectivityResults,
    onError: (Object _, StackTrace __) {},
  );
}

/// Traced one-shot connectivity check. Opens a CLIENT span
/// recording the result as `network.connection.type`.
///
/// The connectivity check itself always runs. When the OTel SDK is not
/// initialized the span is skipped and the raw
/// `Connectivity.checkConnectivity()` result is returned — telemetry
/// never decides whether the app gets to know its network state.
Future<List<ConnectivityResult>> tracedCheckConnectivity({
  Connectivity? connectivity,
}) async {
  final c = connectivity ?? Connectivity();
  if (connectivityInstrumentationSuppressed()) {
    return c.checkConnectivity();
  }
  final span = tryTelemetry(
    () => _tracer().startSpan(
      'connectivity.check',
      kind: SpanKind.client,
    ),
  );
  if (span == null) return c.checkConnectivity();
  try {
    final results = await c.checkConnectivity();
    tryTelemetryEffect(() {
      span.addAttributes(OTel.attributes([
        OTel.attributeString(
          Network.networkConnectionType.key,
          _primaryConnectionType(results),
        ),
      ]));
    });
    return results;
  } catch (e, st) {
    tryTelemetryEffect(() {
      span
        ..recordException(e, stackTrace: st)
        ..setStatus(SpanStatusCode.Error, e.toString());
    });
    rethrow;
  } finally {
    tryTelemetryEffect(span.end);
  }
}
