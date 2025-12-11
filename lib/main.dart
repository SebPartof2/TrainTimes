import 'package:flutter/material.dart';
import 'config/cities_config.dart';
import 'models/agency.dart';
import 'models/city.dart';
import 'models/gtfs_stop.dart';
import 'services/gtfs_service.dart';

// CORS Proxy Configuration
// Replace this with your deployed Cloudflare Worker URL
// Example: 'https://train-times-proxy.your-username.workers.dev'
// Leave as null for local development (will have CORS issues)
const String? kCorsProxyUrl = 'https://train-times-proxy.sebpartof2.workers.dev';

void main() {
  runApp(const TrainTimesApp());
}

class TrainTimesApp extends StatelessWidget {
  const TrainTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Times',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const StationsPage(),
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Train Times - GTFS Stations'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectors(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadStations,
              icon: const Icon(Icons.download),
              label: const Text('Load Stations'),
            ),
            const SizedBox(height: 16),
            if (_stops.isNotEmpty) _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectors() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select City and Agency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<City>(
                    initialValue: _selectedCity,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
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
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Agency>(
                    initialValue: _selectedAgency,
                    decoration: const InputDecoration(
                      labelText: 'Agency',
                      border: OutlineInputBorder(),
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
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Stations',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
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

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Stations (${_filteredStops.length}${_searchQuery.isNotEmpty ? ' of ${_stops.length}' : ''})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredStops.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final stop = _filteredStops[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.train_outlined),
                  ),
                  title: Text(stop.stopName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stop.stopCode != null && stop.stopCode!.isNotEmpty)
                        Text('Code: ${stop.stopCode}'),
                      if (stop.stopLat != null && stop.stopLon != null)
                        Text(
                          'Location: ${stop.stopLat!.toStringAsFixed(6)}, ${stop.stopLon!.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: stop.wheelchairBoarding == '1'
                      ? const Icon(Icons.accessible, color: Colors.blue)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
