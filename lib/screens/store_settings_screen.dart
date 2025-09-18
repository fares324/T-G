// lib/screens/store_settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fouad_stock/model/store_details_model.dart';
import 'package:fouad_stock/screens/backup_restore_screen.dart';
import 'package:image_picker/image_picker.dart';
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
  
  String? _logoPath;
  String? _instaPayQrPath;
  String? _walletQrPath;

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

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final details = await _settingsService.getStoreDetails();
      
      if (mounted) {
        _nameController.text = details.name == SettingsService.defaultStoreName ? '' : details.name;
        _addressController.text = details.address == SettingsService.defaultStoreAddress ? '' : details.address;
        _phoneController.text = details.phone == SettingsService.defaultStorePhone ? '' : details.phone;
        setState(() {
          _logoPath = details.logoPath;
          _instaPayQrPath = details.instaPayQrPath;
          _walletQrPath = details.walletQrPath;
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      final newDetails = StoreDetails(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        logoPath: _logoPath,
        instaPayQrPath: _instaPayQrPath,
        walletQrPath: _walletQrPath,
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
          setState(() => _isSaving = false);
        }
      }
    }
  }
  
  Future<String?> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      return pickedFile?.path;
    } catch (e) {
      if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('فشل اختيار الصورة: $e', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
       );
      }
      return null;
    }
  }

  Future<void> _pickAndSetLogo() async {
    final path = await _pickImage();
    if (path != null) {
      setState(() => _logoPath = path);
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _logoPath = null);
  }

  Future<void> _pickAndSetInstaPayQr() async {
    final path = await _pickImage();
    if (path != null) {
      setState(() => _instaPayQrPath = path);
    }
  }

  Future<void> _removeInstaPayQr() async {
    setState(() => _instaPayQrPath = null);
  }

  Future<void> _pickAndSetWalletQr() async {
    final path = await _pickImage();
    if (path != null) {
      setState(() => _walletQrPath = path);
    }
  }

  Future<void> _removeWalletQr() async {
    setState(() => _walletQrPath = null);
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

  Widget _buildImagePickerCard({
    required BuildContext context,
    required String title,
    required String? imagePath,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final textStyleCairo = TextStyle(fontFamily: 'Cairo');
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
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
                  child: Icon(Icons.qr_code_scanner, color: Colors.grey.shade600, size: 50),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  label: Text('إزالة', style: textStyleCairo.copyWith(color: Colors.red)),
                  onPressed: imagePath != null ? onRemove : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text('اختيار صورة', style: textStyleCairo),
                  onPressed: onPick,
                ),
              ],
            )
          ],
        ),
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
                  
                  const Divider(height: 40, thickness: 1),

                  _buildSectionTitle(context, 'شعار المتجر'),
                  _buildImagePickerCard(
                    context: context,
                    title: 'سيظهر هذا الشعار أعلى الفاتورة',
                    imagePath: _logoPath,
                    onPick: _pickAndSetLogo,
                    onRemove: _removeLogo,
                  ),

                  const Divider(height: 40, thickness: 1),
                  
                  _buildSectionTitle(context, 'صور طرق الدفع'),
                  _buildImagePickerCard(
                    context: context,
                    title: 'صورة QR Code الخاصة بـ InstaPay',
                    imagePath: _instaPayQrPath,
                    onPick: _pickAndSetInstaPayQr,
                    onRemove: _removeInstaPayQr,
                  ),
                  _buildImagePickerCard(
                    context: context,
                    title: 'صورة QR Code لمحفظة الكاش',
                    imagePath: _walletQrPath,
                    onPick: _pickAndSetWalletQr,
                    onRemove: _removeWalletQr,
                  ),

                  const Divider(height: 40, thickness: 1),

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
                  const SizedBox(height: 30),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_outlined, color: Colors.white),
                          label: Text('حفظ كل الإعدادات', style: textStyleCairo.copyWith(fontSize: 18, color: Colors.white)),
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}