/// Validate a given [ip] string.
///
/// Rules are:
///   - ip must be in ipv4 format.
///
/// Returns an error string in the event of any issues, else null.
String? validateIP(String ip) {
  RegExp ipRegex = RegExp(r"^(\d{1,3}\.){3}\d{1,3}$");

  if (!ipRegex.hasMatch(ip)) {
    return "IP must be in ipv4 format.";
  }
  return null;
}

/// Validate a given [password] string.
///
/// Rules are:
///   - Password must have at least 6 characters.
///
/// Returns an error string in the event of any issues, else null.
String? validatePassword(String password) {
  if (password.isEmpty) {
    return "Please provide a password.";
  }
  return null;
}
