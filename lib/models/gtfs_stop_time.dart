class GtfsStopTime {
  final String tripId;
  final String arrivalTime; // HH:MM:SS format (can exceed 24 hours)
  final String departureTime; // HH:MM:SS format (can exceed 24 hours)
  final String stopId;
  final int stopSequence;
  final String? stopHeadsign;
  final int? pickupType;
  final int? dropOffType;

  GtfsStopTime({
    required this.tripId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopId,
    required this.stopSequence,
    this.stopHeadsign,
    this.pickupType,
    this.dropOffType,
  });

  factory GtfsStopTime.fromCsvRow(List<dynamic> row, Map<String, int> headers) {
    String? getOptionalField(String field) {
      final idx = headers[field];
      if (idx != null && idx < row.length) {
        final value = row[idx].toString().trim();
        return value.isEmpty ? null : value;
      }
      return null;
    }

    int? getOptionalIntField(String field) {
      final value = getOptionalField(field);
      return value != null ? int.tryParse(value) : null;
    }

    return GtfsStopTime(
      tripId: row[headers['trip_id']!].toString().trim(),
      arrivalTime: row[headers['arrival_time']!].toString().trim(),
      departureTime: row[headers['departure_time']!].toString().trim(),
      stopId: row[headers['stop_id']!].toString().trim(),
      stopSequence: int.tryParse(row[headers['stop_sequence']!].toString()) ?? 0,
      stopHeadsign: getOptionalField('stop_headsign'),
      pickupType: getOptionalIntField('pickup_type'),
      dropOffType: getOptionalIntField('drop_off_type'),
    );
  }

  /// Convert GTFS time (HH:MM:SS, can exceed 24 hours) to DateTime for today
  DateTime? toDateTime() {
    try {
      final parts = departureTime.split(':');
      if (parts.length != 3) return null;

      int hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final seconds = int.parse(parts[2]);

      final now = DateTime.now();
      var dateTime = DateTime(now.year, now.month, now.day, 0, minutes, seconds);

      // Handle times that exceed 24 hours (e.g., 25:30:00 means 1:30 AM next day)
      if (hours >= 24) {
        dateTime = dateTime.add(Duration(days: hours ~/ 24, hours: hours % 24));
      } else {
        dateTime = dateTime.add(Duration(hours: hours));
      }

      return dateTime;
    } catch (e) {
      return null;
    }
  }

  /// Get a human-readable time string (e.g., "2:30 PM")
  String getFormattedTime() {
    try {
      final parts = departureTime.split(':');
      if (parts.length != 3) return departureTime;

      int hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      // Handle times exceeding 24 hours
      if (hours >= 24) {
        hours = hours % 24;
      }

      final period = hours >= 12 ? 'PM' : 'AM';
      final displayHour = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);

      return '$displayHour:${minutes.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return departureTime;
    }
  }
}
