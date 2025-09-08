// lib/screens/store_settings_screen.dart
import 'dart:io'; // Needed for File operations
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/store_details_model.dart';
import 'package:fouad_stock/screens/backup_restore_screen.dart';
import 'package:image_picker/image_picker.dart'; // Import the image_picker package
import '../services/settings_service.dart';

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
  
  // --- NEW: State variable for the logo path ---
  String? _logoPath;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final details = await _settingsService.getStoreDetails();
      final logoPath = await _settingsService.getStoreLogo();
      
      if (mounted) {
        _nameController.text = details.name == SettingsService.defaultStoreName ? '' : details.name;
        _addressController.text = details.address == SettingsService.defaultStoreAddress ? '' : details.address;
        _phoneController.text = details.phone == SettingsService.defaultStorePhone ? '' : details.phone;
        setState(() {
          _logoPath = logoPath;
        });
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

      try {
        await _settingsService.saveStoreDetails(newDetails);
        
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
  
  // --- NEW: Method to pick an image from the gallery ---
  Future<void> _pickLogo() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        await _settingsService.saveStoreLogo(pickedFile.path);
        setState(() {
          _logoPath = pickedFile.path;
        });
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الشعار بنجاح!', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل اختيار الشعار: $e', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
       }
    }
  }

  // --- NEW: Method to remove the logo ---
  Future<void> _removeLogo() async {
    await _settingsService.clearStoreLogo();
    setState(() {
      _logoPath = null;
    });
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إزالة الشعار.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
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
    final textStyleCairo = TextStyle(fontFamily: 'Cairo');

    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات التطبيق', style: textStyleCairo.copyWith(color: theme.colorScheme.onPrimary)),
        backgroundColor: Colors.teal.shade900,
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
                            backgroundColor: Colors.teal.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                  const Divider(height: 40, thickness: 1),

                  // --- NEW: Store Logo Section ---
                  _buildSectionTitle(context, 'شعار المتجر'),
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (_logoPath != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_logoPath!),
                                width: 150,
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.red, size: 50),
                              ),
                            )
                          else
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400)
                              ),
                              child: Center(
                                child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade600, size: 50),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                                label: Text('إزالة الشعار', style: textStyleCairo.copyWith(color: Colors.red)),
                                onPressed: _logoPath != null ? _removeLogo : null,
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text('اختيار شعار', style: textStyleCairo),
                                onPressed: _pickLogo,
                              ),
                            ],
                          )
                        ],
                      ),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
