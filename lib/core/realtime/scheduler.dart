import 'dart:async';

abstract interface class Scheduler {
  Timer after(Duration delay, void Function() callback);

  Timer every(Duration period, void Function() callback);
}

class SystemScheduler implements Scheduler {
  const SystemScheduler();

  @override
  Timer after(Duration delay, void Function() callback) =>
      Timer(delay, callback);

  @override
  Timer every(Duration period, void Function() callback) =>
      Timer.periodic(period, (_) => callback());
}
