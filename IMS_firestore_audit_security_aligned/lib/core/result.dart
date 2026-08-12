sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
  });
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
  }) => success(value);
}

class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
  }) => failure(error, stackTrace);
}
