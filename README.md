# Train Times - GTFS Station Viewer

A Flutter web application that reads GTFS (General Transit Feed Specification) data and displays train stations in a modular, extensible way.

## Features

- **Modular Architecture**: Easily add new cities and transit agencies
- **GTFS Support**: Automatically downloads and parses GTFS ZIP files
- **Station Display**: View all stations with details like location coordinates and accessibility
- **Search Functionality**: Filter stations by name or code
- **Mobile-Responsive**: Works on desktop and mobile browsers

## Currently Supported

### Cities and Agencies
- **Chicago, Illinois**
  - Metra (Chicago commuter rail)

## Project Structure

```
lib/
├── config/
│   └── cities_config.dart      # Configuration for cities and agencies
├── models/
│   ├── agency.dart             # Agency model
│   ├── city.dart               # City model
│   └── gtfs_stop.dart          # GTFS stop/station model
├── services/
│   └── gtfs_service.dart       # GTFS data fetching and parsing
└── main.dart                   # Main application UI
```

## How to Add a New City/Agency

To add support for a new transit agency:

1. Open `lib/config/cities_config.dart`
2. Add a new `City` object to the `cities` list:

```dart
City(
  id: 'your_city_id',
  name: 'Your City Name',
  state: 'State',
  country: 'Country',
  agencies: [
    Agency(
      id: 'agency_id',
      name: 'Agency Name',
      gtfsUrl: 'https://example.com/gtfs/feed.zip',
      website: 'https://agency.com',
      timezone: 'America/New_York',
    ),
  ],
),
```

3. The agency will automatically appear in the dropdown selectors

### Example: Adding NYC MTA

```dart
City(
  id: 'new_york',
  name: 'New York',
  state: 'New York',
  country: 'USA',
  agencies: [
    Agency(
      id: 'mta_subway',
      name: 'MTA Subway',
      gtfsUrl: 'https://api.mta.info/gtfs/subway/gtfs',
      website: 'https://new.mta.info',
      timezone: 'America/New_York',
    ),
  ],
),
```

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Web browser

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd TrainTimes
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run -d chrome
```

Or build for web:
```bash
flutter build web
```

### Important: CORS Issues

When running locally, you may encounter CORS (Cross-Origin Resource Sharing) errors because transit agencies' GTFS feeds don't allow direct browser access.

**Solutions:**
1. **For Production**: Deploy using the included Cloudflare Worker proxy (see [DEPLOYMENT.md](DEPLOYMENT.md))
2. **For Local Development**: Use a browser extension like "CORS Unblock" (not recommended for production)

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment instructions to Cloudflare Pages with the CORS proxy.

## Usage

1. Select a city from the dropdown
2. Select a transit agency from the dropdown
3. Click "Load Stations" to download and parse the GTFS data
4. Use the search bar to filter stations by name or code
5. View station details including:
   - Station name
   - Station code
   - GPS coordinates
   - Wheelchair accessibility

## GTFS Data Format

The app expects standard GTFS format with at least a `stops.txt` file containing:
- `stop_id`: Unique identifier
- `stop_name`: Station name
- `stop_lat`: Latitude
- `stop_lon`: Longitude
- `stop_code`: Optional station code
- `location_type`: Optional type (0=stop, 1=station)
- `parent_station`: Optional parent station ID
- `wheelchair_boarding`: Optional accessibility info

## Technologies Used

- **Flutter**: Cross-platform UI framework
- **http**: HTTP requests for downloading GTFS data
- **archive**: ZIP file extraction
- **csv**: CSV parsing for GTFS files

## Future Enhancements

- Route information display
- Real-time arrival/departure times
- Map view of stations
- Trip planning
- Multiple cities support (already architected)
- Favorites/saved stations
- Offline support

## Contributing

To add support for your local transit agency:
1. Find the GTFS feed URL (usually available on the transit agency's website)
2. Add the agency to `cities_config.dart`
3. Submit a pull request

## License

This project is open source and available under the MIT License.
