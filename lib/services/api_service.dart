import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gtfs_stop.dart';
import '../models/gtfs_route.dart';
import '../models/gtfs_stop_time.dart';
import '../models/agency.dart';

class ApiService {
  // API base URL - update this with your Worker URL
  final String? apiBaseUrl;

  ApiService({this.apiBaseUrl});

  String get _baseUrl => apiBaseUrl ?? 'https://train-times-api.sebpartof2.workers.dev';

  /// Get list of available agencies
  Future<List<Agency>> getAgencies() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/agencies'));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch agencies: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final agencies = (data['agencies'] as List)
        .map((json) => Agency(
              id: json['id'] as String,
              name: json['name'] as String,
              gtfsUrl: '', // Not needed from API
              defaultRouteTypes: (json['defaultRouteTypes'] as List?)
                  ?.map((e) => e as int)
                  .toList(),
            ))
        .toList();

    return agencies;
  }

  /// Get stations for an agency, filtered by route types
  Future<List<GtfsStop>> getStations(
    Agency agency, {
    List<int>? routeTypeFilter,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    // Build query parameters
    final routeTypes = routeTypeFilter ?? agency.defaultRouteTypes ?? [];
    final routeTypesParam = routeTypes.join(',');

    final uri = Uri.parse('$_baseUrl/api/stations').replace(queryParameters: {
      'agency': agency.id,
      'routeTypes': routeTypesParam,
    });

    // Report progress
    onProgress?.call(0, 100, 'Loading stations from API...');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stations: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final stationsJson = data['stations'] as List;

    // Report progress
    onProgress?.call(stationsJson.length, stationsJson.length, '${stationsJson.length} stations loaded');

    // Parse stations
    final stations = stationsJson.map((json) {
      final stop = GtfsStop(
        stopId: json['stopId'] as String,
        stopName: json['stopName'] as String,
        stopLat: json['stopLat'] as double?,
        stopLon: json['stopLon'] as double?,
        stopCode: json['stopCode'] as String?,
        stopDesc: json['stopDesc'] as String?,
        locationType: json['locationType'] as int?,
        parentStation: json['parentStation'] as String?,
        wheelchairBoarding: json['wheelchairBoarding'] as String?,
      );

      // Parse routes for this stop
      stop.routes = (json['routes'] as List)
          .map((routeJson) => GtfsRoute(
                routeId: routeJson['routeId'] as String,
                routeShortName: routeJson['routeShortName'] as String? ?? '',
                routeLongName: routeJson['routeLongName'] as String?,
                routeType: routeJson['routeType'] as int,
                routeColor: routeJson['routeColor'] as String?,
                routeTextColor: routeJson['routeTextColor'] as String?,
              ))
          .toList();

      return stop;
    }).toList();

    return stations;
  }

  /// Get upcoming departures for a specific station
  Future<List<GtfsStopTime>> getUpcomingDepartures(String stopId, {int limit = 10}) async {
    final uri = Uri.parse('$_baseUrl/api/departures').replace(queryParameters: {
      'stopId': stopId,
      'limit': limit.toString(),
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch departures: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final departuresJson = data['departures'] as List;

    // Parse departures
    final departures = departuresJson.map((json) {
      return GtfsStopTime(
        tripId: json['tripId'] as String? ?? '',
        arrivalTime: json['departureTime'] as String? ?? '00:00:00',
        departureTime: json['departureTime'] as String? ?? '00:00:00',
        stopId: stopId,
        stopSequence: 0, // Not provided by API
        stopHeadsign: json['stopHeadsign'] as String?,
      );
    }).toList();

    return departures;
  }

  /// Filter stations to only include main stations (no child stops)
  List<GtfsStop> filterStations(List<GtfsStop> stops) {
    return stops.where((stop) {
      return stop.locationType == 1 ||
             (stop.parentStation == null || stop.parentStation!.isEmpty);
    }).toList();
  }

  /// Sort stops by name
  List<GtfsStop> sortStopsByName(List<GtfsStop> stops) {
    final sorted = List<GtfsStop>.from(stops);
    sorted.sort((a, b) => a.stopName.compareTo(b.stopName));
    return sorted;
  }

  /// Trigger GTFS data refresh (admin only)
  Future<void> refreshGtfsData(String agencyId) async {
    final uri = Uri.parse('$_baseUrl/api/refresh').replace(queryParameters: {
      'agency': agencyId,
    });

    final response = await http.post(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to refresh data: ${response.statusCode}');
    }
  }
}
