/// The same invite credential is used in typed input, a QR code and a link.
final class HouseholdInviteCode {
  const HouseholdInviteCode._(this.value);

  static final _groupedCode = RegExp(
    r'^(?:[0-9A-HJKMNP-TV-Z]{12}|[0-9A-HJKMNP-TV-Z]{16})$',
  );
  static final _legacy = RegExp(r'^[0-9a-f]{64}$');

  static HouseholdInviteCode? parse(String input) {
    if (input.length > 80) return null;
    if (_legacy.hasMatch(input)) return HouseholdInviteCode._(input);
    final normalized = input.toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
    return _groupedCode.hasMatch(normalized)
        ? HouseholdInviteCode._(normalized)
        : null;
  }

  final String value;

  String get displayValue => [
    for (var offset = 0; offset < value.length; offset += 4)
      value.substring(offset, offset + 4),
  ].join('-');

  String get qrPayload => value;

  /// The browser delivers the credential as a fragment instead of a URL query.
  Uri shareUrl(Uri backend) => Uri(
    scheme: backend.scheme,
    host: backend.host,
    port: backend.hasPort ? backend.port : null,
    pathSegments: [
      ...backend.pathSegments.where((segment) => segment.isNotEmpty),
      'functions',
      'v1',
      'household-invite',
    ],
    fragment: value,
  );

  static HouseholdInviteCode? fromAppLink(Uri uri) {
    if (uri.scheme != 'tavli' ||
        uri.host != 'household' ||
        uri.path != '/join') {
      return null;
    }
    return parse(uri.fragment);
  }
}
