// lib/screens/backup_restore_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator and Uint8List
import 'dart:io'; // For File, Platform, exit(), FileSystemException
import 'package:path_provider/path_provider.dart'; // For getting directory paths
import 'package:file_picker/file_picker.dart';    // For picking/saving files
import 'package:path/path.dart' as p;             // For path manipulation
import 'package:intl/intl.dart';                 // For timestamp in filename

// IMPORTANT: Adjust the path to your DatabaseHelper file if necessary
import 'package:fouad_stock/helpers/db_helpers.dart';

class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  // Method to handle the backup logic (uses FilePicker.platform.saveFile with bytes)
  Future<void> _performBackup(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    try {
      // 1. Get the path to the app's database file (internal storage)
      Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
      String dbName = "MedicalStore.db"; // From your DatabaseHelper
      String originalDbPath = p.join(appDocumentsDirectory.path, dbName);
      File originalDbFile = File(originalDbPath);

      if (!await originalDbFile.exists()) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'خطأ: ملف قاعدة البيانات الأصلي (${dbName}) غير موجود!',
              style: TextStyle(fontFamily: 'Cairo', color: theme.colorScheme.onError),
            ),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        return;
      }

      // 2. Read the database file into bytes
      Uint8List fileBytes = await originalDbFile.readAsBytes();

      // 3. Prepare a suggested backup filename
      String timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      String suggestedFileName = 'FouadStock_Backup_$timestamp.db';

      // 4. Let the user pick a location and name to save the file, providing the bytes
      String? savedFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان واسم ملف النسخة الاحتياطية:',
        fileName: suggestedFileName,
        bytes: fileBytes, // Provide the file bytes directly
      );

      // If saveFile returns a path, it means the file was successfully written by the plugin.
      print("[BackupRestoreScreen] Backup saved by plugin to: $savedFilePath");

      scaffoldMessenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم حفظ النسخة الاحتياطية بنجاح!',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'المسار: $savedFilePath',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
        ),
      );

    } catch (e, s) {
      print("[BackupRestoreScreen] Backup Error: $e");
      print("[BackupRestoreScreen] Backup StackTrace: $s");
      String errorMessage = 'فشل إنشاء النسخة الاحتياطية: $e';
      if (e is FileSystemException && (e.osError?.errorCode == 1 || e.osError?.errorCode == 13 || e.message.toLowerCase().contains("permission denied") || e.message.toLowerCase().contains("operation not permitted"))) {
          errorMessage = 'فشل إنشاء النسخة الاحتياطية: خطأ في صلاحيات الوصول إلى الملفات أو المسار المختار.';
      } else if (e.toString().toLowerCase().contains("bytes are required")) {
          errorMessage = 'فشل إنشاء النسخة الاحتياطية: خطأ في تمرير بيانات الملف.';
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: TextStyle(fontFamily: 'Cairo', color: theme.colorScheme.onError),
          ),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }

  // Method to handle the restore logic (with "Unsupported filter" fix)
  Future<void> _performRestore(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);

    try {
      bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('تحذير هام!', style: TextStyle(fontFamily: 'Cairo', color: Colors.red[700], fontSize: 18, fontWeight: FontWeight.bold)),
            content: const Text(
              'هل أنت متأكد أنك تريد استعادة البيانات من نسخة احتياطية؟\nسيتم الكتابة فوق جميع البيانات الحالية في التطبيق بشكل كامل. لا يمكن التراجع عن هذه العملية.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
              textAlign: TextAlign.right,
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: <Widget>[
              TextButton(
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: theme.textTheme.bodyLarge?.color ?? Colors.black, fontSize: 14)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                child: const Text('نعم، قم بالاستعادة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('تم إلغاء عملية الاستعادة.', style: TextStyle(fontFamily: 'Cairo'))),
        );
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'اختر ملف النسخة الاحتياطية (يجب أن يكون ملف .db)',
      );

      if (result == null || result.files.single.path == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('لم يتم اختيار ملف. تم إلغاء الاستعادة.', style: TextStyle(fontFamily: 'Cairo'))),
        );
        return;
      }

      String pickedFilePath = result.files.single.path!;

      if (!pickedFilePath.toLowerCase().endsWith('.db')) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'ملف غير صالح. الرجاء اختيار ملف نسخة احتياطية بامتداد .db',
              style: TextStyle(fontFamily: 'Cairo', color: theme.colorScheme.onError),
            ),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        return;
      }

      File backupFile = File(pickedFilePath);

      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbName = "MedicalStore.db";
      String activeDbPath = p.join(documentsDirectory.path, dbName);
      File activeDbFile = File(activeDbPath);

      await DatabaseHelper.closeDatabaseInstance();

      if (await activeDbFile.exists()) {
        await activeDbFile.delete();
        print("[BackupRestoreScreen] Deleted existing database file: $activeDbPath");
      }

      await backupFile.copy(activeDbPath);
      print("[BackupRestoreScreen] Copied backup file to: $activeDbPath");

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('نجاح!', style: TextStyle(fontFamily: 'Cairo', color: Colors.green[700], fontSize: 18, fontWeight: FontWeight.bold)),
            content: const Text(
              'تم استعادة البيانات بنجاح. يرجى إعادة تشغيل التطبيق الآن لتطبيق التغييرات بشكل كامل.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
              textAlign: TextAlign.right,
            ),
            actions: <Widget>[
              TextButton(
                child: Text('حسنًا، سأقوم بإعادة التشغيل', style: TextStyle(fontFamily: 'Cairo', color: Colors.green[700], fontSize: 14)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (Platform.isAndroid) {
                    SystemNavigator.pop();
                  } else if (Platform.isIOS) {
                    // exit(0); // Programmatic exit on iOS is generally discouraged.
                  }
                },
              ),
            ],
          );
        },
      );

      if (navigator.canPop()) {
         navigator.pop();
      }

    } catch (e, s) {
      print("[BackupRestoreScreen] Restore Error: $e");
      print("[BackupRestoreScreen] Restore StackTrace: $s");
      try {
        await DatabaseHelper.instance.database;
        print("[BackupRestoreScreen] Database re-initialized after error.");
      } catch (dbError) {
        print("[BackupRestoreScreen] Failed to re-initialize database after restore error: $dbError");
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('فشل استعادة البيانات: $e', style: TextStyle(fontFamily: 'Cairo', color: theme.colorScheme.onError)),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle bodyTextStyle = theme.textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo', fontSize: 15) ??
                                  const TextStyle(fontFamily: 'Cairo', fontSize: 15);
    final TextStyle buttonTextStyle = theme.textTheme.labelLarge?.copyWith(fontFamily: 'Cairo', color: Colors.white, fontSize: 16) ??
                                     const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16);
    final TextStyle appBarTextStyle = theme.textTheme.titleLarge?.copyWith(fontFamily: 'Cairo', color: theme.colorScheme.onPrimary) ??
                                     const TextStyle(fontFamily: 'Cairo', fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold);
    final TextStyle warningTitleTextStyle = bodyTextStyle.copyWith(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 17);
    final TextStyle warningBodyTextStyle = bodyTextStyle.copyWith(color: Colors.red[700], fontSize: 14);

    return Scaffold(
      appBar: AppBar(
        title: Text('النسخ الاحتياطي والاستعادة', style: appBarTextStyle),
        backgroundColor:Colors.teal.shade900,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'قم بحماية بياناتك عن طريق إنشاء نسخة احتياطية بانتظام. يمكنك استعادة بياناتك من نسخة احتياطية محفوظة مسبقًا في أي وقت.',
              style: bodyTextStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            ElevatedButton.icon(
              icon: const Icon(Icons.backup, color: Colors.white),
              label: Text('إنشاء نسخة احتياطية', style: buttonTextStyle),
              onPressed: () => _performBackup(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              icon: const Icon(Icons.restore, color: Colors.white),
              label: Text('استعادة نسخة احتياطية', style: buttonTextStyle),
              onPressed: () => _performRestore(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[600]!, width: 1),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'تحذير هام عند الاستعادة!',
                    style: warningTitleTextStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'استعادة نسخة احتياطية سيقوم بالكتابة فوق جميع البيانات الحالية في التطبيق بشكل كامل. لا يمكن التراجع عن هذه العملية. تأكد من اختيار الملف الصحيح وأنك تفهم ما تقوم به قبل المتابعة.',
                    style: warningBodyTextStyle,
                    textAlign: TextAlign.center,
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