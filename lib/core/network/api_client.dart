import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/environment.dart';
class ApiClient {
  final http.Client client; ApiClient([http.Client? client]):client=client??http.Client();
  Future<bool> health() async { try { final r=await client.get(Uri.parse('${Environment.apiBaseUrl}/health')).timeout(const Duration(seconds:2)); return r.statusCode==200 && jsonDecode(r.body)['status']=='ok'; } catch (_) { return false; } }
}
abstract interface class ParkingRepository {}
abstract interface class AvailabilityRepository {}
abstract interface class VehicleRepository {}
