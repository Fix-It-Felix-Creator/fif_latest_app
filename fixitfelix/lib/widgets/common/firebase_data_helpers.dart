/// Mixin providing common Firebase data conversion methods.
/// Used to convert Firebase data types to Dart types.
mixin FirebaseDataHelpersMixin {
  /// Convert dynamic map to `Map<String, dynamic>`.
  Map<String, dynamic> convertToStringDynamicMap(Map<dynamic, dynamic>? data) {
    if (data == null) return {};
    return data.map((key, value) {
      if (value is Map<dynamic, dynamic>) {
        return MapEntry(key.toString(), convertToStringDynamicMap(value));
      } else if (value is List) {
        return MapEntry(key.toString(), convertList(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  /// Convert list items if they contain maps.
  List<dynamic> convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<dynamic, dynamic>) {
        return convertToStringDynamicMap(item);
      } else if (item is List) {
        return convertList(item);
      }
      return item;
    }).toList();
  }
}

/// Static class for Firebase data conversion.
class FirebaseDataHelpers {
  FirebaseDataHelpers._();

  /// Convert dynamic map to `Map<String, dynamic>`.
  static Map<String, dynamic> toStringDynamicMap(Map<dynamic, dynamic>? data) {
    if (data == null) return {};
    return data.map((key, value) {
      if (value is Map<dynamic, dynamic>) {
        return MapEntry(key.toString(), toStringDynamicMap(value));
      } else if (value is List) {
        return MapEntry(key.toString(), _convertList(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  /// Convert list items if they contain maps.
  static List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<dynamic, dynamic>) {
        return toStringDynamicMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }
}
