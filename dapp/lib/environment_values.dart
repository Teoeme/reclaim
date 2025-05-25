import 'dart:convert';
import 'package:flutter/services.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFDevEnvironmentValues {
  static const String currentEnvironment = 'Production';
  static const String environmentValuesPath =
      'assets/environment_values/environment.json';

  static final FFDevEnvironmentValues _instance =
      FFDevEnvironmentValues._internal();

  factory FFDevEnvironmentValues() {
    return _instance;
  }

  FFDevEnvironmentValues._internal();

  Future<void> initialize() async {
    try {
      final String response =
          await rootBundle.loadString(environmentValuesPath);
      final data = await json.decode(response);
      _TokenStamping = data['TokenStamping'];
      _AvnuApiKey = data['AvnuApiKey'];
      _HashSecret = data['HashSecret'];
      _ContractAddress = data['ContractAddress'];
    } catch (e) {
      print('Error loading environment values: $e');
    }
  }

  String _TokenStamping = '';
  String get TokenStamping => _TokenStamping;
  
  String _AvnuApiKey = '';
  String get AvnuApiKey => _AvnuApiKey;
  
  String _HashSecret = '';
  String get HashSecret => _HashSecret;
  
  String _ContractAddress = '';
  String get ContractAddress => _ContractAddress;
}
