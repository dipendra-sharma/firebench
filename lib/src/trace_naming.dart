const _maxTraceNameLength = 100;
const _maxAttributeValueLength = 100;

final _invalidNameChars = RegExp('[^A-Za-z0-9_]');

/// Builds a Firebase-safe trace name from [prefix] and [rawRouteName],
/// replacing invalid characters and clamping to the backend length limit.
String sanitizeTraceName(String prefix, String rawRouteName) {
  final sanitized = rawRouteName.replaceAll(_invalidNameChars, '_');
  final full = '$prefix$sanitized';
  if (full.length <= _maxTraceNameLength) return full;
  return full.substring(0, _maxTraceNameLength);
}

/// Clamps an attribute [value] to the backend's maximum length.
String clampAttribute(String value) {
  if (value.length <= _maxAttributeValueLength) return value;
  return value.substring(0, _maxAttributeValueLength);
}
