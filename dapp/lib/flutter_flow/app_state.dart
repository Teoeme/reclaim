import 'package:flutter/material.dart';
import '/backend/api_requests/api_calls.dart';

class AppState extends ChangeNotifier {
  static AppState? _instance;
  static AppState get instance => _instance ??= AppState._();
  
  AppState._();

  // Información del wallet del usuario
  String? _userPublicKey;
  String? _userPrivateKey;
  String? _userWalletAddress;
  bool _walletLoaded = false;

  // Getters
  String? get userPublicKey => _userPublicKey;
  String? get userPrivateKey => _userPrivateKey;
  String? get userWalletAddress => _userWalletAddress;
  bool get walletLoaded => _walletLoaded;

  // Método para cargar la información del wallet
  Future<void> loadWalletInfo(String firebaseUserUuid) async {
    try {
      final walletResponse = await CreateOGetWalletCall.call(
        firebaseUserUuid: firebaseUserUuid,
      );

      if (walletResponse?.succeeded ?? false) {
        _userPublicKey = CreateOGetWalletCall.publicKey(walletResponse?.jsonBody);
        _userPrivateKey = CreateOGetWalletCall.encryptedPrivateKey(walletResponse?.jsonBody);
        _userWalletAddress = CreateOGetWalletCall.address(walletResponse?.jsonBody);
        _walletLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading wallet info: $e');
    }
  }

  // Método para limpiar la información del wallet (logout)
  void clearWalletInfo() {
    _userPublicKey = null;
    _userPrivateKey = null;
    _userWalletAddress = null;
    _walletLoaded = false;
    notifyListeners();
  }

  // Método para verificar si tenemos la información necesaria
  bool hasWalletInfo() {
    return _userPublicKey != null && _userPublicKey!.isNotEmpty;
  }
} 