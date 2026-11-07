// lib/core/models/supabase_snapshot.dart

class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// Lightweight timestamp compatible with code that expects `.toDate()`.
class AppTimestamp {
  final DateTime dateTime;

  AppTimestamp(this.dateTime);

  factory AppTimestamp.fromDate(DateTime dt) => AppTimestamp(dt);
  factory AppTimestamp.now() => AppTimestamp(DateTime.now());

  static AppTimestamp? tryFromValue(dynamic val) {
    if (val == null) return null;
    if (val is AppTimestamp) return val;
    if (val is DateTime) return AppTimestamp(val);
    if (val is int) {
      // Distinguish seconds vs milliseconds epoch
      final ms = val < 10000000000 ? val * 1000 : val;
      return AppTimestamp(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    if (val is num) {
      final intVal = val.toInt();
      final ms = intVal < 10000000000 ? intVal * 1000 : intVal;
      return AppTimestamp(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    if (val is String && val.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(val.trim());
      if (parsed != null) return AppTimestamp(parsed.toLocal());
    }
    return null;
  }

  factory AppTimestamp.fromValue(dynamic val) {
    return tryFromValue(val) ?? AppTimestamp(DateTime.now());
  }

  DateTime toDate() => dateTime;

  int get millisecondsSinceEpoch => dateTime.millisecondsSinceEpoch;

  @override
  String toString() => dateTime.toIso8601String();
}

typedef Timestamp = AppTimestamp;

/// Lightweight document snapshot compatible with Firestore `.data()`, `['key']`, and `.id`.
class AppDocSnapshot {
  final String id;
  final Map<String, dynamic> _data;
  final bool exists;

  AppDocSnapshot(this.id, Map<String, dynamic>? data)
      : _data = data != null ? Map<String, dynamic>.from(data) : {},
        exists = data != null;

  Map<String, dynamic> data() => _data;

  dynamic operator [](String key) => _data[key];

  bool containsKey(String key) => _data.containsKey(key);
}

typedef DocumentSnapshot<T> = AppDocSnapshot;
typedef QueryDocumentSnapshot<T> = AppDocSnapshot;

/// Lightweight query snapshot compatible with Firestore `.docs`.
class AppQuerySnapshot {
  final List<AppDocSnapshot> docs;

  AppQuerySnapshot(this.docs);

  int get size => docs.length;
  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
}

typedef QuerySnapshot<T> = AppQuerySnapshot;
