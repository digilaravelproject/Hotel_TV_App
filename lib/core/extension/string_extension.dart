extension TextTransformExtension on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1).toLowerCase();

  String capitalizeEachWord() =>
      split(' ')
          .map((e) => e.isEmpty ? e : e.capitalize())
          .join(' ');
}
