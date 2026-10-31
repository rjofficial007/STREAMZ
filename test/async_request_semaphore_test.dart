import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/data/network/async_request_semaphore.dart';

void main() {
  test('bounds active requests and queued callers', () async {
    final semaphore = AsyncRequestSemaphore(maxConcurrent: 1, maxQueued: 1);

    expect(
      await semaphore.acquire(timeout: const Duration(seconds: 1)),
      isTrue,
    );
    final queued = semaphore.acquire(timeout: const Duration(seconds: 1));
    expect(semaphore.active, 1);
    expect(semaphore.queued, 1);
    expect(
      await semaphore.acquire(timeout: const Duration(seconds: 1)),
      isFalse,
    );

    semaphore.release();
    expect(await queued, isTrue);
    expect(semaphore.active, 1);
    expect(semaphore.queued, 0);

    semaphore.release();
    expect(semaphore.active, 0);
  });

  test('a timed out waiter is removed without taking a later slot', () async {
    final semaphore = AsyncRequestSemaphore(maxConcurrent: 1, maxQueued: 1);
    await semaphore.acquire(timeout: const Duration(seconds: 1));

    await expectLater(
      semaphore.acquire(timeout: const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>()),
    );
    expect(semaphore.queued, 0);

    semaphore.release();
    expect(
      await semaphore.acquire(timeout: const Duration(seconds: 1)),
      isTrue,
    );
    semaphore.release();
  });
}
