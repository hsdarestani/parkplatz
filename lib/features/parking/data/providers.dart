import 'package:flutter_riverpod/flutter_riverpod.dart';import 'demo_parking_repository.dart';import '../../search/presentation/search_controller.dart';
final parkingRepositoryProvider=Provider<ParkingRepository>((ref)=>DemoParkingRepository());
final parkingResultsProvider=Provider((ref)=>ref.watch(parkingRepositoryProvider).search(ref.watch(searchProvider)));
final selectedParkingIdProvider=StateProvider<String?>((ref)=>null);
