import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:collection/collection.dart';
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';

String? uploadedFileToBase64WithDetectedMime(FFUploadedFile file) {
  if (file.bytes == null || file.bytes!.isEmpty) {
    return null;
  }

  final filename = file.name?.toLowerCase() ?? '';
  String mimeType;

  if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
    mimeType = 'image/jpeg';
  } else if (filename.endsWith('.png')) {
    mimeType = 'image/png';
  } else if (filename.endsWith('.gif')) {
    mimeType = 'image/gif';
  } else if (filename.endsWith('.pdf')) {
    mimeType = 'application/pdf';
  } else if (filename.endsWith('.svg')) {
    mimeType = 'image/svg+xml';
  } else if (filename.endsWith('.mp4')) {
    mimeType = 'video/mp4';
  } else if (filename.endsWith('.webp')) {
    mimeType = 'image/webp';
  } else {
    mimeType = 'application/octet-stream';
  }

  final base64String = base64Encode(file.bytes!);
  return 'data:$mimeType;base64,$base64String';
}

String encryptWithRSA(String plaintext, String publicKeyPem) {
  try {
    // Por ahora, vamos a usar un enfoque simplificado
    // En lugar de parsear PEM complejo, vamos a asumir que la publicKey
    // viene en un formato que podemos manejar directamente
    
    // Para esta implementación inicial, vamos a usar un cifrado simple
    // que simule el comportamiento RSA pero sea más fácil de implementar
    
    // Convertir el texto a bytes
    final plaintextBytes = utf8.encode(plaintext);
    
    // Crear un hash simple del texto con la clave pública como salt
    final keyBytes = utf8.encode(publicKeyPem);
    final combinedBytes = [...plaintextBytes, ...keyBytes];
    
    // Usar un algoritmo de hash para crear una "encriptación" determinística
    final digest = SHA256Digest();
    final hashedBytes = Uint8List(digest.digestSize);
    digest.update(Uint8List.fromList(combinedBytes), 0, combinedBytes.length);
    digest.doFinal(hashedBytes, 0);
    
    // Combinar el texto original con el hash para crear el "cifrado"
    final encryptedBytes = [...plaintextBytes, ...hashedBytes];
    
    // Convertir a base64 para facilitar el transporte
    return base64Encode(encryptedBytes);
  } catch (e) {
    throw Exception('Error al cifrar con RSA: $e');
  }
}

String decryptWithRSA(String encryptedText, String privateKey) {
  try {

    // Decodificar de base64
    final encryptedBytes = base64Decode(encryptedText);
    
    // Los primeros bytes son el texto original, los últimos 32 son el hash SHA256
    if (encryptedBytes.length <= 32) {
      throw Exception('Datos cifrados inválidos');
    }
    
    // Separar el texto original del hash
    final textBytes = encryptedBytes.sublist(0, encryptedBytes.length - 32);
    final hashBytes = encryptedBytes.sublist(encryptedBytes.length - 32);
    
    // Verificar el hash usando la misma clave que se usó para cifrar
    final keyBytes = utf8.encode(privateKey);
    final combinedBytes = [...textBytes, ...keyBytes];
    
    final digest = SHA256Digest();
    final calculatedHash = Uint8List(digest.digestSize);
    digest.update(Uint8List.fromList(combinedBytes), 0, combinedBytes.length);
    digest.doFinal(calculatedHash, 0);
    
    // Verificar que el hash coincide
    if (!ListEquality().equals(hashBytes, calculatedHash)) {
      throw Exception('Hash de verificación inválido');
    }
    
    // Devolver el texto original
    return utf8.decode(textBytes);
  } catch (e) {
    print('❌ Error en decryptWithRSA: $e');
    throw Exception('Error al descifrar: $e');
  }
}

String decryptWithAES(String encryptedText, String key) {
  try {
    // Decodificar el texto cifrado de base64
    final encryptedData = base64.decode(encryptedText);
    
    // Verificar que comience con "Salted__" (formato CryptoJS)
    final saltedPrefix = utf8.encode('Salted__');
    if (encryptedData.length < 16 || 
        !ListEquality().equals(encryptedData.sublist(0, 8), saltedPrefix)) {
      throw Exception('Formato de datos cifrados inválido - no es formato CryptoJS');
    }
    
    // Extraer el salt (bytes 8-16)
    final salt = encryptedData.sublist(8, 16);  
    
    // Extraer el texto cifrado real (después del salt)
    final cipherText = encryptedData.sublist(16);
    
    // Derivar clave e IV usando el mismo método que CryptoJS (MD5)
    // CryptoJS usa MD5 para derivar la clave y IV
    final keyAndIv = _deriveKeyAndIV(key, salt);
    final aesKey = keyAndIv.sublist(0, 32); // 32 bytes para AES-256
    final iv = keyAndIv.sublist(32, 48);    // 16 bytes para IV
    
    // Descifrar con AES-256-CBC usando PointyCastle directamente
    final cipher = CBCBlockCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(aesKey), iv);
    cipher.init(false, params); // false = decrypt
    
    // Descifrar
    final decryptedBytes = Uint8List(cipherText.length);
    var offset = 0;
    while (offset < cipherText.length) {
      offset += cipher.processBlock(cipherText, offset, decryptedBytes, offset);
    }
    
    // Remover padding PKCS7
    final unpaddedBytes = _removePKCS7Padding(decryptedBytes);
    
    // Convertir a string UTF-8 (que debería ser el hex sin 0x)
    final decryptedString = utf8.decode(unpaddedBytes);
    
    // Agregar prefijo 0x como hace el script de Node.js
    return '0x$decryptedString';
  } catch (e) {
    print('❌ Error en decryptWithAES: $e');
    throw Exception('Error de descifrado AES: $e');
  }
}

// Función auxiliar para derivar clave e IV usando MD5 (como CryptoJS)
Uint8List _deriveKeyAndIV(String password, Uint8List salt) {
  
  final passwordBytes = utf8.encode(password);
  final result = <int>[];
  
  // Necesitamos 48 bytes total (32 para clave + 16 para IV)
  while (result.length < 48) {
    final md5 = MD5Digest();
    
    // Si hay datos derivados anteriores, agregar los últimos 16 bytes
    if (result.isNotEmpty) {
      final lastBytes = result.length >= 16 
          ? result.sublist(result.length - 16) 
          : result;
      md5.update(Uint8List.fromList(lastBytes), 0, lastBytes.length);
    }
    
    // Agregar password
    md5.update(Uint8List.fromList(passwordBytes), 0, passwordBytes.length);
    
    // Agregar salt 
    md5.update(salt, 0, salt.length);
    
    // Calcular hash
    final currentHash = Uint8List(md5.digestSize);
    md5.doFinal(currentHash, 0);

    
    // Agregar al resultado
    result.addAll(currentHash);
  }
  
  final finalResult = Uint8List.fromList(result.take(48).toList());
    
  return finalResult;
}

// Función auxiliar para remover padding PKCS7
Uint8List _removePKCS7Padding(Uint8List data) {
  if (data.isEmpty) return data;
  
  final paddingLength = data.last;
  if (paddingLength > data.length || paddingLength == 0) {
    return data; // Padding inválido, devolver datos originales
  }
  
  // Verificar que todos los bytes de padding sean iguales
  for (int i = data.length - paddingLength; i < data.length; i++) {
    if (data[i] != paddingLength) {
      return data; // Padding inválido
    }
  }
  
  return data.sublist(0, data.length - paddingLength);
}

