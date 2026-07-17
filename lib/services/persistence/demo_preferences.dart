import 'package:shared_preferences/shared_preferences.dart';
class DemoPreferences{static const keys=['destination','vehicle','filters'];Future<void> reset()async{final p=await SharedPreferences.getInstance();for(final k in keys){await p.remove(k);}}}
