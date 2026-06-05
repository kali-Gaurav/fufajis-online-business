import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {
  @override
  List<String>? getStringList(String key) => [];

  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
}
