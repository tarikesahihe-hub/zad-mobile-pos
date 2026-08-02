import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'activation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(
    const ActivationScreen(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zad POS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zad POS'),
      ),
      body: const Center(
        child: Text(
          'Welcome to Zad POS System',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
