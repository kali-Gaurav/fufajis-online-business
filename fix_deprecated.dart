import 'dart:io';

void main() {
  final dir = Directory('lib');
  int opacityCount = 0;
  int shareCount = 0;
  
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      bool changed = false;
      
      final opacityRegex = RegExp(r'\.withOpacity\(([^)]+)\)');
      if (opacityRegex.hasMatch(content)) {
        content = content.replaceAllMapped(opacityRegex, (match) {
          opacityCount++;
          return '.withValues(alpha: \${match.group(1)})';
        });
        changed = true;
      }
      
      if (content.contains('Share.share(')) {
        if (!content.contains("import 'package:share_plus/share_plus.dart';")) {
          content = "import 'package:share_plus/share_plus.dart';\n" + content;
        }
        content = content.replaceAll('Share.share(', 'SharePlus.instance.share(');
        content = content.replaceAll("import 'package:share/share.dart';\n", "");
        shareCount++;
        changed = true;
      }
      
      if (changed) {
        entity.writeAsStringSync(content);
      }
    }
  }
  if (opacityCount >= 0 && shareCount >= 0) {
    stdout.writeln('Replaced $opacityCount withOpacity calls and $shareCount Share.share calls.');
  }
}
