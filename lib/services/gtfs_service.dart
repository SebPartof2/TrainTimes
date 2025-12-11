import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import '../models/gtfs_stop.dart';
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

      // Find stops.txt in the archive
      ArchiveFile? stopsFile;
      for (final file in archive) {
        if (file.name == 'stops.txt' && !file.isFile) {
          continue;
        }
        if (file.name == 'stops.txt') {
          stopsFile = file;
          break;
        }
      }

      if (stopsFile == null) {
        throw Exception('stops.txt not found in GTFS archive');
      }

      // Extract and parse stops.txt
      final stopsContent = utf8.decode(stopsFile.content as List<int>);
      final stops = _parseStopsCsv(stopsContent);

      return stops;
    } catch (e) {
      throw Exception('Error fetching GTFS stops: $e');
    }
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
