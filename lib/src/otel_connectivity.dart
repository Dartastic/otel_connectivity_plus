// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'connectivity_suppression.dart';

const _tracerName = 'otel_connectivity_plus';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

String _resultsToString(List<ConnectivityResult> results) {
  if (results.isEmpty) return 'none';
  return results.map((r) => r.name).join(',');
}

/// Records the [results] of a connectivity check as an event named
/// `network.connectivity_change` on the active span, with
/// `network.connection.type` carrying a comma-separated list of
/// active connectivity types.
///
/// If no span is active, the event is dropped (no orphan spans
/// are created — connectivity changes are a poor span shape).
void recordConnectivityResults(List<ConnectivityResult> results) {
  if (connectivityInstrumentationSuppressed()) return;
  final activeSpan = Context.current.span;
  if (activeSpan == null || !activeSpan.isValid) return;
  activeSpan.addEventNow(
    'network.connectivity_change',
    OTel.attributesFromMap(<String, Object>{
      'network.connection.type': _resultsToString(results),
    }),
  );
}

/// Subscribes to [Connectivity.onConnectivityChanged] and emits an
/// event on the active span for every emission. Returns the
/// underlying [StreamSubscription] so callers can cancel it.
StreamSubscription<List<ConnectivityResult>> listenConnectivityTraced({
  Connectivity? connectivity,
}) {
  final c = connectivity ?? Connectivity();
  return c.onConnectivityChanged.listen(recordConnectivityResults);
}

/// Traced one-shot connectivity check. Opens a CLIENT span
/// recording the result as `network.connection.type`.
Future<List<ConnectivityResult>> tracedCheckConnectivity({
  Connectivity? connectivity,
}) async {
  final c = connectivity ?? Connectivity();
  if (connectivityInstrumentationSuppressed()) {
    return c.checkConnectivity();
  }
  final span = _tracer().startSpan(
    'connectivity.check',
    kind: SpanKind.client,
  );
  try {
    final results = await c.checkConnectivity();
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        'network.connection.type',
        _resultsToString(results),
      ),
    ]));
    return results;
  } catch (e, st) {
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
