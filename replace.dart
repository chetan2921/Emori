import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    if (content.contains('GoogleFonts')) {
      content = content.replaceAll(
        "import 'package:google_fonts/google_fonts.dart';",
        "",
      );
      content = content.replaceAll(
        "GoogleFonts.poppins",
        "TextStyle(fontFamily: 'PlusJakartaSans'",
      );
      content = content.replaceAll(
        "GoogleFonts.inter",
        "TextStyle(fontFamily: 'Nunito'",
      );
      file.writeAsStringSync(content);
      print('Updated \${file.path}');
    }
  }
}
