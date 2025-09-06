// lib/main.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/screens/activation_screen.dart';
import 'package:fouad_stock/screens/on_boarding_screen.dart';
import 'package:fouad_stock/screens/splash_screen.dart';
import 'package:fouad_stock/services/activation_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';

// Your project files
import 'package:fouad_stock/helpers/db_helpers.dart';
import 'package:fouad_stock/providers/product_provider.dart';
import 'package:fouad_stock/providers/invoice_provider.dart';

// Import the package for desktop support
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
  }
  
  // --- NEW: Check activation status FIRST ---
  final activationService = ActivationService();
  final bool isAppActivated = await activationService.isAppActivated();
  // --- END NEW ---

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  await DatabaseHelper.instance.database;
  
  // Pass BOTH flags to the MyApp widget
  runApp(MyApp(
    onboardingCompleted: onboardingCompleted,
    isAppActivated: isAppActivated,
  ));
}

class MyApp extends StatelessWidget {
  final bool onboardingCompleted;
  // --- NEW: Add isAppActivated property ---
  final bool isAppActivated;

  const MyApp({
    super.key, 
    required this.onboardingCompleted,
    required this.isAppActivated,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProductProvider()..fetchProducts()),
        ChangeNotifierProvider(create: (context) => InvoiceProvider()),
      ],
      child: MaterialApp(
        title: 'Fouad Stock',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Cairo',
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.teal.shade900,
            foregroundColor: Colors.white,
            elevation: 2.0,
            titleTextStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.teal, width: 2.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
            labelStyle: TextStyle(color: Colors.teal.shade800),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontFamily: 'Cairo', fontSize: 16.0),
            bodyMedium: TextStyle(fontFamily: 'Cairo', fontSize: 14.0),
            labelLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
        ),
        locale: const Locale('ar', ''),
        supportedLocales: const [
          Locale('ar', ''),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // --- NEW: Conditionally set the home screen based on activation status first ---
        home: isAppActivated
          ? (onboardingCompleted ? const SplashScreen() : const OnboardingScreen())
          : const ActivationScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}











































































// import 'package:flutter/material.dart';
// import 'package:fouad_stock/helpers/db_helpers';
// // Assuming your database helper file is db_helpers.dart inside the helpers folder
// // And the class inside is DatabaseHelper
// import 'package:fouad_stock/providers/product_provider.dart';
// import 'package:fouad_stock/screens/product_list_screen.dart'; // Corrected from product_list_screen
// import 'package:provider/provider.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:fouad_stock/providers/invoice_provider.dart'; // Add this

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   // Make sure the class name here matches the one in your db_helpers.dart file
//   await DatabaseHelper.instance.database;
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   // It's good practice to add a key to the constructor if it's public
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (context) => ProductProvider()..fetchProducts(),
//       child: MaterialApp(
//         title: 'مدير متجر مستلزمات طبية', // App Title in Arabic
//         theme: ThemeData(
//           primarySwatch: Colors.teal,
//           visualDensity: VisualDensity.adaptivePlatformDensity,
//           fontFamily: 'Cairo', // Consider adding an Arabic font like 'Cairo' or 'Tajawal' to your assets
//           appBarTheme: const AppBarTheme(
//             backgroundColor: Colors.teal,
//             foregroundColor: Colors.white,
//           ),
//           floatingActionButtonTheme: const FloatingActionButtonThemeData(
//             backgroundColor: Colors.amber,
//           ),
//           inputDecorationTheme: InputDecorationTheme(
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8.0),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderSide: const BorderSide(color: Colors.teal, width: 2.0),
//               borderRadius: BorderRadius.circular(8.0),
//             ),
//           ),
//           elevatedButtonTheme: ElevatedButtonThemeData(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.teal,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//               textStyle: const TextStyle(fontSize: 16),
//             ),
//           ),
//         ),
//         // Arabic Language Settings
//         locale: const Locale('ar', ''), // Set locale to Arabic
//         supportedLocales: const [
//           Locale('ar', ''), // Arabic
//         ],
//         localizationsDelegates: const [
//           GlobalMaterialLocalizations.delegate,
//           GlobalWidgetsLocalizations.delegate,
//           GlobalCupertinoLocalizations.delegate,
//         ],
//         home: ProductsListScreen(), // Ensure this screen name is correct
//         debugShowCheckedModeBanner: false,
//       ),
//     );
//   }
// }