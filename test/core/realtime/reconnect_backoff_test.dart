import 'dart:math' as math;

import 'package:cardo/core/realtime/realtime_policy.dart';
import 'package:cardo/core/realtime/reconnect_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_random.dart';

void main() {
  group('reconnectDelay with the middle of the jitter range', () {
    final middle = FixedRandom(0.5);

    test('follows 0.5 s * 2^n up to the 30 s cap', () {
      final delays = [
        for (var attempt = 0; attempt <= 8; attempt++)
          reconnectDelay(attempt, middle).inMilliseconds,
      ];

      expect(delays, [500, 1000, 2000, 4000, 8000, 16000, 30000, 30000, 30000]);
    });

    test('a huge attempt counter stays at the cap and does not overflow', () {
      expect(reconnectDelay(1000, middle), const Duration(seconds: 30));
      expect(reconnectDelay(64, middle), const Duration(seconds: 30));
      expect(reconnectDelay(16, middle), const Duration(seconds: 30));
    });
  });

  group('jitter boundaries are plus and minus 20 percent', () {
    test('the lowest random value gives 80 percent', () {
      final low = FixedRandom(0);

      expect(reconnectDelay(0, low).inMilliseconds, 400);
      expect(reconnectDelay(1, low).inMilliseconds, 800);
      expect(reconnectDelay(3, low).inMilliseconds, 3200);
      expect(reconnectDelay(10, low).inMilliseconds, 24000);
    });

    test('the highest random value gives 120 percent', () {
      final high = FixedRandom(1);

      expect(reconnectDelay(0, high).inMilliseconds, 600);
      expect(reconnectDelay(1, high).inMilliseconds, 1200);
      expect(reconnectDelay(3, high).inMilliseconds, 4800);
      expect(reconnectDelay(10, high).inMilliseconds, 36000);
    });

    test('the cap itself is jittered, so the maximum is 36 s', () {
      expect(reconnectDelay(6, FixedRandom(1)), const Duration(seconds: 36));
      expect(reconnectDelay(6, FixedRandom(0)), const Duration(seconds: 24));
    });

    test('every delay stays inside the plus/minus 20 percent band', () {
      final random = math.Random(31);
      for (var attempt = 0; attempt < 20; attempt++) {
        final base = math.min(500 * (1 << math.min(attempt, 16)), 30000);
        for (var i = 0; i < 50; i++) {
          final ms = reconnectDelay(attempt, random).inMilliseconds;
          expect(ms, inInclusiveRange(base * 0.8 - 1, base * 1.2 + 1));
        }
      }
    });

    test('the delay grows with the attempt before the cap', () {
      final fixed = FixedRandom(0.25);
      var previous = Duration.zero;
      for (var attempt = 0; attempt <= 5; attempt++) {
        final delay = reconnectDelay(attempt, fixed);
        expect(delay, greaterThan(previous));
        previous = delay;
      }
    });
  });

  group('minimum for the abuse backoff', () {
    test('4008 never waits less than 30 s even at the lowest jitter', () {
      final delay = reconnectDelay(
        0,
        FixedRandom(0),
        minimum: RealtimePolicy.abuseBackoff,
      );

      expect(delay, const Duration(seconds: 30));
    });

    test('a larger computed delay is kept above the minimum', () {
      final delay = reconnectDelay(
        6,
        FixedRandom(1),
        minimum: RealtimePolicy.abuseBackoff,
      );

      expect(delay, const Duration(seconds: 36));
    });

    test('the default minimum does not raise anything', () {
      expect(
        reconnectDelay(0, FixedRandom(0)),
        const Duration(milliseconds: 400),
      );
    });
  });

  group('countdownSeconds', () {
    test('rounds up to whole seconds', () {
      expect(countdownSeconds(const Duration(milliseconds: 1)), 1);
      expect(countdownSeconds(const Duration(milliseconds: 400)), 1);
      expect(countdownSeconds(const Duration(milliseconds: 999)), 1);
      expect(countdownSeconds(const Duration(milliseconds: 1000)), 1);
      expect(countdownSeconds(const Duration(milliseconds: 1001)), 2);
      expect(countdownSeconds(const Duration(milliseconds: 29500)), 30);
      expect(countdownSeconds(const Duration(seconds: 36)), 36);
    });

    test('zero and negative delays count as zero', () {
      expect(countdownSeconds(Duration.zero), 0);
      expect(countdownSeconds(const Duration(milliseconds: -5)), 0);
    });
  });

  group('policy constants', () {
    test('match the README numbers', () {
      expect(RealtimePolicy.gapWait, const Duration(seconds: 1));
      expect(RealtimePolicy.readyTimeout, const Duration(seconds: 30));
      expect(RealtimePolicy.refreshAckTimeout, const Duration(seconds: 15));
      expect(RealtimePolicy.tokenRefreshLeeway, const Duration(seconds: 60));
      expect(RealtimePolicy.backoffBase, const Duration(milliseconds: 500));
      expect(RealtimePolicy.backoffMax, const Duration(seconds: 30));
      expect(RealtimePolicy.abuseBackoff, const Duration(seconds: 30));
      expect(RealtimePolicy.pendingMaxAge, const Duration(hours: 24));
      expect(RealtimePolicy.backoffJitter, 0.2);
      expect(RealtimePolicy.maxMessageBytes, 65536);
      expect(RealtimePolicy.protocolVersion, 1);
    });
  });
}
