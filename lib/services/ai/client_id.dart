import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identificativo stabile per device/installazione, salvato in
/// `shared_preferences`. Usato come `X-Client-Id` verso il Worker e per il
/// rate limit lato server. Non è collegato a dati personali.
class ClientId {
  static const _kKey = 'ai.clientId';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kKey);
    if (id == null || id.length < 8) {
      id = const Uuid().v4().replaceAll('-', '');
      await prefs.setString(_kKey, id);
    }
    _cached = id;
    return id;
  }
}
