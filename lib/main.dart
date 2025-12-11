import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'config/cities_config.dart';
import 'models/agency.dart';
import 'models/city.dart';
import 'models/gtfs_stop.dart';
import 'services/gtfs_service.dart';
import 'widgets/station_detail_page.dart';

// CORS Proxy Configuration
// Replace this with your deployed Cloudflare Worker URL
// Example: 'https://train-times-proxy.your-username.workers.dev'
// Leave as null for local development (will have CORS issues)
const String? kCorsProxyUrl = 'https://train-times-proxy.sebpartof2.workers.dev';

// Global list to store stations (so we can access them from routes)
List<GtfsStop> _globalStations = [];

// Router configuration
final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const StationsPage(),
    ),
    GoRoute(
      path: '/station/:id',
      builder: (context, state) {
        final stationId = state.pathParameters['id']!;
        final station = _globalStations.firstWhere(
          (s) => s.stopId == stationId,
          orElse: () => _globalStations.first,
        );
        return StationDetailPage(station: station);
      },
    ),
  ],
);

void main() {
  runApp(const TrainTimesApp());
}

class TrainTimesApp extends StatelessWidget {
  const TrainTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Train Times',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class StationsPage extends StatefulWidget {
  const StationsPage({super.key});

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  final GtfsService _gtfsService = GtfsService(corsProxyUrl: kCorsProxyUrl);

  City? _selectedCity;
  Agency? _selectedAgency;
  List<GtfsStop> _stops = [];
  List<GtfsStop> _filteredStops = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Set default city and agency (Chicago Metra)
    if (CitiesConfig.cities.isNotEmpty) {
      _selectedCity = CitiesConfig.cities.first;
      if (_selectedCity!.agencies.isNotEmpty) {
        _selectedAgency = _selectedCity!.agencies.first;
      }
    }
    // Auto-load stations on page open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStations();
    });
  }

  Future<void> _loadStations() async {
    if (_selectedAgency == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _stops = [];
      _filteredStops = [];
    });

    try {
      final stops = await _gtfsService.fetchStops(_selectedAgency!);
      final stations = _gtfsService.filterStations(stops);
      final sortedStations = _gtfsService.sortStopsByName(stations);

      setState(() {
        _stops = sortedStations;
        _filteredStops = sortedStations;
        _globalStations = sortedStations; // Update global list for routing
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterStops(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStops = _stops;
      } else {
        _filteredStops = _stops
            .where((stop) =>
                stop.stopName.toLowerCase().contains(query.toLowerCase()) ||
                (stop.stopCode?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectors(),
                      const SizedBox(height: 16),
                      if (_stops.isNotEmpty) _buildSearchBar(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.train,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Train Times',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'GTFS Station Explorer',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_stops.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_stops.length} stations',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select City and Agency',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<City>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    items: CitiesConfig.cities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text('${city.name}, ${city.state ?? city.country}'),
                      );
                    }).toList(),
                    onChanged: (city) {
                      setState(() {
                        _selectedCity = city;
                        _selectedAgency = city?.agencies.first;
                        _stops = [];
                        _filteredStops = [];
                      });
                      if (city != null) _loadStations();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Agency>(
                    value: _selectedAgency,
                    decoration: InputDecoration(
                      labelText: 'Agency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      prefixIcon: const Icon(Icons.directions_transit),
                    ),
                    items: _selectedCity?.agencies.map((agency) {
                      return DropdownMenuItem(
                        value: agency,
                        child: Text(agency.name),
                      );
                    }).toList(),
                    onChanged: (agency) {
                      setState(() {
                        _selectedAgency = agency;
                        _stops = [];
                        _filteredStops = [];
                      });
                      if (agency != null) _loadStations();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Search Stations',
          hintText: 'Enter station name or code...',
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _filterStops('');
                  },
                )
              : null,
        ),
        onChanged: _filterStops,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading stations...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    if (_filteredStops.isEmpty && _stops.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a city and agency, then click "Load Stations"',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_filteredStops.isEmpty) {
      return const Center(
        child: Text('No stations found matching your search'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.list,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Stations (${_filteredStops.length}${_searchQuery.isNotEmpty ? ' of ${_stops.length}' : ''})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: _filteredStops.length,
            itemBuilder: (context, index) {
              final stop = _filteredStops[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      context.go('/station/${Uri.encodeComponent(stop.stopId)}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primaryContainer,
                                  Theme.of(context).colorScheme.secondaryContainer,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.train,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.stopName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (stop.stopCode != null && stop.stopCode!.isNotEmpty)
                                  Text(
                                    'Code: ${stop.stopCode}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                if (stop.stopLat != null && stop.stopLon != null)
                                  Text(
                                    '${stop.stopLat!.toStringAsFixed(4)}, ${stop.stopLon!.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              if (stop.wheelchairBoarding == '1')
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.accessible,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
