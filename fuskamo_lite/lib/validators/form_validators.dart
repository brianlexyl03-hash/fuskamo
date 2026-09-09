class FormValidators {
  FormValidators._();

  static String? requiredText(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) return 'Age is required';
    final n = int.tryParse(value);
    if (n == null) return 'Enter a valid age';
    if (n < 10 || n > 45) return 'Age must be between 10 and 45';
    return null;
  }

  /// Optional field — only validates format when something was typed.
  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
    return ok ? null : 'Enter a valid email';
  }

  /// Optional field — expects a plain phone number, digits and a leading +.
  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final ok = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value.trim());
    return ok ? null : 'Enter a valid phone number (digits only, optional +)';
  }
}
