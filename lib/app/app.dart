// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/auth_gate.dart';
import 'package:red_cell_net_final/main.dart'; // For navigatorKey
// Import details page - needed if using named routes, good practice otherwise
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Assign the global key to the MaterialApp
      navigatorKey: navigatorKey, // <-- ADD THIS LINE
      title:
          'RedCellNet', // Make sure this matches name changes elsewhere if needed
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.redAccent,
          textTheme: ButtonTextTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Entry point remains AuthGate
      // TODO: Define routes later for named navigation if needed
      // routes: {
      //   '/request_details': (context) => RequestDetailsPage(requestId: ''), // Example structure
      // },
    );
  }
}
