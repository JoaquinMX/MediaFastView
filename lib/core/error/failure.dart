/// Base class for domain layer failures.
/// Represents business logic errors that can occur during operations.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Failure when a requested resource is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Failure due to validation errors in business logic.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Failure due to external service or dependency issues.
class ServiceFailure extends Failure {
  const ServiceFailure(super.message);
}

/// Failure due to network or connectivity issues.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Failure for unexpected errors in domain operations.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
