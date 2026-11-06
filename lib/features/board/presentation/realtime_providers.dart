import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/scheduler.dart';
import '../data/realtime/realtime_transport.dart';
import '../data/realtime/realtime_transport_factory.dart';

final realtimeTransportProvider = Provider<RealtimeTransport>(
  (ref) => createRealtimeTransport(),
);

final realtimeSchedulerProvider = Provider<Scheduler>(
  (ref) => const SystemScheduler(),
);

final realtimeRandomProvider = Provider<math.Random>((ref) => math.Random());
