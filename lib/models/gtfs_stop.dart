import 'gtfs_route.dart';

class GtfsStop {
  final String stopId;
  final String stopName;
  final double? stopLat;
  final double? stopLon;
  final String? stopCode;
  final String? stopDesc;
  final String? zoneId;
  final String? stopUrl;
  final int? locationType;
  final String? parentStation;
  final String? wheelchairBoarding;

  // Routes that serve this stop (populated after parsing)
  List<GtfsRoute> routes = [];

  GtfsStop({
    required this.stopId,
    required this.stopName,
    this.stopLat,
    this.stopLon,
    this.stopCode,
    this.stopDesc,
    this.zoneId,
    this.stopUrl,
    this.locationType,
    this.parentStation,
    this.wheelchairBoarding,
  });

  factory GtfsStop.fromCsvRow(Map<String, String> row) {
    return GtfsStop(
      stopId: row['stop_id'] ?? '',
      stopName: row['stop_name'] ?? '',
      stopLat: row['stop_lat'] != null && row['stop_lat']!.isNotEmpty
          ? double.tryParse(row['stop_lat']!)
          : null,
      stopLon: row['stop_lon'] != null && row['stop_lon']!.isNotEmpty
          ? double.tryParse(row['stop_lon']!)
          : null,
      stopCode: row['stop_code'],
      stopDesc: row['stop_desc'],
      zoneId: row['zone_id'],
      stopUrl: row['stop_url'],
      locationType: row['location_type'] != null && row['location_type']!.isNotEmpty
          ? int.tryParse(row['location_type']!)
          : null,
      parentStation: row['parent_station'],
      wheelchairBoarding: row['wheelchair_boarding'],
    );
  }

  Map<String, dynamic> toJson() => {
        'stopId': stopId,
        'stopName': stopName,
        'stopLat': stopLat,
        'stopLon': stopLon,
        'stopCode': stopCode,
        'stopDesc': stopDesc,
        'zoneId': zoneId,
        'stopUrl': stopUrl,
        'locationType': locationType,
        'parentStation': parentStation,
        'wheelchairBoarding': wheelchairBoarding,
      };
}
