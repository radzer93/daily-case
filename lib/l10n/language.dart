import 'dart:ui';

const String defaultLanguage = 'pl';

const String languageHeader = 'x-lang';

const Map<String, String> languageNames = {
  'pl': 'Polski',
  'en': 'English',
};

String languageName(String code) => languageNames[code] ?? code.toUpperCase();

List<String> parseLanguages(String value) {
  final list = value
      .split(',')
      .map((l) => l.trim().toLowerCase())
      .where((l) => RegExp(r'^[a-z]{2}$').hasMatch(l))
      .toSet()
      .toList();
  return list.isEmpty ? const [defaultLanguage] : list;
}

List<String> supportedLanguages(List<String> requested, List<String> available) {
  final list = requested.where(available.contains).toList();
  return list.isEmpty ? const [defaultLanguage] : list;
}

String resolveLanguage(List<Locale> deviceLocales, List<String> enabled) {
  for (final locale in deviceLocales) {
    final code = locale.languageCode.toLowerCase();
    if (enabled.contains(code)) return code;
  }
  return enabled.contains(defaultLanguage) ? defaultLanguage : enabled.first;
}
