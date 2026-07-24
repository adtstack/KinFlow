sealed class FoundationFailure {
  const FoundationFailure({required this.code});

  final String code;
}

final class InvalidFoundationPayload extends FoundationFailure {
  const InvalidFoundationPayload() : super(code: 'foundation.invalid_payload');
}

final class FoundationUnavailable extends FoundationFailure {
  const FoundationUnavailable() : super(code: 'foundation.unavailable');
}
