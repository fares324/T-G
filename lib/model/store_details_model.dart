// lib/models/store_details_model.dart

class StoreDetails {
  final String name;
  final String address;
  final String phone;
  // You can add more fields later, like tax ID, email, logo path, etc.

  StoreDetails({
    required this.name,
    required this.address,
    required this.phone,
  });

  // Optional: If you need to convert to/from JSON for any reason, though not strictly needed for SharedPreferences here
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
      };

  factory StoreDetails.fromJson(Map<String, dynamic> json) => StoreDetails(
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        phone: json['phone'] ?? '',
      );
}