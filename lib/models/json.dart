/// DRF serializes DecimalFields as strings ("12.345678"), so every numeric
/// field is parsed leniently.
double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? asString(dynamic value) => value?.toString();

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<T> asList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  // Growable: callers sort the result in place.
  if (value is! List) return <T>[];
  return value.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
}
