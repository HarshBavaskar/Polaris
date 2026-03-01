import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/help/help_request.dart';
import 'package:polaris_citizen/features/help/help_request_api.dart';
import 'package:polaris_citizen/features/help/help_request_queue.dart';
import 'package:polaris_citizen/features/help/help_request_tracking_store.dart';
import 'package:polaris_citizen/features/help/request_help_screen.dart';

class _FakeHelpRequestApi implements HelpRequestApi {
  bool failWithGenericError = false;
  int submitCalls = 0;

  @override
  Future<HelpRequestSubmitResult> submitHelpRequest(HelpRequest request) async {
    submitCalls += 1;
    if (failWithGenericError) {
      throw Exception('offline');
    }
    return HelpRequestSubmitResult(
      serverRequestId: 'REQ-$submitCalls',
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<String?> fetchRequestStatus(String requestId) async {
    return 'OPEN';
  }
}

class _MemoryHelpQueue implements HelpRequestQueue {
  final List<HelpRequest> requests = <HelpRequest>[];

  @override
  Future<void> enqueue(HelpRequest request) async {
    requests.add(request);
  }

  @override
  Future<List<HelpRequest>> pending() async {
    return List<HelpRequest>.from(requests);
  }

  @override
  Future<void> replace(List<HelpRequest> next) async {
    requests
      ..clear()
      ..addAll(next);
  }
}

class _MemoryTrackingStore implements HelpRequestTrackingStore {
  final List<TrackedHelpRequest> _tracked = <TrackedHelpRequest>[];

  @override
  Future<List<TrackedHelpRequest>> list() async {
    return List<TrackedHelpRequest>.from(_tracked);
  }

  @override
  Future<void> upsert(TrackedHelpRequest tracked) async {
    final int index = _tracked.indexWhere(
      (TrackedHelpRequest t) => t.localId == tracked.localId,
    );
    if (index >= 0) {
      _tracked[index] = tracked;
    } else {
      _tracked.insert(0, tracked);
    }
  }
}

Widget _buildScreen({
  required HelpRequestApi api,
  required HelpRequestQueue queue,
  required HelpRequestTrackingStore trackingStore,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RequestHelpScreen(
        api: api,
        queue: queue,
        trackingStore: trackingStore,
      ),
    ),
  );
}

void main() {
  testWidgets('queues offline help request and syncs from pending queue', (
    WidgetTester tester,
  ) async {
    final _FakeHelpRequestApi api = _FakeHelpRequestApi()
      ..failWithGenericError = true;
    final _MemoryHelpQueue queue = _MemoryHelpQueue();
    final _MemoryTrackingStore trackingStore = _MemoryTrackingStore();

    await tester.pumpWidget(
      _buildScreen(api: api, queue: queue, trackingStore: trackingStore),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('help-contact-input')),
      '9876543210',
    );
    await tester.tap(find.byKey(const Key('help-submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('saved offline'), findsOneWidget);
    expect(queue.requests.length, 1);
    expect(find.textContaining('Pending requests: 1'), findsOneWidget);

    api.failWithGenericError = false;
    await tester.tap(find.byKey(const Key('help-sync-pending-button')));
    await tester.pumpAndSettle();

    expect(queue.requests, isEmpty);
    expect(find.textContaining('Pending requests: 0'), findsOneWidget);
    expect(api.submitCalls, 2);
  });
}
