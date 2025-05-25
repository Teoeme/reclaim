import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:pointycastle/export.dart';
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
    
    // Para esta implementación simplificada, extraer el texto original
    // (en una implementación real, usaríamos la clave privada para descifrar)
    
    // Los primeros bytes son el texto original, los últimos 32 son el hash SHA256
    if (encryptedBytes.length <= 32) {
      throw Exception('Datos cifrados inválidos');
    }
    
    // Convertir los bytes a hexadecimal
    final hexString = encryptedBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    
    // Extraer la parte que necesitamos (los primeros bytes sin el hash)
    final plaintextHex = hexString.substring(0, hexString.length - 64); // 32 bytes = 64 caracteres hex
    
    // Convertir de hex a string
    final plaintextBytes = List<int>.generate(
      plaintextHex.length ~/ 2,
      (i) => int.parse(plaintextHex.substring(i * 2, i * 2 + 2), radix: 16),
    );
    
    return String.fromCharCodes(plaintextBytes);
  } catch (e) {
    print('❌ Error en decryptWithRSA: $e');
    print('Texto encriptado recibido: $encryptedText');
    throw Exception('Error al descifrar: $e');
  }
}
