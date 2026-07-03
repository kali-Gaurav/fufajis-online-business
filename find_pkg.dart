import 'dart:io';
import 'dart:convert';
void main() {
  final file = File('.dart_tool/package_config.json');
  final json = jsonDecode(file.readAsStringSync());
  final pkg = json['packages'].firstWhere((p) => p['name'] == 'google_sign_in');
  print(pkg['rootUri']);
}
