import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import '../models/gtfs_stop.dart';
import '../models/gtfs_route.dart';
import '../models/agency.dart';

class GtfsService {
  // Optional CORS proxy URL (e.g., your Cloudflare Worker)
  final String? corsProxyUrl;

  GtfsService({this.corsProxyUrl});

  Future<List<GtfsStop>> fetchStops(Agency agency) async {
    try {
      // Construct the URL with CORS proxy if configured
      final fetchUrl = _buildFetchUrl(agency.gtfsUrl);

      // Download the GTFS ZIP file
      final response = await http.get(Uri.parse(fetchUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download GTFS data: ${response.statusCode}');
      }

      // Decode the ZIP archive
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);

      // Parse all necessary files
      final stops = _parseStopsFromArchive(archive);
      final routes = _parseRoutesFromArchive(archive);
      final stopRoutes = _linkStopsToRoutes(archive, routes);

      // Add route information to stops
      for (final stop in stops) {
        stop.routes = stopRoutes[stop.stopId] ?? [];
      }

      return stops;
    } catch (e) {
      throw Exception('Error fetching GTFS stops: $e');
    }
  }

  List<GtfsStop> _parseStopsFromArchive(Archive archive) {
    final stopsFile = _findFileInArchive(archive, 'stops.txt');
    if (stopsFile == null) {
      throw Exception('stops.txt not found in GTFS archive');
    }
    final stopsContent = utf8.decode(stopsFile.content as List<int>);
    return _parseStopsCsv(stopsContent);
  }

  List<GtfsRoute> _parseRoutesFromArchive(Archive archive) {
    final routesFile = _findFileInArchive(archive, 'routes.txt');
    if (routesFile == null) {
      return []; // Routes are optional, return empty list
    }
    final routesContent = utf8.decode(routesFile.content as List<int>);
    return _parseRoutesCsv(routesContent);
  }

  Map<String, List<GtfsRoute>> _linkStopsToRoutes(
    Archive archive,
    List<GtfsRoute> routes,
  ) {
    // Parse trips.txt to get trip_id -> route_id mapping
    final tripToRoute = _parseTripToRouteMapping(archive);

    // Parse stop_times.txt to get stop_id -> trip_id mappings
    final stopToTrips = _parseStopToTripsMapping(archive);

    // Build stop_id -> routes mapping
    final stopRoutes = <String, List<GtfsRoute>>{};
    final routeMap = {for (var r in routes) r.routeId: r};

    for (final entry in stopToTrips.entries) {
      final stopId = entry.key;
      final tripIds = entry.value;

      final routesForStop = <GtfsRoute>{};
      for (final tripId in tripIds) {
        final routeId = tripToRoute[tripId];
        if (routeId != null && routeMap.containsKey(routeId)) {
          routesForStop.add(routeMap[routeId]!);
        }
      }

      if (routesForStop.isNotEmpty) {
        stopRoutes[stopId] = routesForStop.toList();
      }
    }

    return stopRoutes;
  }

  Map<String, String> _parseTripToRouteMapping(Archive archive) {
    final tripsFile = _findFileInArchive(archive, 'trips.txt');
    if (tripsFile == null) return {};

    final tripsContent = utf8.decode(tripsFile.content as List<int>);
    final rows = const CsvToListConverter().convert(
      tripsContent,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (rows.isEmpty) return {};

    final headers = <String, int>{};
    for (int i = 0; i < rows[0].length; i++) {
      headers[rows[0][i].toString().trim()] = i;
    }

    final tripToRoute = <String, String>{};
    final tripIdIdx = headers['trip_id'];
    final routeIdIdx = headers['route_id'];

    if (tripIdIdx == null || routeIdIdx == null) return {};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length > tripIdIdx && row.length > routeIdIdx) {
        final tripId = row[tripIdIdx].toString().trim();
        final routeId = row[routeIdIdx].toString().trim();
        tripToRoute[tripId] = routeId;
      }
    }

    return tripToRoute;
  }

  Map<String, Set<String>> _parseStopToTripsMapping(Archive archive) {
    final stopTimesFile = _findFileInArchive(archive, 'stop_times.txt');
    if (stopTimesFile == null) return {};

    final stopTimesContent = utf8.decode(stopTimesFile.content as List<int>);
    final rows = const CsvToListConverter().convert(
      stopTimesContent,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (rows.isEmpty) return {};

    final headers = <String, int>{};
    for (int i = 0; i < rows[0].length; i++) {
      headers[rows[0][i].toString().trim()] = i;
    }

    final stopToTrips = <String, Set<String>>{};
    final tripIdIdx = headers['trip_id'];
    final stopIdIdx = headers['stop_id'];

    if (tripIdIdx == null || stopIdIdx == null) return {};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length > tripIdIdx && row.length > stopIdIdx) {
        final tripId = row[tripIdIdx].toString().trim();
        final stopId = row[stopIdIdx].toString().trim();
        stopToTrips.putIfAbsent(stopId, () => <String>{}).add(tripId);
      }
    }

    return stopToTrips;
  }

  ArchiveFile? _findFileInArchive(Archive archive, String fileName) {
    for (final file in archive) {
      if (file.name == fileName && file.isFile) {
        return file;
      }
    }
    return null;
  }

  List<GtfsStop> _parseStopsCsv(String csvContent) {
    final rows = const CsvToListConverter().convert(
      csvContent,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (rows.isEmpty) {
      return [];
    }

    // First row contains headers
    final headers = rows[0].map((h) => h.toString().trim()).toList();
    final stops = <GtfsStop>[];

    // Parse each data row
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowMap = <String, String>{};

      for (int j = 0; j < headers.length && j < row.length; j++) {
        rowMap[headers[j]] = row[j].toString().trim();
      }

      try {
        stops.add(GtfsStop.fromCsvRow(rowMap));
      } catch (e) {
        // Skip invalid rows
        print('Error parsing row $i: $e');
      }
    }

    return stops;
  }

  List<GtfsRoute> _parseRoutesCsv(String csvContent) {
    final rows = const CsvToListConverter().convert(
      csvContent,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (rows.isEmpty) {
      return [];
    }

    // First row contains headers
    final headers = <String, int>{};
    for (int i = 0; i < rows[0].length; i++) {
      headers[rows[0][i].toString().trim()] = i;
    }

    final routes = <GtfsRoute>[];

    // Parse each data row
    for (int i = 1; i < rows.length; i++) {
      try {
        routes.add(GtfsRoute.fromCsvRow(rows[i], headers));
      } catch (e) {
        // Skip invalid rows
        print('Error parsing route row $i: $e');
      }
    }

    return routes;
  }

  List<GtfsStop> filterStations(List<GtfsStop> stops) {
    // Filter to only include stations (location_type = 1) or stops without parent
    // This helps avoid duplicates and focuses on main stations
    return stops.where((stop) {
      return stop.locationType == 1 ||
             (stop.parentStation == null || stop.parentStation!.isEmpty);
    }).toList();
  }

  List<GtfsStop> sortStopsByName(List<GtfsStop> stops) {
    final sorted = List<GtfsStop>.from(stops);
    sorted.sort((a, b) => a.stopName.compareTo(b.stopName));
    return sorted;
  }

  String _buildFetchUrl(String gtfsUrl) {
    if (corsProxyUrl == null) {
      // Direct fetch (will fail with CORS in browser)
      return gtfsUrl;
    }
    // Use CORS proxy - append the GTFS URL as a query parameter
    return '$corsProxyUrl?url=${Uri.encodeComponent(gtfsUrl)}';
  }
}
