// lib/services/activation_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

class ActivationService {
  static const _activationKey = 'is_activated';
  
  // This is the HASH of your password "Fares97996924"
  // It is safe to store this here.
  static const String _correctPasswordHash = r'$2a$12$FC/iaoicRebgYldXxhy0Fu3r4x.BCWJ2IqIEVaPDegz2Vl4uyMXL2';

  // Checks if the entered password matches the stored hash
  Future<bool> checkPassword(String enteredPassword) async {
    try {
      return BCrypt.checkpw(enteredPassword, _correctPasswordHash);
    } catch(e) {
      print("Error checking password: $e");
      return false;
    }
  }

  // Activates the app by saving a flag to the device's local storage
  Future<void> activateApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationKey, true);
  }

  // Checks if the app has been activated before
  Future<bool> isAppActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationKey) ?? false;
  }
}
