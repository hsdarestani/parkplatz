import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../parking/data/demo_parking_repository.dart';

abstract interface class TokenStorage implements ApiTokenStore {
  Future<void> replace(String access,String refresh);
}
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this.storage=const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  @override Future<String?> readAccess()=>storage.read(key:'access_token');
  @override Future<String?> readRefresh()=>storage.read(key:'refresh_token');
  @override Future<void> save(String access,String refresh)=>replace(access,refresh);
  @override Future<void> replace(String access,String refresh) async {await storage.write(key:'access_token',value:access);await storage.write(key:'refresh_token',value:refresh);}
  @override Future<void> clear() async {await storage.delete(key:'access_token');await storage.delete(key:'refresh_token');}
}

enum AppMode { checking, api, localBeta, unavailable }
class AppModeController extends StateNotifier<AppMode> {
  AppModeController(this.api) : super(AppMode.checking) { check(); }
  AppModeController.fixed(AppMode mode) : api = null, super(mode);
  final ApiClient? api;
  Future<void> check() async {
    if (api == null) return;
    state = AppMode.checking;
    final healthy = await api!.health();
    state = healthy ? AppMode.api : Environment.allowLocalBookingFallback ? AppMode.localBeta : AppMode.unavailable;
  }
}
final tokenStorageProvider=Provider<TokenStorage>((_)=>const SecureTokenStorage());
final apiClientProvider=Provider<ApiClient>((ref)=>ApiClient(ref.watch(tokenStorageProvider)));
final appModeProvider=StateNotifierProvider<AppModeController,AppMode>((ref)=>AppModeController(ref.watch(apiClientProvider)));

class AppUser { const AppUser({required this.id,required this.email,required this.displayName}); final String id,email,displayName; factory AppUser.fromJson(Map<String,dynamic> j)=>AppUser(id:j['id'] as String,email:j['email'] as String,displayName:j['display_name'] as String); }
abstract interface class AuthRepository { Future<void> login(String email,String password);Future<void> register(String name,String email,String password);Future<void> logout();Future<bool> restore();bool get authenticated;AppUser? get currentUser; }
class LocalBetaAuthRepository implements AuthRepository {
  static bool _authenticated=false; @override bool get authenticated=>_authenticated; @override AppUser? get currentUser=>_authenticated?const AppUser(id:'local',email:'lokal@beta',displayName:'Beta-Nutzer'):null;
  @override Future<void> login(String email,String password) async {if(!email.contains('@')||password.length<8)throw const FormatException('E-Mail oder Passwort ist ungültig.');_authenticated=true;}
  @override Future<void> register(String name,String email,String password)=>login(email,password);
  @override Future<void> logout() async=>_authenticated=false; @override Future<bool> restore() async=>authenticated;
}
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api,this.tokens); final ApiClient api; final TokenStorage tokens; AppUser? _user;
  @override bool get authenticated=>_user!=null; @override AppUser? get currentUser=>_user;
  Future<void> _authenticate(String path,Map<String,dynamic> body) async {final j=await api.post(path,body:body,authenticated:false) as Map<String,dynamic>;await tokens.save(j['access_token'] as String,j['refresh_token'] as String);await _me();}
  @override Future<void> login(String email,String password)=>_authenticate('/auth/login',{'email':email.trim(),'password':password});
  @override Future<void> register(String name,String email,String password)=>_authenticate('/auth/register',{'display_name':name.trim(),'email':email.trim(),'password':password});
  Future<void> _me() async=>_user=AppUser.fromJson((await api.get('/auth/me')) as Map<String,dynamic>);
  @override Future<bool> restore() async {if(await tokens.readRefresh()==null)return false;try{await _me();return true;}catch(_){await tokens.clear();_user=null;return false;}}
  @override Future<void> logout() async {final refresh=await tokens.readRefresh();try{if(refresh!=null)await api.post('/auth/logout',body:{'refresh_token':refresh},authenticated:false);}finally{await tokens.clear();_user=null;}}
}

class VehicleRecord {const VehicleRecord({required this.id,required this.name,required this.plate,required this.height,required this.width,required this.length,required this.isDefault});final String id,name,plate;final double height,width,length;final bool isDefault;factory VehicleRecord.fromJson(Map<String,dynamic> j)=>VehicleRecord(id:j['id'].toString(),name:j['name'] as String,plate:j['plate'] as String,height:(j['height_m'] as num).toDouble(),width:(j['width_m'] as num).toDouble(),length:(j['length_m'] as num).toDouble(),isDefault:j['is_default']==true);
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'plate':plate,'height_m':height,'width_m':width,'length_m':length,'is_default':isDefault}; Map<String,dynamic> toApi()=>{...toJson()}..remove('id');}
abstract interface class VehicleRepository {Future<List<VehicleRecord>> all();Future<VehicleRecord> save(VehicleRecord vehicle);Future<void> delete(String id);}
class ApiVehicleRepository implements VehicleRepository {ApiVehicleRepository(this.api);final ApiClient api;@override Future<List<VehicleRecord>> all() async=>(await api.get('/vehicles') as List).map((e)=>VehicleRecord.fromJson(e)).toList();@override Future<VehicleRecord> save(VehicleRecord v) async=>VehicleRecord.fromJson(await (v.id.isEmpty?api.post('/vehicles',body:v.toApi()):api.patch('/vehicles/${v.id}',body:v.toApi())));@override Future<void> delete(String id)=>api.delete('/vehicles/$id');}
class LocalVehicleRepository implements VehicleRepository {static const key='local_beta_vehicles';@override Future<List<VehicleRecord>> all() async=>(await SharedPreferences.getInstance()).getStringList(key)?.map((e)=>VehicleRecord.fromJson(jsonDecode(e))).toList()??[];Future<void> _write(List<VehicleRecord> v) async=>(await SharedPreferences.getInstance()).setStringList(key,v.map((e)=>jsonEncode(e.toJson())).toList());@override Future<VehicleRecord> save(VehicleRecord v) async {final values=await all();final saved=v.id.isEmpty?VehicleRecord(id:DateTime.now().microsecondsSinceEpoch.toString(),name:v.name,plate:v.plate,height:v.height,width:v.width,length:v.length,isDefault:v.isDefault):v;values.removeWhere((e)=>e.id==saved.id);values.add(saved);await _write(values);return saved;}@override Future<void> delete(String id) async {final v=await all();v.removeWhere((e)=>e.id==id);await _write(v);}}

class BookingRecord {
 const BookingRecord({required this.id,required this.parkingId,required this.title,required this.reference,this.vehicleId='',required this.plate,required this.status,required this.start,required this.end,this.hourlyPriceCents=0,required this.totalCents,this.currency='EUR',this.cancelledAt,this.exactAddress,this.entranceInstructions,this.accessCode,this.parkingPassToken,this.localBeta=false});
 final String id,parkingId,title,reference,vehicleId,plate,status,currency;final DateTime start,end;final int hourlyPriceCents,totalCents;final DateTime? cancelledAt;final String? exactAddress,entranceInstructions,accessCode,parkingPassToken;final bool localBeta;
 factory BookingRecord.fromJson(Map<String,dynamic> j,{bool localBeta=false})=>BookingRecord(id:j['id'].toString(),parkingId:(j['parking_space_id']??j['parkingId']).toString(),title:(j['parking_title']??j['title']??'Stellplatz') as String,reference:(j['public_reference']??j['reference']) as String,vehicleId:(j['vehicle_id']??j['vehicleId']??'').toString(),plate:(j['vehicle_plate']??j['plate']??'') as String,status:j['status'] as String,start:DateTime.parse((j['start_at']??j['start']) as String),end:DateTime.parse((j['end_at']??j['end']) as String),hourlyPriceCents:(j['hourly_price_cents_snapshot']??j['hourlyPriceCents']??0) as int,totalCents:(j['total_price_cents']??j['totalCents']) as int,currency:(j['currency']??'EUR') as String,cancelledAt:j['cancelled_at']==null?null:DateTime.parse(j['cancelled_at']),exactAddress:j['exact_address'],entranceInstructions:j['entrance_instructions'],accessCode:j['access_code'],parkingPassToken:j['parking_pass_token'],localBeta:localBeta||j['localBeta']==true);
 Map<String,dynamic> toJson()=>{'id':id,'parkingId':parkingId,'title':title,'reference':reference,'vehicleId':vehicleId,'plate':plate,'status':status,'start':start.toIso8601String(),'end':end.toIso8601String(),'hourlyPriceCents':hourlyPriceCents,'totalCents':totalCents,'currency':currency,'cancelled_at':cancelledAt?.toIso8601String(),'localBeta':localBeta};
 BookingRecord cancelled()=>BookingRecord(id:id,parkingId:parkingId,title:title,reference:reference,vehicleId:vehicleId,plate:plate,status:'cancelled',start:start,end:end,hourlyPriceCents:hourlyPriceCents,totalCents:totalCents,currency:currency,cancelledAt:DateTime.now(),localBeta:localBeta);
}
abstract interface class BookingRepository {Future<List<BookingRecord>> all();Future<BookingRecord?> detail(String id);Future<BookingRecord> create(BookingRecord booking);Future<void> cancel(String id);}
class ApiBookingRepository implements BookingRepository {ApiBookingRepository(this.api);final ApiClient api;@override Future<List<BookingRecord>> all() async=>(await api.get('/bookings') as List).map((e)=>BookingRecord.fromJson(e)).toList();@override Future<BookingRecord?> detail(String id) async=>BookingRecord.fromJson(await api.get('/bookings/$id'));@override Future<BookingRecord> create(BookingRecord b) async=>BookingRecord.fromJson(await api.post('/bookings',body:{'parking_space_id':b.parkingId,'vehicle_id':b.vehicleId,'start_at':b.start.toIso8601String(),'end_at':b.end.toIso8601String(),'idempotency_key':'${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1<<32)}'}));@override Future<void> cancel(String id) async{await api.post('/bookings/$id/cancel',body:{'reason':'Vom Nutzer storniert'});}}
class LocalBetaBookingRepository implements BookingRepository {static const _key='local_beta_bookings';@override Future<List<BookingRecord>> all() async=>(await SharedPreferences.getInstance()).getStringList(_key)?.map((e)=>BookingRecord.fromJson(jsonDecode(e),localBeta:true)).toList()??[];Future<void> _save(List<BookingRecord> v) async=>(await SharedPreferences.getInstance()).setStringList(_key,v.map((e)=>jsonEncode(e.toJson())).toList());@override Future<BookingRecord> create(BookingRecord b) async {final local=BookingRecord(id:b.id,parkingId:b.parkingId,title:b.title,reference:b.reference,vehicleId:b.vehicleId,plate:b.plate,status:b.status,start:b.start,end:b.end,hourlyPriceCents:b.hourlyPriceCents,totalCents:b.totalCents,localBeta:true);final v=await all();if(!v.any((e)=>e.id==b.id)){v.add(local);await _save(v);}return local;}@override Future<BookingRecord?> detail(String id) async {for(final b in await all()){if(b.id==id)return b;}return null;}@override Future<void> cancel(String id) async {final v=await all();await _save(v.map((e)=>e.id==id?e.cancelled():e).toList());}}

class AvailabilityResult {const AvailabilityResult(this.available,{this.message});final bool available;final String? message;}
abstract interface class AvailabilityRepository {Future<AvailabilityResult> check(String id,DateTime start,DateTime end);}
class ApiAvailabilityRepository implements AvailabilityRepository {ApiAvailabilityRepository(this.api);final ApiClient api;Future<AvailabilityResult> check(String id,DateTime start,DateTime end) async {final j=await api.get('/parking-spaces/$id/availability',query:{'start_at':start.toIso8601String(),'end_at':end.toIso8601String()},authenticated:false);return AvailabilityResult(j['available'] as bool,message:j['message'] as String?);}}
class LocalAvailabilityRepository implements AvailabilityRepository {@override Future<AvailabilityResult> check(String id,DateTime start,DateTime end) async=>const AvailabilityResult(true);}


class ApiParkingRepository implements ParkingRepository {
  ApiParkingRepository(this.api);
  final ApiClient api;

  @override
  Future<List<ParkingSpace>> all() async => (await api.get(
        '/parking-spaces',
        authenticated: false,
      ) as List)
          .map((value) => _parkingFromJson(value as Map<String, dynamic>))
          .toList();

  @override
  Future<ParkingSpace?> byId(String id) async {
    try {
      return _parkingFromJson(await api.get(
        '/parking-spaces/$id',
        authenticated: false,
      ) as Map<String, dynamic>);
    } on ApiNotFoundException {
      return null;
    }
  }
}

ParkingSpace _parkingFromJson(Map<String, dynamic> json) {
  final access = switch (json['access_type']?.toString()) {
    'barrier' || 'schranke' => AccessType.schranke,
    'gate' || 'tor' => AccessType.tor,
    'underground' || 'tiefgarage' => AccessType.tiefgarage,
    'reception' || 'rezeption' => AccessType.rezeption,
    _ => AccessType.offen,
  };
  return ParkingSpace(
    id: json['id'].toString(),
    title: json['title'] as String,
    district: json['district'] as String,
    landmark: json['landmark'] as String,
    lat: (json['latitude'] as num).toDouble(),
    lng: (json['longitude'] as num).toDouble(),
    hourlyPrice: (json['hourly_price_cents'] as num).toDouble() / 100,
    currency: (json['currency'] ?? 'EUR') as String,
    walkingMeters: 500,
    walkingMinutes: 7,
    available: true,
    instant: json['is_instant_bookable'] == true,
    covered: json['is_covered'] == true,
    ev: json['has_ev_charging'] == true,
    accessible: json['is_accessible'] == true,
    maxHeight: (json['max_height_m'] as num).toDouble(),
    maxWidth: (json['max_width_m'] as num).toDouble(),
    maxLength: (json['max_length_m'] as num).toDouble(),
    access: access,
    entranceSummary: 'Genaue Zufahrt nach bestätigter Buchung',
    hostType: 'FREIRAUM Partner',
    verified: json['is_verified'] == true,
    rating: (json['rating'] as num).toDouble(),
    reviewCount: json['review_count'] as int,
    cancellationSummary: 'Stornierungsbedingungen werden vor Buchung bestätigt',
    availabilityStatus: 'Verfügbarkeit wird live geprüft',
    visual: json['is_covered'] == true ? VisualType.garage : VisualType.privateOutdoor,
  );
}
