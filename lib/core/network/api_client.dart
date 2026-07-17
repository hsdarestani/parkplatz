import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/environment.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message, {this.code});
  final String message;
  final String? code;
  @override String toString() => message;
}
class ApiOfflineException extends ApiException { const ApiOfflineException():super('Der Server ist gerade nicht erreichbar.'); }
class ApiUnauthorizedException extends ApiException { const ApiUnauthorizedException([String message='Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.']):super(message); }
class ApiValidationException extends ApiException { const ApiValidationException(super.message,{super.code}); }
class ApiConflictException extends ApiException { const ApiConflictException(super.message,{super.code}); }
class ApiNotFoundException extends ApiException { const ApiNotFoundException([String message='Der Eintrag wurde nicht gefunden.']):super(message); }
class ApiServerException extends ApiException { const ApiServerException():super('Der Server ist vorübergehend nicht verfügbar.'); }

abstract interface class ApiTokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

class ApiClient {
  ApiClient(this.tokens, [http.Client? client]) : client = client ?? http.Client();
  final ApiTokenStore tokens;
  final http.Client client;
  Future<bool>? _refreshing;
  static const timeout = Duration(seconds: 8);

  Uri _uri(String path, [Map<String,String>? query]) {
    final base=Environment.apiBaseUrl.endsWith('/')?Environment.apiBaseUrl.substring(0,Environment.apiBaseUrl.length-1):Environment.apiBaseUrl;
    return Uri.parse('$base${path.startsWith('/')?path:'/$path'}').replace(queryParameters: query);
  }

  Future<bool> health() async {
    try {
      final r=await client.get(_uri('/health')).timeout(const Duration(seconds:3));
      final body=jsonDecode(r.body);
      return r.statusCode==200 && body is Map && body['status']=='ok' && body['database']=='connected';
    } catch (_) { return false; }
  }

  Future<dynamic> get(String path,{Map<String,String>? query,bool authenticated=true}) => _request('GET',path,query:query,authenticated:authenticated);
  Future<dynamic> post(String path,{Object? body,bool authenticated=true}) => _request('POST',path,body:body,authenticated:authenticated);
  Future<dynamic> patch(String path,{Object? body}) => _request('PATCH',path,body:body);
  Future<void> delete(String path) async { await _request('DELETE',path); }

  Future<dynamic> _request(String method,String path,{Object? body,Map<String,String>? query,bool authenticated=true,bool retried=false}) async {
    final headers=<String,String>{'Accept':'application/json','Content-Type':'application/json'};
    if(authenticated){final token=await tokens.readAccess(); if(token!=null) headers['Authorization']='Bearer $token';}
    http.Response response;
    try {
      final request=http.Request(method,_uri(path,query))..headers.addAll(headers);
      if(body!=null) request.body=jsonEncode(body);
      response=await http.Response.fromStream(await client.send(request).timeout(timeout));
    } on TimeoutException catch (_) { throw const ApiOfflineException(); }
      on http.ClientException catch (_) { throw const ApiOfflineException(); }
    if(response.statusCode==401 && authenticated && !retried && await _refresh()) return _request(method,path,body:body,query:query,authenticated:true,retried:true);
    if(response.statusCode==204) return null;
    dynamic decoded; try { decoded=response.body.isEmpty?null:jsonDecode(response.body); } catch (_) { decoded=null; }
    if(response.statusCode>=200 && response.statusCode<300) return decoded;
    final detail=decoded is Map?decoded['detail']:null;
    final data=detail is Map?detail:decoded is Map?decoded:<String,dynamic>{};
    final message=data is Map && data['message'] is String?data['message'] as String:null;
    final code=data is Map?data['code']?.toString():null;
    switch(response.statusCode){
      case 401: await tokens.clear(); throw ApiUnauthorizedException(message??'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.');
      case 404: throw ApiNotFoundException(message??'Der Eintrag wurde nicht gefunden.');
      case 409: throw ApiConflictException(message??'Dieser Zeitraum wurde gerade gebucht. Bitte wähle eine andere Zeit.',code:code);
      case 400: case 422: throw ApiValidationException(message??'Bitte prüfe deine Eingaben.',code:code);
      default: throw const ApiServerException();
    }
  }

  Future<bool> _refresh() {
    final active = _refreshing;
    if (active != null) return active;
    final refresh = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = refresh;
    return refresh;
  }
  Future<bool> _doRefresh() async {
    final refresh=await tokens.readRefresh(); if(refresh==null) return false;
    try {
      final response=await post('/auth/refresh',body:{'refresh_token':refresh},authenticated:false);
      await tokens.save(response['access_token'] as String,response['refresh_token'] as String); return true;
    } catch (_) { await tokens.clear(); return false; }
  }
}
