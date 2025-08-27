/// String utilities for the app.
String titleCase(String input) {
  final s = input.trim();
  if (s.isEmpty) return input;
  return s
      .split(RegExp(r'\s+'))
      .map(
        (w) =>
            w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1).toLowerCase()),
      )
      .join(' ');
}
