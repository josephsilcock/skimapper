import 'package:diacritic/diacritic.dart';

/// Single home for accent and caps folding: names compare and match by this (F1 sort, F9 search).
String folded(String text) => removeDiacritics(text).toLowerCase();
