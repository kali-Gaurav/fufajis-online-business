import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (var file in files) {
    final content = file.readAsStringSync();
    if (content.contains('DecoratedBox') && content.contains('ListTile')) {
      print('DecoratedBox+ListTile in: ' + file.path);
    }
    if (content.contains('Container(') && content.contains('ListTile') && content.contains('decoration:')) {
      print('Container(decoration)+ListTile in: ' + file.path);
    }
  }
}
