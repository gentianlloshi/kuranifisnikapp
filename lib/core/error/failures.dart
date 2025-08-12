abstract class Failure {
  final String message;
  final StackTrace? stackTrace;
  const Failure(this.message, {this.stackTrace});
  @override
  String toString() => '${runtimeType.toString()}: $message';
}

class ParseFailure extends Failure {
  const ParseFailure(String message, {StackTrace? stackTrace}) : super(message, stackTrace: stackTrace);
}

class CacheFailure extends Failure {
  const CacheFailure(String message, {StackTrace? stackTrace}) : super(message, stackTrace: stackTrace);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {StackTrace? stackTrace}) : super(message, stackTrace: stackTrace);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(String message, {StackTrace? stackTrace}) : super(message, stackTrace: stackTrace);
}

class UnknownFailure extends Failure {
  const UnknownFailure(String message, {StackTrace? stackTrace}) : super(message, stackTrace: stackTrace);
}

Failure mapError(Object error, StackTrace st) {
  final msg = error.toString();
  if (msg.contains('FormatException')) return ParseFailure(msg, stackTrace: st);
  return UnknownFailure(msg, stackTrace: st);
}
