abstract class MapProvider {
  String get attribution;
  String get tileTemplate;
  List<String> get subdomains;
  String get userAgentPackageName;
}

class OpenStreetMapProvider implements MapProvider {
  @override
  String get attribution => '© OpenStreetMap-Mitwirkende';

  @override
  String get tileTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  List<String> get subdomains => const [];

  @override
  String get userAgentPackageName => 'freiraum_parking';
}
