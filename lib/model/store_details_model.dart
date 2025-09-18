// lib/models/store_details_model.dart

class StoreDetails {
  final String name;
  final String address;
  final String phone;
  // --- ADDED: Fields for image paths ---
  final String? logoPath;
  final String? instaPayQrPath;
  final String? walletQrPath;

  StoreDetails({
    required this.name,
    required this.address,
    required this.phone,
    // --- ADDED: Optional parameters for images ---
    this.logoPath,
    this.instaPayQrPath,
    this.walletQrPath,
  });

  // Optional: If you need to convert to/from JSON for any reason
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
        'logoPath': logoPath,
        'instaPayQrPath': instaPayQrPath,
        'walletQrPath': walletQrPath,
      };

  factory StoreDetails.fromJson(Map<String, dynamic> json) => StoreDetails(
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        phone: json['phone'] ?? '',
        logoPath: json['logoPath'],
        instaPayQrPath: json['instaPayQrPath'],
        walletQrPath: json['walletQrPath'],
      );
}