import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      bool changed = false;
      if (content.contains('SharePlus.instance.share(')) {
        content = content.replaceAll('SharePlus.instance.share(', 'Share.share(');
        changed = true;
      }
      if (changed) {
        entity.writeAsStringSync(content);
        print('Fixed Share in \${entity.path}');
      }
    }
  }
}
