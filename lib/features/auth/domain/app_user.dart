import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';

enum TemperatureUnit {
  fahrenheit('F'),
  celsius('C');

  const TemperatureUnit(this.wire);
  final String wire;

  static TemperatureUnit fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => TemperatureUnit.fahrenheit,
  );
}

enum DistanceUnit {
  imperial('imperial'),
  metric('metric');

  const DistanceUnit(this.wire);
  final String wire;

  static DistanceUnit fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => DistanceUnit.imperial,
  );
}

enum VolumeUnit {
  usCustomary('us_customary'),
  metric('metric');

  const VolumeUnit(this.wire);
  final String wire;

  static VolumeUnit fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => VolumeUnit.usCustomary,
  );
}

/// Where the user gardens. Drives hardiness and, later, weather lookups.
class HomeLocation {
  const HomeLocation({
    this.countryCode,
    this.state,
    this.city,
    this.postalCode,
    this.hardinessZone,
    this.timezone,
  });

  final String? countryCode;
  final String? state;
  final String? city;
  final String? postalCode;
  final String? hardinessZone;

  /// IANA zone name. The reminder sweep needs this to honour quiet hours.
  final String? timezone;

  factory HomeLocation.fromMap(Map<String, dynamic> map) => HomeLocation(
    countryCode: FirestoreValue.text(map['countryCode']),
    state: FirestoreValue.text(map['state']),
    city: FirestoreValue.text(map['city']),
    postalCode: FirestoreValue.text(map['postalCode']),
    hardinessZone: FirestoreValue.text(map['hardinessZone']),
    timezone: FirestoreValue.text(map['timezone']),
  );

  Map<String, Object?> toMap() => {
    'countryCode': countryCode,
    'state': state,
    'city': city,
    'postalCode': postalCode,
    'hardinessZone': hardinessZone,
    'timezone': timezone,
  };
}

class MeasurementPreferences {
  const MeasurementPreferences({
    this.temperature = TemperatureUnit.fahrenheit,
    this.distance = DistanceUnit.imperial,
    this.volume = VolumeUnit.usCustomary,
  });

  final TemperatureUnit temperature;
  final DistanceUnit distance;
  final VolumeUnit volume;

  factory MeasurementPreferences.fromMap(Map<String, dynamic> map) =>
      MeasurementPreferences(
        temperature: TemperatureUnit.fromWire(map['temperature']),
        distance: DistanceUnit.fromWire(map['distance']),
        volume: VolumeUnit.fromWire(map['volume']),
      );

  Map<String, Object?> toMap() => {
    'temperature': temperature.wire,
    'distance': distance.wire,
    'volume': volume.wire,
  };
}

/// Local-time window when push notifications are suppressed.
class QuietHours {
  const QuietHours({this.start = '21:00', this.end = '08:00'});

  /// 24-hour `HH:mm`.
  final String start;
  final String end;

  factory QuietHours.fromMap(Map<String, dynamic> map) => QuietHours(
    start: FirestoreValue.text(map['start']) ?? '21:00',
    end: FirestoreValue.text(map['end']) ?? '08:00',
  );

  Map<String, Object?> toMap() => {'start': start, 'end': end};
}

class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.quietHours = const QuietHours(),
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final QuietHours quietHours;

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) =>
      NotificationPreferences(
        pushEnabled: FirestoreValue.boolean(map['pushEnabled'], fallback: true),
        emailEnabled: FirestoreValue.boolean(map['emailEnabled']),
        quietHours: QuietHours.fromMap(FirestoreValue.map(map['quietHours'])),
      );

  Map<String, Object?> toMap() => {
    'pushEnabled': pushEnabled,
    'emailEnabled': emailEnabled,
    'quietHours': quietHours.toMap(),
  };
}

/// The profile document at /users/{uid}.
class AppUser {
  const AppUser({
    required this.id,
    this.displayName,
    this.email,
    this.homeLocation = const HomeLocation(),
    this.units = const MeasurementPreferences(),
    this.notificationPreferences = const NotificationPreferences(),
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayName;
  final String? email;
  final HomeLocation homeLocation;
  final MeasurementPreferences units;
  final NotificationPreferences notificationPreferences;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AppUser(
      id: snapshot.id,
      displayName: FirestoreValue.text(data['displayName']),
      email: FirestoreValue.text(data['email']),
      homeLocation: HomeLocation.fromMap(
        FirestoreValue.map(data['homeLocation']),
      ),
      units: MeasurementPreferences.fromMap(FirestoreValue.map(data['units'])),
      notificationPreferences: NotificationPreferences.fromMap(
        FirestoreValue.map(data['notificationPreferences']),
      ),
      createdAt: FirestoreValue.dateTime(data['createdAt']),
      updatedAt: FirestoreValue.dateTime(data['updatedAt']),
    );
  }

  /// onUserCreated fills in anything omitted here, so a sign-up only has to
  /// send what it actually knows.
  Map<String, Object?> toCreateJson() => {
    'displayName': displayName,
    'email': email,
    'homeLocation': homeLocation.toMap(),
    'units': units.toMap(),
    'notificationPreferences': notificationPreferences.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };

  Map<String, Object?> toUpdateJson() => withoutNulls({
    'displayName': displayName,
    'email': email,
    'homeLocation': homeLocation.toMap(),
    'units': units.toMap(),
    'notificationPreferences': notificationPreferences.toMap(),
  })..addAll({
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  });

  AppUser copyWith({
    String? displayName,
    String? email,
    HomeLocation? homeLocation,
    MeasurementPreferences? units,
    NotificationPreferences? notificationPreferences,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      homeLocation: homeLocation ?? this.homeLocation,
      units: units ?? this.units,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
