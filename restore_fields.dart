import 'dart:io';

void main() {
  final lines = File('unused.txt').readAsLinesSync();
  for (var line in lines) {
    if (line.contains('UNUSED_FIELD') || line.contains('_razorpayWebhookSecret') || line.contains('_phoneId')) {
      final parts = line.split('|');
      if (parts.length < 5) continue;
      final filePath = parts[3];
      final lineNum = int.parse(parts[4]) - 1;
      
      final file = File(filePath);
      if (!file.existsSync()) continue;
      final fileLines = file.readAsLinesSync();
      
      if (fileLines[lineNum].startsWith('// ')) {
        fileLines[lineNum] = fileLines[lineNum].substring(3);
        file.writeAsStringSync(fileLines.join('\n') + '\n');
        print('Restored line \${lineNum + 1} in \$filePath');
      }
    }
  }
}
