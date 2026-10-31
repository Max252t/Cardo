sealed class Result<T, F> {
  const Result();

  bool get isSuccess => this is Success<T, F>;

  T? get valueOrNull => switch (this) {
    Success<T, F>(:final value) => value,
    Failure<T, F>() => null,
  };

  F? get failureOrNull => switch (this) {
    Success<T, F>() => null,
    Failure<T, F>(:final failure) => failure,
  };

  Result<R, F> map<R>(R Function(T value) transform) => switch (this) {
    Success<T, F>(:final value) => Success<R, F>(transform(value)),
    Failure<T, F>(:final failure) => Failure<R, F>(failure),
  };

  Result<T, F> mapFailure(F Function(F failure) transform) => switch (this) {
    Success<T, F>() => this,
    Failure<T, F>(:final failure) => Failure<T, F>(transform(failure)),
  };
}

final class Success<T, F> extends Result<T, F> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      other is Success<T, F> && other.value == value;

  @override
  int get hashCode => Object.hash(Success, value);

  @override
  String toString() => 'Success($value)';
}

final class Failure<T, F> extends Result<T, F> {
  const Failure(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      other is Failure<T, F> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Failure, failure);

  @override
  String toString() => 'Failure($failure)';
}
