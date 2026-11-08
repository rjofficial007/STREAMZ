import 'dart:async';
import 'dart:collection';

/// Bounds concurrent work and the number of callers waiting for a slot.
class AsyncRequestSemaphore {
  AsyncRequestSemaphore({required this.maxConcurrent, this.maxQueued = 64})
    : assert(maxConcurrent > 0, 'maxConcurrent must be positive'),
      assert(maxQueued >= 0, 'maxQueued cannot be negative');

  final int maxConcurrent;
  final int maxQueued;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _active = 0;

  int get active => _active;
  int get queued => _waiters.length;

  Future<bool> acquire({required Duration timeout}) async {
    if (_active < maxConcurrent) {
      _active++;
      return true;
    }
    if (_waiters.length >= maxQueued) return false;

    final waiter = Completer<void>();
    _waiters.addLast(waiter);
    try {
      await waiter.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _waiters.remove(waiter);
      rethrow;
    }
  }

  void release() {
    if (_active == 0) throw StateError('No active request to release');

    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      if (waiter.isCompleted) continue;
      waiter.complete();
      return;
    }

    _active--;
  }
}
