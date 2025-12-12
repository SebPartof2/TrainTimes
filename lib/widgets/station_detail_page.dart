import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/gtfs_stop.dart';
import '../models/gtfs_stop_time.dart';
import '../services/api_service.dart';

class StationDetailPage extends StatelessWidget {
  final GtfsStop station;
  final ApiService gtfsService;

  const StationDetailPage({
    super.key,
    required this.station,
    required this.gtfsService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(station.stopName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context),
            const SizedBox(height: 16),
            if (station.routes.isNotEmpty) ...[
              _buildRoutesCard(context),
              const SizedBox(height: 16),
            ],
            _buildDepartureTimesCard(context),
            const SizedBox(height: 16),
            _buildLocationCard(context),
            const SizedBox(height: 16),
            _buildDetailsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.train,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.stopName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (station.stopCode != null && station.stopCode!.isNotEmpty)
                    Text(
                      'Station Code: ${station.stopCode}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  if (station.stopDesc != null && station.stopDesc!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        station.stopDesc!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Routes Serving This Station',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: station.routes.map((route) {
                return _buildRouteBadge(context, route);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteBadge(BuildContext context, dynamic route) {
    // Parse route color (default to blue if not provided)
    Color backgroundColor = Colors.blue;
    Color textColor = Colors.white;

    if (route.routeColor != null && route.routeColor!.isNotEmpty) {
      try {
        final colorHex = route.routeColor!.replaceAll('#', '');
        backgroundColor = Color(int.parse('FF$colorHex', radix: 16));
      } catch (e) {
        backgroundColor = Colors.blue;
      }
    }

    if (route.routeTextColor != null && route.routeTextColor!.isNotEmpty) {
      try {
        final colorHex = route.routeTextColor!.replaceAll('#', '');
        textColor = Color(int.parse('FF$colorHex', radix: 16));
      } catch (e) {
        textColor = Colors.white;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            route.routeShortName,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (route.routeLongName.isNotEmpty)
            Text(
              route.routeLongName,
              style: TextStyle(
                color: textColor.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartureTimesCard(BuildContext context) {
    return FutureBuilder<List<GtfsStopTime>>(
      future: gtfsService.getUpcomingDepartures(station.stopId, limit: 15),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Upcoming Departures',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          );
        }

        final departures = snapshot.data ?? [];

    if (departures.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Upcoming Departures',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No upcoming departures available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Departures',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: departures.length,
              separatorBuilder: (context, index) => Divider(
                height: 24,
                color: Colors.grey[300],
              ),
              itemBuilder: (context, index) {
                final departure = departures[index];

                return Row(
                  children: [
                    // Time
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        departure.getFormattedTime(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Headsign
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (departure.stopHeadsign != null &&
                              departure.stopHeadsign!.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.arrow_forward,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    departure.stopHeadsign!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Departure',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    if (station.stopLat == null || station.stopLon == null) {
      return const SizedBox.shrink();
    }

    final location = LatLng(station.stopLat!, station.stopLon!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Interactive Leaflet Map
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 15.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.example.train_times_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 80,
                        height: 80,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.train,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              Icons.place,
              'Latitude',
              station.stopLat!.toStringAsFixed(6),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.place,
              'Longitude',
              station.stopLon!.toStringAsFixed(6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Station Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              Icons.tag,
              'Stop ID',
              station.stopId,
            ),
            if (station.zoneId != null && station.zoneId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.layers_outlined,
                'Zone ID',
                station.zoneId!,
              ),
            ],
            if (station.locationType != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.location_city,
                'Location Type',
                _getLocationTypeLabel(station.locationType!),
              ),
            ],
            if (station.wheelchairBoarding != null &&
                station.wheelchairBoarding!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.accessible,
                'Wheelchair Accessible',
                station.wheelchairBoarding == '1' ? 'Yes' : 'No',
              ),
            ],
            if (station.parentStation != null &&
                station.parentStation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.account_tree,
                'Parent Station',
                station.parentStation!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getLocationTypeLabel(int type) {
    switch (type) {
      case 0:
        return 'Stop/Platform';
      case 1:
        return 'Station';
      case 2:
        return 'Entrance/Exit';
      case 3:
        return 'Generic Node';
      case 4:
        return 'Boarding Area';
      default:
        return 'Unknown ($type)';
    }
  }
}
