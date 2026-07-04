import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  int totalFixed = 0;

  for (var file in files) {
    String content = file.readAsStringSync();
    bool changed = false;
    
    int index = 0;
    while (true) {
      index = content.indexOf('ListTile(', index);
      if (index == -1) break;

      // Check if it's already wrapped in Material
      int materialIdx = content.lastIndexOf('Material(', index);
      if (materialIdx != -1) {
        String between = content.substring(materialIdx, index);
        if (!between.contains(')')) { 
            index += 9;
            continue;
        }
      }
      
      // Check for const before ListTile
      int constIndex = content.lastIndexOf('const ', index);
      bool isConst = false;
      if (constIndex != -1 && (index - constIndex) < 10) {
        String between = content.substring(constIndex + 6, index).trim();
        if (between.isEmpty) {
          isConst = true;
        }
      }

      int openBrackets = 0;
      int matchIndex = -1;
      for (int i = index + 8; i < content.length; i++) {
        if (content[i] == '(') openBrackets++;
        if (content[i] == ')') {
          openBrackets--;
          if (openBrackets == 0) {
            matchIndex = i;
            break;
          }
        }
      }

      if (matchIndex != -1) {
        String before = isConst ? content.substring(0, constIndex) : content.substring(0, index);
        String listTileStr = content.substring(index, matchIndex + 1);
        String after = content.substring(matchIndex + 1);
        
        // Wrap in Material. If it was const, we make the Material const.
        String replacement = 'Material(color: Colors.transparent, child: ' + (isConst ? 'const ' : '') + listTileStr + ')';
        if (isConst) replacement = 'const ' + replacement;
        
        content = before + replacement + after;
        changed = true;
        index = before.length + replacement.length;
      } else {
        index += 9;
      }
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Fixed: ' + file.path);
      totalFixed++;
    }
  }
  print('Total files fixed: $totalFixed');
}
