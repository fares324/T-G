// lib/screens/store_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/store_details_model.dart';
import 'package:fouad_stock/screens/backup_restore_screen.dart'; // Import BackupRestoreScreen
import '../services/settings_service.dart'; // Your SettingsService

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final SettingsService _settingsService = SettingsService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  // Add controllers for new settings if needed in the future
  // late TextEditingController _defaultTaxController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    // _defaultTaxController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final details = await _settingsService.getStoreDetails();
      // final defaultTax = await _settingsService.getDefaultTaxRate(); // Example
      if (mounted) {
        _nameController.text = details.name == SettingsService.defaultStoreName ? '' : details.name;
        _addressController.text = details.address == SettingsService.defaultStoreAddress ? '' : details.address;
        _phoneController.text = details.phone == SettingsService.defaultStorePhone ? '' : details.phone;
        // _defaultTaxController.text = defaultTax?.toString() ?? ''; // Example
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الإعدادات: $e', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });

      final newDetails = StoreDetails(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      // final newDefaultTax = double.tryParse(_defaultTaxController.text.trim()); // Example

      try {
        await _settingsService.saveStoreDetails(newDetails);
        // if (newDefaultTax != null) { // Example
        //   await _settingsService.saveDefaultTaxRate(newDefaultTax);
        // } else if (_defaultTaxController.text.trim().isEmpty) {
        //   await _settingsService.clearDefaultTaxRate();
        // }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الإعدادات بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حفظ الإعدادات: $e', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    // _defaultTaxController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, right: 8.0, left: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontFamily: 'Cairo',
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyleCairo = TextStyle(fontFamily: 'Cairo'); // Base Cairo font style

    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات التطبيق', style: textStyleCairo.copyWith(color: theme.colorScheme.onPrimary)),
        backgroundColor: Colors.teal.shade900, // Dark teal background
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  // --- Store Information Section ---
                  _buildSectionTitle(context, 'معلومات المتجر'),
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'أدخل معلومات متجرك التي ستظهر في الفواتير.',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'Cairo',
                              color: theme.colorScheme.onSurface.withOpacity(0.7)
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            textAlign: TextAlign.right,
                            style: textStyleCairo,
                            decoration: InputDecoration(
                              labelText: 'اسم المتجر*',
                              labelStyle: textStyleCairo,
                              hintText: 'مثال: صيدلية الشفاء',
                              hintStyle: textStyleCairo.copyWith(color: Colors.grey),
                              prefixIcon: Icon(Icons.store_outlined, color: theme.primaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال اسم المتجر.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            textAlign: TextAlign.right,
                            style: textStyleCairo,
                            decoration: InputDecoration(
                              labelText: 'عنوان المتجر*',
                              labelStyle: textStyleCairo,
                              hintText: 'مثال: 123 شارع النصر، القاهرة',
                              hintStyle: textStyleCairo.copyWith(color: Colors.grey),
                              prefixIcon: Icon(Icons.location_on_outlined, color: theme.primaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال عنوان المتجر.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            textAlign: TextAlign.right,
                            style: textStyleCairo,
                            decoration: InputDecoration(
                              labelText: 'رقم هاتف المتجر*',
                              labelStyle: textStyleCairo,
                              hintText: 'مثال: 01xxxxxxxxx',
                              hintStyle: textStyleCairo.copyWith(color: Colors.grey),
                              prefixIcon: Icon(Icons.phone_outlined, color: theme.primaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال رقم الهاتف.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_outlined, color: Colors.white),
                          label: Text('حفظ معلومات المتجر', style: textStyleCairo.copyWith(fontSize: 18, color: Colors.white)),
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade900, // Dark teal button
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                  const Divider(height: 40, thickness: 1),

                  // --- Data Management Section ---
                  _buildSectionTitle(context, 'إدارة البيانات'),
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.backup_outlined, color: theme.primaryColor),
                          title: Text('النسخ الاحتياطي والاستعادة', style: textStyleCairo.copyWith(fontSize: 16)),
                          subtitle: Text('حفظ أو استعادة بيانات التطبيق', style: textStyleCairo.copyWith(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BackupRestoreScreen()),
                            );
                          },
                        ),
                        // Add more data management options here if needed (e.g., Clear Data - with extreme caution)
                      ],
                    ),
                  ),
                  const Divider(height: 40, thickness: 1),
                  
                  // --- Placeholder for Invoice Settings ---
                  // _buildSectionTitle(context, 'إعدادات الفواتير (قريباً)'),
                  // Card(
                  //   elevation: 2,
                  //   margin: const EdgeInsets.symmetric(vertical: 8.0),
                  //   child: ListTile(
                  //     leading: Icon(Icons.receipt_long_outlined, color: Colors.grey),
                  //     title: Text('معدل الضريبة الافتراضي', style: textStyleCairo.copyWith(fontSize: 16, color: Colors.grey)),
                  //     subtitle: Text('سيتم تطبيقه على الفواتير الجديدة', style: textStyleCairo.copyWith(fontSize: 12, color: Colors.grey)),
                  //      enabled: false, // Disabled for now
                  //      onTap: () { /* TODO: Implement tax settings */},
                  //   ),
                  // ),

                  // Add more settings sections or items here
                ],
              ),
            ),
    );
  }
}










// import 'package:flutter/material.dart';
// import 'package:fouad_stock/model/store_details_model.dart';
// import '../services/settings_service.dart'; // Your SettingsService

// class StoreSettingsScreen extends StatefulWidget {
//   const StoreSettingsScreen({super.key});

//   @override
//   State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
// }

// class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final SettingsService _settingsService = SettingsService();

//   late TextEditingController _nameController;
//   late TextEditingController _addressController;
//   late TextEditingController _phoneController;

//   bool _isLoading = true;
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _addressController = TextEditingController();
//     _phoneController = TextEditingController();
//     _loadSettings();
//   }

//   Future<void> _loadSettings() async {
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final details = await _settingsService.getStoreDetails();
//       if (mounted) {
//         // Use the public static constants from SettingsService for comparison
//         _nameController.text = details.name == SettingsService.defaultStoreName ? '' : details.name;
//         _addressController.text = details.address == SettingsService.defaultStoreAddress ? '' : details.address;
//         _phoneController.text = details.phone == SettingsService.defaultStorePhone ? '' : details.phone;
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('فشل تحميل الإعدادات: $e', textAlign: TextAlign.right)),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _saveSettings() async {
//     if (_formKey.currentState!.validate()) {
//       _formKey.currentState!.save(); // Not strictly needed as controllers hold values
//       setState(() {
//         _isSaving = true;
//       });

//       final newDetails = StoreDetails(
//         name: _nameController.text.trim(),
//         address: _addressController.text.trim(),
//         phone: _phoneController.text.trim(),
//       );

//       try {
//         await _settingsService.saveStoreDetails(newDetails);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('تم حفظ الإعدادات بنجاح!', textAlign: TextAlign.right),
//               backgroundColor: Colors.green,
//             ),
//           );
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('فشل حفظ الإعدادات: $e', textAlign: TextAlign.right),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       } finally {
//         if (mounted) {
//           setState(() {
//             _isSaving = false;
//           });
//         }
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _addressController.dispose();
//     _phoneController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('إعدادات المتجر'),
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)))
//           : Form(
//               key: _formKey,
//               child: ListView(
//                 padding: const EdgeInsets.all(16.0),
//                 children: <Widget>[
//                   Text(
//                     'أدخل معلومات متجرك التي ستظهر في الفواتير.',
//                     style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
//                     textAlign: TextAlign.right,
//                   ),
//                   const SizedBox(height: 20),
//                   TextFormField(
//                     controller: _nameController,
//                     textAlign: TextAlign.right,
//                     decoration: const InputDecoration(
//                       labelText: 'اسم المتجر*',
//                       hintText: 'مثال: صيدلية الشفاء',
//                       prefixIcon: Icon(Icons.store_outlined),
//                     ),
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return 'الرجاء إدخال اسم المتجر.';
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: _addressController,
//                     textAlign: TextAlign.right,
//                     decoration: const InputDecoration(
//                       labelText: 'عنوان المتجر*',
//                       hintText: 'مثال: 123 شارع النصر، القاهرة',
//                       prefixIcon: Icon(Icons.location_on_outlined),
//                     ),
//                     maxLines: 2, // Allow for a slightly longer address
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return 'الرجاء إدخال عنوان المتجر.';
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: _phoneController,
//                     textAlign: TextAlign.right,
//                     decoration: const InputDecoration(
//                       labelText: 'رقم هاتف المتجر*',
//                       hintText: 'مثال: 01xxxxxxxxx',
//                       prefixIcon: Icon(Icons.phone_outlined),
//                     ),
//                     keyboardType: TextInputType.phone,
//                     validator: (value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return 'الرجاء إدخال رقم الهاتف.';
//                       }
//                       // Add more sophisticated phone validation if needed
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 30),
//                   _isSaving
//                       ? const Center(child: CircularProgressIndicator())
//                       : ElevatedButton.icon(
//                           icon: const Icon(Icons.save_alt_outlined),
//                           label: const Text('حفظ الإعدادات'),
//                           onPressed: _saveSettings,
//                           style: ElevatedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                             textStyle: const TextStyle(fontSize: 18, fontFamily: 'Cairo'), // Ensure font
//                           ),
//                         ),
//                 ],
//               ),
//             ),
//     );
//   }
// }