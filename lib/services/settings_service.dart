// lib/services/settings_service.dart
import 'package:fouad_stock/model/store_details_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _storeNameKey = 'store_name';
  static const String _storeAddressKey = 'store_address';
  static const String _storePhoneKey = 'store_phone';
  // --- NEW: Key for saving the logo image path ---
  static const String _storeLogoKey = 'store_logo';

  static const String defaultStoreName = "اسم متجرك";
  static const String defaultStoreAddress = "ادخل العنوان من الإعدادات";
  static const String defaultStorePhone = "ادخل الهاتف من الإعدادات";

  Future<void> saveStoreDetails(StoreDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeNameKey, details.name);
    await prefs.setString(_storeAddressKey, details.address);
    await prefs.setString(_storePhoneKey, details.phone);
  }

  Future<StoreDetails> getStoreDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return StoreDetails(
      name: prefs.getString(_storeNameKey) ?? defaultStoreName,
      address: prefs.getString(_storeAddressKey) ?? defaultStoreAddress,
      phone: prefs.getString(_storePhoneKey) ?? defaultStorePhone,
    );
  }

  Future<String> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeNameKey) ?? defaultStoreName;
  }

  Future<String> getStoreAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeAddressKey) ?? defaultStoreAddress;
  }

  Future<String> getStorePhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storePhoneKey) ?? defaultStorePhone;
  }
  
  // --- NEW: Methods for handling the store logo ---

  /// Saves the file path of the store logo.
  Future<void> saveStoreLogo(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeLogoKey, imagePath);
  }

  /// Retrieves the saved file path of the store logo.
  /// Returns null if no logo is set.
  Future<String?> getStoreLogo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeLogoKey);
  }

  /// Removes the saved store logo path.
  Future<void> clearStoreLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeLogoKey);
  }
}


// // lib/services/settings_service.dart
// // lib/services/settings_service.dart
// import 'package:fouad_stock/model/store_details_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class SettingsService {
//   static const String _storeNameKey = 'store_name';
//   static const String _storeAddressKey = 'store_address';
//   static const String _storePhoneKey = 'store_phone';

//   // *** CHANGED: Made default constants public by removing underscore ***
//   static const String defaultStoreName = "Ｔ & Ｇ 𝓤𝓷𝓲𝓯𝓸𝓻𝓶";
//   static const String defaultStoreAddress = "ادخل العنوان من الإعدادات";
//   static const String defaultStorePhone = "ادخل الهاتف من الإعدادات";


//   Future<void> saveStoreDetails(StoreDetails details) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_storeNameKey, details.name);
//     await prefs.setString(_storeAddressKey, details.address);
//     await prefs.setString(_storePhoneKey, details.phone);
//   }

//   Future<StoreDetails> getStoreDetails() async {
//     final prefs = await SharedPreferences.getInstance();
//     return StoreDetails(
//       name: prefs.getString(_storeNameKey) ?? defaultStoreName, // Use public constant
//       address: prefs.getString(_storeAddressKey) ?? defaultStoreAddress, // Use public constant
//       phone: prefs.getString(_storePhoneKey) ?? defaultStorePhone, // Use public constant
//     );
//   }

//   // Individual getters also use public constants for their defaults
//   Future<String> getStoreName() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_storeNameKey) ?? defaultStoreName;
//   }

//   Future<String> getStoreAddress() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_storeAddressKey) ?? defaultStoreAddress;
//   }

//   Future<String> getStorePhone() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_storePhoneKey) ?? defaultStorePhone;
//   }
// }