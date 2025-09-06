// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:fouad_stock/screens/splash_screen.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _onOnboardingDone(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  // A custom widget to create the styled graphic area for each page
  Widget _buildGraphic(IconData icon) {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.teal.shade800.withOpacity(0.5), // A lighter dark teal for the circle
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, size: 100, color: Colors.tealAccent.shade100), // Bright accent color for the icon
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define text styles for the dark theme
    const bodyStyle = TextStyle(fontSize: 18.0, fontFamily: 'Cairo', color: Colors.white70, height: 1.6);
    const titleStyle = TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white);

    // Define the page decoration for the dark theme
    const pageDecoration = PageDecoration(
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
      pageColor: Colors.transparent, 
      imagePadding: EdgeInsets.only(top: 80, bottom: 24),
      bodyAlignment: Alignment.center,
    );

    return IntroductionScreen(
      // --- UI Customization with "Teal Dark" Background ---
      globalBackgroundColor: Colors.teal.shade900, // Main dark teal background color
      
      pages: [
        PageViewModel(
          title: "إدارة شاملة للمخزون",
          body: "تتبع كل قطعة في مخزونك بدقة وسهولة، من الكميات والأسعار إلى تواريخ الانتهاء.",
          image: _buildGraphic(Icons.inventory_2_outlined),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "فواتير احترافية بلمسة زر",
          body: "أنشئ فواتير بيع وشراء مفصلة، مع تحديث تلقائي للمخزون بعد كل عملية.",
          image: _buildGraphic(Icons.receipt_long_outlined),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "تقارير ذكية لأعمالك",
          body: "احصل على رؤى قيمة حول أداء مبيعاتك وحالة المخزون، وقم بتصدير البيانات بسهولة.",
          image: _buildGraphic(Icons.bar_chart_rounded),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "بياناتك في أمان تام",
          body: "مع خاصية النسخ الاحتياطي والاستعادة، كن مطمئنًا أن بيانات عملك محمية دائمًا.",
          image: _buildGraphic(Icons.verified_user_outlined),
          decoration: pageDecoration,
        ),
      ],
      
      onDone: () => _onOnboardingDone(context),
      onSkip: () => _onOnboardingDone(context),

      // --- Controls Styling ---
      showSkipButton: true,
      skip: const Text('تخطي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white60)),
      next: const Icon(Icons.arrow_forward, color: Colors.white),
      
      done: const Text(
        'ابدأ الآن', 
        style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo', color: Colors.teal) // Dark teal text on light button
      ),
      doneStyle: ElevatedButton.styleFrom(
        backgroundColor: Colors.tealAccent.shade100, // Vibrant accent color for the button
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      
      // Dots Indicator Styling
      dotsDecorator: const DotsDecorator(
        size: Size(8.0, 8.0),
        color: Colors.white24,
        activeColor: Colors.tealAccent,
        activeSize: Size(20.0, 8.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}