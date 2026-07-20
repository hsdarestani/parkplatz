import '../../../shared/models/models.dart';

class VehicleCatalogEntry {
  const VehicleCatalogEntry({
    required this.brand,
    required this.model,
    required this.height,
    required this.width,
    required this.length,
  });

  final String brand;
  final String model;
  final double height;
  final double width;
  final double length;

  String get id =>
      'catalog-${brand.toLowerCase()}-${model.toLowerCase().replaceAll(' ', '-')}';

  Vehicle toVehicle() => Vehicle(
        id,
        '$brand $model',
        '',
        height,
        width,
        length,
      );
}

const vehicleCatalog = <VehicleCatalogEntry>[
  VehicleCatalogEntry(
    brand: 'Audi',
    model: 'A3',
    height: 1.45,
    width: 1.82,
    length: 4.34,
  ),
  VehicleCatalogEntry(
    brand: 'Audi',
    model: 'A4',
    height: 1.43,
    width: 1.85,
    length: 4.76,
  ),
  VehicleCatalogEntry(
    brand: 'Audi',
    model: 'Q3',
    height: 1.62,
    width: 1.85,
    length: 4.49,
  ),
  VehicleCatalogEntry(
    brand: 'BMW',
    model: '1er',
    height: 1.46,
    width: 1.80,
    length: 4.36,
  ),
  VehicleCatalogEntry(
    brand: 'BMW',
    model: '3er',
    height: 1.44,
    width: 1.83,
    length: 4.71,
  ),
  VehicleCatalogEntry(
    brand: 'BMW',
    model: 'X3',
    height: 1.68,
    width: 1.89,
    length: 4.71,
  ),
  VehicleCatalogEntry(
    brand: 'Ford',
    model: 'Fiesta',
    height: 1.48,
    width: 1.74,
    length: 4.04,
  ),
  VehicleCatalogEntry(
    brand: 'Ford',
    model: 'Focus',
    height: 1.47,
    width: 1.83,
    length: 4.38,
  ),
  VehicleCatalogEntry(
    brand: 'Ford',
    model: 'Kuga',
    height: 1.68,
    width: 1.88,
    length: 4.61,
  ),
  VehicleCatalogEntry(
    brand: 'Mercedes-Benz',
    model: 'A-Klasse',
    height: 1.44,
    width: 1.80,
    length: 4.42,
  ),
  VehicleCatalogEntry(
    brand: 'Mercedes-Benz',
    model: 'C-Klasse',
    height: 1.44,
    width: 1.82,
    length: 4.75,
  ),
  VehicleCatalogEntry(
    brand: 'Mercedes-Benz',
    model: 'Vito',
    height: 1.91,
    width: 1.93,
    length: 5.14,
  ),
  VehicleCatalogEntry(
    brand: 'Opel',
    model: 'Corsa',
    height: 1.44,
    width: 1.77,
    length: 4.06,
  ),
  VehicleCatalogEntry(
    brand: 'Opel',
    model: 'Astra',
    height: 1.44,
    width: 1.86,
    length: 4.37,
  ),
  VehicleCatalogEntry(
    brand: 'Opel',
    model: 'Mokka',
    height: 1.53,
    width: 1.79,
    length: 4.15,
  ),
  VehicleCatalogEntry(
    brand: 'Tesla',
    model: 'Model 3',
    height: 1.44,
    width: 1.85,
    length: 4.72,
  ),
  VehicleCatalogEntry(
    brand: 'Tesla',
    model: 'Model Y',
    height: 1.62,
    width: 1.92,
    length: 4.75,
  ),
  VehicleCatalogEntry(
    brand: 'Volkswagen',
    model: 'Polo',
    height: 1.45,
    width: 1.75,
    length: 4.07,
  ),
  VehicleCatalogEntry(
    brand: 'Volkswagen',
    model: 'Golf',
    height: 1.49,
    width: 1.79,
    length: 4.28,
  ),
  VehicleCatalogEntry(
    brand: 'Volkswagen',
    model: 'Tiguan',
    height: 1.68,
    width: 1.84,
    length: 4.51,
  ),
];

List<String> get vehicleBrands =>
    vehicleCatalog.map((entry) => entry.brand).toSet().toList()..sort();

List<VehicleCatalogEntry> vehicleModelsFor(String brand) => vehicleCatalog
    .where((entry) => entry.brand == brand)
    .toList()
  ..sort((a, b) => a.model.compareTo(b.model));
