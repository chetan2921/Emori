import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    if (content.contains("TextStyle(fontFamily: 'Nunito'(") ||
        content.contains("TextStyle(fontFamily: 'PlusJakartaSans'(")) {
      content = content.replaceAll(
        "TextStyle(fontFamily: 'Nunito'(",
        "TextStyle(fontFamily: 'Nunito', ",
      );
      content = content.replaceAll(
        "TextStyle(fontFamily: 'PlusJakartaSans'(",
        "TextStyle(fontFamily: 'PlusJakartaSans', ",
      );
      // Fix empty parameters edge case: `TextStyle(fontFamily: 'Nunito', )` is valid.
      file.writeAsStringSync(content);
      print('Fixed \${file.path}');
    }
  }
}
