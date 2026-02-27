import 'dart:io';

void main() {
  final langs = ['en', 'es', 'hi', 'fr', 'ar', 'bn', 'ru', 'pt', 'id', 'de'];
  final dir = Directory('assets/translations');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  for (var lang in langs) {
    final file = File('assets/translations/$lang.json');
    file.writeAsStringSync('{"app_name": "DetectPlant"}');
  }
  print('Generated translation files.');
}
