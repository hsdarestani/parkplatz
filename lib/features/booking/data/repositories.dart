import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TokenStorage { Future<void> write(String access, String refresh); Future<String?> readAccess(); Future<void> clear(); }
class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage storage; const SecureTokenStorage([this.storage = const FlutterSecureStorage()]);
  @override Future<void> write(String access, String refresh) async { await storage.write(key: 'access', value: access); await storage.write(key: 'refresh', value: refresh); }
  @override Future<String?> readAccess() => storage.read(key: 'access');
  @override Future<void> clear() => storage.deleteAll();
}
abstract interface class AuthRepository { Future<void> login(String email, String password); Future<void> register(String name, String email, String password); Future<void> logout(); bool get authenticated; }
class LocalBetaAuthRepository implements AuthRepository {
  static bool _authenticated = false;
  @override bool get authenticated => _authenticated;
  @override Future<void> login(String email, String password) async { if (!email.contains('@') || password.length < 8) throw const FormatException('E-Mail oder Passwort ist ungültig.'); _authenticated = true; }
  @override Future<void> register(String name, String email, String password) => login(email, password);
  @override Future<void> logout() async => _authenticated = false;
}
class BookingRecord {
  final String id, parkingId, title, reference, plate, status;
  final DateTime start, end;
  final int totalCents;
  const BookingRecord({required this.id, required this.parkingId, required this.title, required this.reference, required this.plate, required this.status, required this.start, required this.end, required this.totalCents});
  Map<String,dynamic> toJson()=>{'id':id,'parkingId':parkingId,'title':title,'reference':reference,'plate':plate,'status':status,'start':start.toIso8601String(),'end':end.toIso8601String(),'totalCents':totalCents};
  factory BookingRecord.fromJson(Map<String,dynamic> j)=>BookingRecord(id:j['id'],parkingId:j['parkingId'],title:j['title'],reference:j['reference'],plate:j['plate'],status:j['status'],start:DateTime.parse(j['start']),end:DateTime.parse(j['end']),totalCents:j['totalCents']);
  BookingRecord cancelled()=>BookingRecord(id:id,parkingId:parkingId,title:title,reference:reference,plate:plate,status:'cancelled',start:start,end:end,totalCents:totalCents);
}
abstract interface class BookingRepository { Future<List<BookingRecord>> all(); Future<BookingRecord> create(BookingRecord booking); Future<void> cancel(String id); }
class LocalBetaBookingRepository implements BookingRepository {
  static const _key='local_beta_bookings';
  @override Future<List<BookingRecord>> all() async { final p=await SharedPreferences.getInstance(); return (p.getStringList(_key)??[]).map((e)=>BookingRecord.fromJson(jsonDecode(e))).toList(); }
  Future<void> _save(List<BookingRecord> values) async { final p=await SharedPreferences.getInstance(); await p.setStringList(_key,values.map((e)=>jsonEncode(e.toJson())).toList()); }
  @override Future<BookingRecord> create(BookingRecord booking) async { final values=await all(); if(!values.any((b)=>b.id==booking.id)){values.add(booking); await _save(values);} return booking; }
  @override Future<void> cancel(String id) async { final values=await all(); await _save(values.map((b)=>b.id==id?b.cancelled():b).toList()); }
}
