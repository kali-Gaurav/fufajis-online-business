import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      bool changed = false;
      
      // Share.share('text', subject: 'sub') -> SharePlus.instance.share(ShareParams(text: 'text', subject: 'sub'))
      final regexWithSubject = RegExp(r'Share\.share\(([^,]+),\s*subject:\s*([^)]+)\)');
      if (regexWithSubject.hasMatch(content)) {
        content = content.replaceAllMapped(regexWithSubject, (match) {
          return 'SharePlus.instance.share(ShareParams(text: \${match.group(1)}, subject: \${match.group(2)}))';
        });
        changed = true;
      }
      
      // Share.share('text') -> SharePlus.instance.share(ShareParams(text: 'text'))
      final regexNoSubject = RegExp(r'Share\.share\(([^,)]+)\)');
      if (regexNoSubject.hasMatch(content)) {
        content = content.replaceAllMapped(regexNoSubject, (match) {
          return 'SharePlus.instance.share(ShareParams(text: \${match.group(1)}))';
        });
        changed = true;
      }

      if (changed) {
        if (!content.contains("import 'package:share_plus/share_plus.dart';")) {
          content = "import 'package:share_plus/share_plus.dart';\n" + content;
        }
        entity.writeAsStringSync(content);
        print('Updated Share in \${entity.path}');
      }
    }
  }
}
