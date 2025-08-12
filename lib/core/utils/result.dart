import 'package:kurani_fisnik_app/core/error/failures.dart';

sealed class Result<T> {
  const Result();
  R when<R>({required R Function(T) success, required R Function(Failure) failure}) =>
      switch (this) { Success<T>(value: final v) => success(v), FailureResult<T>(failure: final f) => failure(f) };
  bool get isSuccess => this is Success<T>;
  T? get data => this is Success<T> ? (this as Success<T>).value : null;
  Failure? get error => this is FailureResult<T> ? (this as FailureResult<T>).failure : null;
}

class Success<T> extends Result<T> { final T value; const Success(this.value); }
class FailureResult<T> extends Result<T> { final Failure failure; const FailureResult(this.failure); }

extension ResultX<T> on Result<T> {
  T get orThrow => switch (this) { Success<T>(value: final v) => v, FailureResult<T>(failure: final f) => throw f };
}
