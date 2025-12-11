import 'agency.dart';

class City {
  final String id;
  final String name;
  final List<Agency> agencies;
  final String? state;
  final String? country;

  City({
    required this.id,
    required this.name,
    required this.agencies,
    this.state,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agencies': agencies.map((a) => a.toJson()).toList(),
        'state': state,
        'country': country,
      };

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as String,
        name: json['name'] as String,
        agencies: (json['agencies'] as List)
            .map((a) => Agency.fromJson(a as Map<String, dynamic>))
            .toList(),
        state: json['state'] as String?,
        country: json['country'] as String?,
      );
}
