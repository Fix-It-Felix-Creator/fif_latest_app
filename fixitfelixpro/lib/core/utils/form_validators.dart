/// Form validation utilities for the application
/// Centralizes all form validation logic to avoid duplication
class FormValidators {
  FormValidators._();

  // ============ NAME VALIDATORS ============

  /// Validates first name
  /// - Required
  /// - Minimum 2 characters
  /// - Only letters, spaces, hyphens, and apostrophes allowed
  static String? validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'First name is required';
    }
    if (value.length < 2) {
      return 'First name must be at least 2 characters';
    }
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return 'First name can only contain letters';
    }
    return null;
  }

  /// Validates last name
  /// - Required
  /// - Minimum 2 characters
  /// - Only letters, spaces, hyphens, and apostrophes allowed
  static String? validateLastName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Last name is required';
    }
    if (value.length < 2) {
      return 'Last name must be at least 2 characters';
    }
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return 'Last name can only contain letters';
    }
    return null;
  }

  /// Validates business name
  /// - Required
  /// - Minimum 2 characters
  static String? validateBusinessName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Business name is required';
    }
    if (value.length < 2) {
      return 'Business name must be at least 2 characters';
    }
    return null;
  }

  // ============ CONTACT VALIDATORS ============

  /// Validates email address
  /// - Required
  /// - Must be valid email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates optional email (allows empty)
  static String? validateOptionalEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return validateEmail(value);
  }

  /// Validates UK phone number
  /// - Required
  /// - Must be 11 digits
  /// - Must start with 0
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 11) {
      return 'Please enter a valid 11-digit UK phone number';
    }
    if (!value.startsWith('0')) {
      return 'Phone number must start with 0';
    }
    return null;
  }

  /// Validates optional phone number (allows empty)
  static String? validateOptionalPhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return validatePhoneNumber(value);
  }

  // ============ ADDRESS VALIDATORS ============

  /// Validates address line 1
  /// - Required
  /// - Minimum 5 characters
  static String? validateAddressLine1(String? value) {
    if (value == null || value.isEmpty) {
      return 'Address line 1 is required';
    }
    if (value.length < 5) {
      return 'Please enter a valid address';
    }
    return null;
  }

  /// Validates optional address line 2 (always valid)
  static String? validateAddressLine2(String? value) {
    return null;
  }

  /// Validates city
  /// - Required
  /// - Minimum 2 characters
  /// - Only letters, spaces, and hyphens allowed
  static String? validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'City is required';
    }
    if (value.length < 2) {
      return 'Please enter a valid city name';
    }
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(value)) {
      return 'City can only contain letters';
    }
    return null;
  }

  /// Validates UK postcode
  /// - Required
  /// - Must match UK postcode format
  static String? validatePostcode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Postcode is required';
    }
    // UK postcode regex pattern
    final postcodeRegex = RegExp(
      r'^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$',
      caseSensitive: false,
    );
    if (!postcodeRegex.hasMatch(value)) {
      return 'Please enter a valid UK postcode';
    }
    return null;
  }

  /// Validates county (optional, but if provided must be valid)
  static String? validateCounty(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length < 2) {
      return 'Please enter a valid county name';
    }
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(value)) {
      return 'County can only contain letters';
    }
    return null;
  }

  // ============ PASSWORD VALIDATORS ============

  /// Validates password
  /// - Required
  /// - Minimum 8 characters
  /// - Must contain uppercase, lowercase, number
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Validates password confirmation
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ============ GENERIC VALIDATORS ============

  /// Validates required field
  static String? validateRequired(String? value, [String? fieldName]) {
    if (value == null || value.isEmpty) {
      return fieldName != null
          ? '$fieldName is required'
          : 'This field is required';
    }
    return null;
  }

  /// Validates minimum length
  static String? validateMinLength(
    String? value,
    int minLength, [
    String? fieldName,
  ]) {
    if (value == null || value.isEmpty) {
      return null; // Use validateRequired for required check
    }
    if (value.length < minLength) {
      return fieldName != null
          ? '$fieldName must be at least $minLength characters'
          : 'Must be at least $minLength characters';
    }
    return null;
  }

  /// Validates maximum length
  static String? validateMaxLength(
    String? value,
    int maxLength, [
    String? fieldName,
  ]) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length > maxLength) {
      return fieldName != null
          ? '$fieldName must be at most $maxLength characters'
          : 'Must be at most $maxLength characters';
    }
    return null;
  }

  // ============ AMOUNT/NUMBER VALIDATORS ============

  /// Validates positive number
  static String? validatePositiveNumber(String? value, [String? fieldName]) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }
    if (number < 0) {
      return fieldName != null
          ? '$fieldName must be positive'
          : 'Value must be positive';
    }
    return null;
  }

  /// Validates amount/price
  static String? validateAmount(String? value, {bool required = false}) {
    if (value == null || value.isEmpty) {
      return required ? 'Amount is required' : null;
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount < 0) {
      return 'Amount cannot be negative';
    }
    return null;
  }
}
