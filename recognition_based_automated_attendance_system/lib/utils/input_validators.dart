final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmailAddress(String value) {
  return _emailPattern.hasMatch(value.trim());
}
