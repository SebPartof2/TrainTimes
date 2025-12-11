class GtfsRoute {
  final String routeId;
  final String? agencyId;
  final String routeShortName;
  final String routeLongName;
  final String? routeDesc;
  final int routeType;
  final String? routeUrl;
  final String? routeColor;
  final String? routeTextColor;

  GtfsRoute({
    required this.routeId,
    this.agencyId,
    required this.routeShortName,
    required this.routeLongName,
    this.routeDesc,
    required this.routeType,
    this.routeUrl,
    this.routeColor,
    this.routeTextColor,
  });

  factory GtfsRoute.fromCsvRow(List<dynamic> row, Map<String, int> headers) {
    return GtfsRoute(
      routeId: row[headers['route_id']!].toString(),
      agencyId: _getOptionalField(row, headers, 'agency_id'),
      routeShortName: row[headers['route_short_name']!].toString(),
      routeLongName: row[headers['route_long_name']!].toString(),
      routeDesc: _getOptionalField(row, headers, 'route_desc'),
      routeType: int.tryParse(row[headers['route_type']!].toString()) ?? 0,
      routeUrl: _getOptionalField(row, headers, 'route_url'),
      routeColor: _getOptionalField(row, headers, 'route_color'),
      routeTextColor: _getOptionalField(row, headers, 'route_text_color'),
    );
  }

  static String? _getOptionalField(
    List<dynamic> row,
    Map<String, int> headers,
    String fieldName,
  ) {
    if (!headers.containsKey(fieldName)) return null;
    final value = row[headers[fieldName]!].toString().trim();
    return value.isEmpty ? null : value;
  }

  String getRouteTypeLabel() {
    switch (routeType) {
      case 0:
        return 'Tram/Light Rail';
      case 1:
        return 'Subway/Metro';
      case 2:
        return 'Rail';
      case 3:
        return 'Bus';
      case 4:
        return 'Ferry';
      case 5:
        return 'Cable Car';
      case 6:
        return 'Gondola';
      case 7:
        return 'Funicular';
      default:
        return 'Unknown';
    }
  }
}
