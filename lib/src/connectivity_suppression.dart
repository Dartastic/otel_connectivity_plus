// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

const Symbol _suppressKey = #otel_connectivity_plus_suppress;

/// Whether connectivity instrumentation is suppressed in the current
/// [Zone] (see [runWithoutConnectivityInstrumentation]).
bool connectivityInstrumentationSuppressed() {
  return Zone.current[_suppressKey] == true;
}

/// Runs [body] with connectivity instrumentation suppressed: no spans
/// are opened and no events are recorded for the duration of the call.
T runWithoutConnectivityInstrumentation<T>(T Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

/// Async variant of [runWithoutConnectivityInstrumentation].
Future<T> runWithoutConnectivityInstrumentationAsync<T>(
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}
