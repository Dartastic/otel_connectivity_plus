// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otel_connectivity_plus/otel_connectivity_plus.dart';

class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recordConnectivityResults', () {
    late _MemorySpanExporter exporter;

    setUp(() async {
      await OTel.reset();
      exporter = _MemorySpanExporter();
      await OTel.initialize(
        serviceName: 'connectivity-otel-test',
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(exporter),
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('adds network.connectivity_change event to active span', () async {
      await OTel.tracer().startActiveSpanAsync<void>(
        name: 'app',
        fn: (_) async {
          recordConnectivityResults([
            ConnectivityResult.wifi,
            ConnectivityResult.mobile,
          ]);
        },
      );

      final span = exporter.spans.firstWhere((s) => s.name == 'app');
      final events = span.spanEvents ?? [];
      final event = events.firstWhere(
        (e) => e.name == 'network.connectivity_change',
      );
      final attrs = {
        for (final a in (event.attributes?.toList() ?? <Attribute<Object>>[]))
          a.key: a.value,
      };
      expect(attrs['network.connection.type'], equals('wifi,mobile'));
    });

    test('no active span — event is dropped silently', () {
      // No startActiveSpan around this call.
      recordConnectivityResults([ConnectivityResult.wifi]);
      expect(exporter.spans, isEmpty);
    });

    test('runWithoutConnectivityInstrumentation bypasses', () async {
      await OTel.tracer().startActiveSpanAsync<void>(
        name: 'app',
        fn: (_) async {
          runWithoutConnectivityInstrumentation(() {
            recordConnectivityResults([ConnectivityResult.wifi]);
          });
        },
      );

      final span = exporter.spans.firstWhere((s) => s.name == 'app');
      final events = span.spanEvents ?? [];
      expect(
        events.any((e) => e.name == 'network.connectivity_change'),
        isFalse,
      );
    });
  });
}
