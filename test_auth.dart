import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  
  final client = Supabase.instance.client;
  
  // Try to create a dummy account to see what happens
  final rand = Random().nextInt(10000);
  final email = "test_user_$rand@example.com";
  final password = "password123";
  
  print("Attempting to sign up $email...");
  try {
    final response = await client.auth.signUp(email: email, password: password);
    print("Sign up complete. Session: ${response.session != null}");
    print("User: ${response.user?.id}");
    
    // Now try to sign in
    print("Attempting to sign in...");
    final signInResponse = await client.auth.signInWithPassword(email: email, password: password);
    print("Sign in complete. Session: ${signInResponse.session != null}");
    
  } catch (e) {
    print("Error occurred: $e");
  }
}
