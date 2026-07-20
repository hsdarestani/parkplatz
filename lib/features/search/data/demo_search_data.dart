import '../../../shared/models/models.dart';

const demoDestinations = <Destination>[
  Destination('messe', 'Messe Frankfurt', 'Westend', 50.111, 8.650),
  Destination(
    'hbf',
    'Frankfurt Hauptbahnhof',
    'Gutleutviertel',
    50.107,
    8.663,
  ),
  Destination(
    'uniklinik',
    'Universitätsklinikum Frankfurt',
    'Niederrad',
    50.096,
    8.659,
  ),
  Destination('alteoper', 'Alte Oper', 'Innenstadt', 50.116, 8.672),
  Destination('skyline', 'Skyline Plaza', 'Gallus', 50.110, 8.652),
  Destination(
    'flughafen',
    'Flughafen Frankfurt Terminal 1',
    'Flughafen',
    50.050,
    8.570,
  ),
  Destination('roemer', 'Römerberg', 'Altstadt', 50.110, 8.682),
  Destination(
    'warte',
    'Bockenheimer Warte',
    'Bockenheim',
    50.120,
    8.653,
  ),
];

const demoVehicles = <Vehicle>[
  Vehicle('class-small', 'Kleinwagen', 'z. B. VW Polo', 1.50, 1.78, 4.10),
  Vehicle('class-compact', 'Kompaktklasse', 'z. B. VW Golf', 1.52, 1.85, 4.45),
  Vehicle('class-sedan', 'Limousine / Kombi', 'z. B. BMW 3er', 1.55, 1.90, 4.90),
  Vehicle('class-suv', 'SUV', 'z. B. VW Tiguan', 1.75, 1.95, 4.75),
  Vehicle('class-van', 'Van / Transporter', 'z. B. Mercedes Vito', 2.05, 2.05, 5.35),
];