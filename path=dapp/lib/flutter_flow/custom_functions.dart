import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/pointycastle.dart';

String decryptWithAES(String encryptedText, String key) {
  try {
    // Decodificar el texto cifrado que incluye el salt
    final encryptedData = base64.decode(encryptedText);
    
    // Extraer el salt (bytes 8-16)
    final salt = encryptedData.sublist(8, 16);
    
    // Extraer el texto cifrado real (después del salt)
    final cipherText = encryptedData.sublist(16);
    
    // Derivar clave e IV usando PBKDF2 con SHA1 y 1000 iteraciones
    final keyGen = PBKDF2KeyDerivator(HMac(SHA1Digest()))
      ..init(Pbkdf2Parameters(salt, 1000, 32 + 16)); // 32 bytes key + 16 bytes IV
    
    final keyAndIv = keyGen.process(Uint8List.fromList(utf8.encode(key)));
    
    // Separar clave y IV
    final aesKey = Key(keyAndIv.sublist(0, 32));
    final iv = IV(keyAndIv.sublist(32, 48));
    
    // Descifrar con AES-256-CBC
    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt(Encrypted(cipherText), iv: iv);
    
    // Convertir a hexadecimal y agregar prefijo 0x
    final hexString = decrypted.codeUnits
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    
    return '0x$hexString';
  } catch (e) {
    print('Error en decryptWithAES: $e');
    throw Exception('Error de descifrado AES: $e');
  }
}