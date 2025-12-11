import '../models/city.dart';
import '../models/agency.dart';

class CitiesConfig {
  static final List<City> cities = [
    City(
      id: 'chicago',
      name: 'Chicago',
      state: 'Illinois',
      country: 'USA',
      agencies: [
        Agency(
          id: 'metra',
          name: 'Metra',
          gtfsUrl: 'https://schedules.metrarail.com/gtfs/schedule.zip',
          website: 'https://metra.com',
          timezone: 'America/Chicago',
        ),
        Agency(
          id: 'cta',
          name: 'CTA',
          gtfsUrl: 'https://www.transitchicago.com/downloads/sch_data/google_transit.zip',
          website: 'https://transitchicago.com',
          timezone: 'America/Chicago',
        ),
      ],
    ),
  ];

  static City? getCityById(String id) {
    try {
      return cities.firstWhere((city) => city.id == id);
    } catch (e) {
      return null;
    }
  }

  static Agency? getAgencyById(String cityId, String agencyId) {
    final city = getCityById(cityId);
    if (city == null) return null;

    try {
      return city.agencies.firstWhere((agency) => agency.id == agencyId);
    } catch (e) {
      return null;
    }
  }

  static List<Agency> getAllAgencies() {
    return cities.expand((city) => city.agencies).toList();
  }
}
