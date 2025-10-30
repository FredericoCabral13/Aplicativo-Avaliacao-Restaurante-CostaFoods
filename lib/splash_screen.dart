import 'package:flutter/material.dart';
import 'main.dart'; // ✅ Certifique-se deste import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('🎯 SplashScreen iniciada'); // ✅ DEBUG

    Future.delayed(const Duration(seconds: 2), () {
      print('🎯 Navegando para AppTabsController...'); // ✅ DEBUG

      Navigator.of(context)
          .pushReplacement(
            MaterialPageRoute(builder: (context) => const AppTabsController()),
          )
          .then((_) {
            print('🎯 Navegação completada'); // ✅ DEBUG
          })
          .catchError((error) {
            print('❌ Erro na navegação: $error'); // ✅ DEBUG
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/logo_costa_feedbacks_icone.png',
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.fromARGB(255, 111, 136, 63),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
