class Agency {
  final String id;
  final String name;
  final String gtfsUrl;
  final String? website;
  final String? timezone;

  Agency({
    required this.id,
    required this.name,
    required this.gtfsUrl,
    this.website,
    this.timezone,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gtfsUrl': gtfsUrl,
        'website': website,
        'timezone': timezone,
      };

  factory Agency.fromJson(Map<String, dynamic> json) => Agency(
        id: json['id'] as String,
        name: json['name'] as String,
        gtfsUrl: json['gtfsUrl'] as String,
        website: json['website'] as String?,
        timezone: json['timezone'] as String?,
      );
}
