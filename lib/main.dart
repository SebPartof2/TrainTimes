import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'config/cities_config.dart';
import 'models/agency.dart';
import 'models/city.dart';
import 'models/gtfs_stop.dart';
import 'services/api_service.dart';
import 'widgets/station_detail_page.dart';

// API Configuration
// Replace this with your deployed Cloudflare Worker API URL
const String? kApiBaseUrl = 'https://train-times-api.sebpartof2.workers.dev';

// Global list to store stations (so we can access them from routes)
List<GtfsStop> _globalStations = [];

// Global service instance (so we can access it from routes)
final ApiService _globalApiService = ApiService(apiBaseUrl: kApiBaseUrl);

// Router configuration
final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const StationsPage(),
    ),
    GoRoute(
      path: '/station/:id',
      redirect: (context, state) {
        // If no stations are loaded yet, redirect to home
        if (_globalStations.isEmpty) {
          return '/';
        }
        return null; // Continue to builder
      },
      builder: (context, state) {
        final stationId = state.pathParameters['id']!;
        try {
          final station = _globalStations.firstWhere(
            (s) => s.stopId == stationId,
          );
          return StationDetailPage(
            station: station,
            gtfsService: _globalApiService,
          );
        } catch (e) {
          // If station not found, redirect to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/');
          });
          return const StationsPage();
        }
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
  // Use the global service instance to share data
  final ApiService _apiService = _globalApiService;

  City? _selectedCity;
  Agency? _selectedAgency;
  List<GtfsStop> _stops = [];
  List<GtfsStop> _filteredStops = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  Set<int> _routeTypesToLoad = {}; // Route types to load from GTFS
  int _loadingProgress = 0;
  int _loadingTotal = 100;
  String _loadingStatus = '';

  @override
  void initState() {
    super.initState();
    // Set default city and agency (Chicago Metra)
    if (CitiesConfig.cities.isNotEmpty) {
      _selectedCity = CitiesConfig.cities.first;
      if (_selectedCity!.agencies.isNotEmpty) {
        _selectedAgency = _selectedCity!.agencies.first;
        // Initialize route types from agency defaults
        if (_selectedAgency!.defaultRouteTypes != null) {
          _routeTypesToLoad = Set.from(_selectedAgency!.defaultRouteTypes!);
        }
      }
    }
    // No cache loading - data is fetched from API on demand
  }

  Future<void> _loadStations() async {
    if (_selectedAgency == null) return;

    // PREVENT loading without route type selection
    if (_routeTypesToLoad.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one station type to load';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _stops = [];
      _filteredStops = [];
      _loadingProgress = 0;
      _loadingTotal = 100;
      _loadingStatus = 'Starting...';
    });

    try {
      // Fetch stations from API
      final stops = await _apiService.getStations(
        _selectedAgency!,
        routeTypeFilter: _routeTypesToLoad.toList(),
        onProgress: (current, total, status) {
          // Only call setState if widget is still mounted
          if (mounted) {
            setState(() {
              _loadingProgress = current;
              _loadingTotal = total;
              _loadingStatus = status;
            });
          }
        },
      );
      final stations = _apiService.filterStations(stops);
      final sortedStations = _apiService.sortStopsByName(stations);

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
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _stops;

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((stop) =>
              stop.stopName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (stop.stopCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    _filteredStops = filtered;
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
                      if (_stops.isNotEmpty) ...[
                        _buildSearchBar(),
                      ],
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
              if (_stops.isNotEmpty) ...[
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
                        // Reset route types to agency defaults
                        if (_selectedAgency?.defaultRouteTypes != null) {
                          _routeTypesToLoad = Set.from(_selectedAgency!.defaultRouteTypes!);
                        } else {
                          _routeTypesToLoad = {};
                        }
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
                        // Reset route types to agency defaults
                        if (agency?.defaultRouteTypes != null) {
                          _routeTypesToLoad = Set.from(agency!.defaultRouteTypes!);
                        } else {
                          _routeTypesToLoad = {};
                        }
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

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated train icon
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(value * 20 - 10, 0),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.train,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            // Loading text
            Text(
              'Loading Stations',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Progress indicator
            SizedBox(
              width: 250,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _loadingTotal > 0 ? _loadingProgress / _loadingTotal : null,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loadingStatus.isNotEmpty ? _loadingStatus : 'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Station count
            if (_loadingProgress > 0)
              Text(
                _loadingProgress == _loadingTotal
                    ? '$_loadingProgress Stations'
                    : '$_loadingProgress Stations...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(height: 8),
            // Agency name
            Text(
              _selectedAgency?.name ?? 'Fetching GTFS data...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingScreen();
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
                                if (stop.routes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: stop.routes.take(5).map((route) {
                                      return _buildRouteBadge(context, route);
                                    }).toList(),
                                  ),
                                ],
                                if (stop.stopLat != null && stop.stopLon != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${stop.stopLat!.toStringAsFixed(4)}, ${stop.stopLon!.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        route.routeShortName,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
