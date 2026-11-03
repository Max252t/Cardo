import 'dart:math' as math;

class FixedRandom implements math.Random {
  FixedRandom(this.value);

  double value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor();
}
