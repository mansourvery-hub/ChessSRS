/// Clock abstraction for injectable time source in SRS tests.
abstract class Clock {
  DateTime now();
}

/// System clock implementation.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Fixed clock for testing.
class FixedClock implements Clock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}