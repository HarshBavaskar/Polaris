import 'help_request_api.dart';
import 'help_request_queue.dart';
import 'help_request.dart';

class HelpRequestSyncSummary {
  final int synced;
  final int failed;
  final int pending;

  const HelpRequestSyncSummary({
    required this.synced,
    required this.failed,
    required this.pending,
  });
}

class HelpRequestSyncService {
  final HelpRequestApi api;
  final HelpRequestQueue queue;

  const HelpRequestSyncService({required this.api, required this.queue});

  Future<HelpRequestSyncSummary> syncPending() async {
    final List<HelpRequest> pending = await queue.pending();
    if (pending.isEmpty) {
      return const HelpRequestSyncSummary(synced: 0, failed: 0, pending: 0);
    }

    int synced = 0;
    int failed = 0;
    final List<HelpRequest> remaining = <HelpRequest>[];
    for (final HelpRequest request in pending) {
      try {
        await api.submitHelpRequest(request);
        synced += 1;
      } on HelpRequestHttpException {
        failed += 1;
      } catch (_) {
        remaining.add(request);
      }
    }

    await queue.replace(remaining);
    return HelpRequestSyncSummary(
      synced: synced,
      failed: failed,
      pending: remaining.length,
    );
  }
}
