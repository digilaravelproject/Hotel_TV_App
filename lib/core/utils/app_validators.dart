class AppValidators {

  /// Validate name (only alphabets & spaces)
  static String? validateName(
      String? value, {
        String fieldName = "Name",
        int minLength = 2,
        String? customMessage,
      }) {
    final trimmed = value?.trim() ?? "";

    if (trimmed.isEmpty) {
      return "$fieldName is required";
    }

    if (trimmed.length < minLength) {
      return "$fieldName must be at least $minLength characters";
    }

    final nameRegex = RegExp(r'^[a-zA-Z ]+$');
    if (!nameRegex.hasMatch(trimmed)) {
      return customMessage ?? "Enter a valid $fieldName";
    }

    return null;
  }


  /// Validate if field is not empty
  static String? validateEmpty(
      String? value, {
        String fieldName = "Field",
        String? customMessage,
      }) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) {
      return customMessage ?? "$fieldName is required";
    }
    return null;
  }

  /// Validate mobile number (default 10 digits)
  static String? validatePhone(
      String? value, {
        int length = 10,
        String? customMessage,
      }) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) {
      return "Mobile number is required";
    }
    final pattern = RegExp(r'^[0-9]{' + length.toString() + r'}$');
    if (!pattern.hasMatch(trimmed)) {
      return customMessage ?? "Enter a valid $length-digit mobile number";
    }
    return null;
  }

  /// Validate email
  static String? validateEmail(
      String? value, {
        String? customMessage,
      }) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) {
      return "Email is required";
    }
    final _emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');
    if (!_emailRegex.hasMatch(trimmed)) {
      return customMessage ?? "Enter a valid email address";
    }
    return null;
  }
}
