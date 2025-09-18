// lib/services/settings_service.dart
import 'package:fouad_stock/model/store_details_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _storeNameKey = 'store_name';
  static const String _storeAddressKey = 'store_address';
  static const String _storePhoneKey = 'store_phone';
  static const String _storeLogoKey = 'store_logo';
  static const String _instaPayQrKey = 'insta_pay_qr';
  static const String _walletQrKey = 'wallet_qr';

  static const String defaultStoreName = "اسم متجرك";
  static const String defaultStoreAddress = "ادخل العنوان من الإعدادات";
  static const String defaultStorePhone = "ادخل الهاتف من الإعدادات";

  /// Saves all store details at once, including image paths.
  Future<void> saveStoreDetails(StoreDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeNameKey, details.name);
    await prefs.setString(_storeAddressKey, details.address);
    await prefs.setString(_storePhoneKey, details.phone);
    // Handle nullable paths
    if (details.logoPath != null) {
      await prefs.setString(_storeLogoKey, details.logoPath!);
    } else {
      await prefs.remove(_storeLogoKey);
    }
    if (details.instaPayQrPath != null) {
      await prefs.setString(_instaPayQrKey, details.instaPayQrPath!);
    } else {
      await prefs.remove(_instaPayQrKey);
    }
    if (details.walletQrPath != null) {
      await prefs.setString(_walletQrKey, details.walletQrPath!);
    } else {
      await prefs.remove(_walletQrKey);
    }
  }

  /// Retrieves all store details in a single object.
  Future<StoreDetails> getStoreDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return StoreDetails(
      name: prefs.getString(_storeNameKey) ?? defaultStoreName,
      address: prefs.getString(_storeAddressKey) ?? defaultStoreAddress,
      phone: prefs.getString(_storePhoneKey) ?? defaultStorePhone,
      logoPath: prefs.getString(_storeLogoKey),
      instaPayQrPath: prefs.getString(_instaPayQrKey),
      walletQrPath: prefs.getString(_walletQrKey),
    );
  }

  // --- Methods for handling the store logo ---
  Future<void> saveStoreLogo(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeLogoKey, imagePath);
  }

  Future<String?> getStoreLogo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeLogoKey);
  }

  Future<void> clearStoreLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeLogoKey);
  }

  // --- ADDED: Methods for handling the InstaPay QR code ---
  Future<void> saveInstaPayQr(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_instaPayQrKey, imagePath);
  }

  Future<String?> getInstaPayQr() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_instaPayQrKey);
  }

  Future<void> clearInstaPayQr() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_instaPayQrKey);
  }

  // --- ADDED: Methods for handling the Wallet QR code ---
  Future<void> saveWalletQr(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_walletQrKey, imagePath);
  }

  Future<String?> getWalletQr() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_walletQrKey);
  }

  Future<void> clearWalletQr() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_walletQrKey);
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