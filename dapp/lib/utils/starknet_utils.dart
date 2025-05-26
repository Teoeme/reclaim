import 'package:starknet_provider/starknet_provider.dart';
import 'package:starknet/starknet.dart' show Felt;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/api.dart';
import 'package:asn1lib/asn1lib.dart';
import '/flutter_flow/custom_functions.dart' as functions;

class StarknetUtils {
  /// Obtiene el selector de una función del contrato usando el ABI
  static Future<Felt> getFunctionSelector(
    JsonRpcProvider provider,
    String contractAddress,
    String functionName,
  ) async {
    try {
      // Obtener la clase del contrato para ver los entrypoints disponibles
      final classAt = await provider.getClassAt(
        blockId: BlockId.latest,
        contractAddress: Felt.fromHexString(contractAddress),
      );

      final contractData = classAt.toJson();
      
      if (contractData['result'] != null) {
        final result = contractData['result'];
        
        // Obtener el ABI del contrato y parsearlo
        final abiJson = result['abi'] as String;
        final abi = jsonDecode(abiJson) as List;
        
        // Encontrar la interfaz del contrato
        final interface = abi.firstWhere(
          (item) => item['type'] == 'interface' && item['name'] == 'contracts::reclaim::IReclaim',
          orElse: () => <String, dynamic>{},
        );
        
        if (interface.isNotEmpty) {
          // Encontrar la función en el ABI
          final function = interface['items'].firstWhere(
            (item) => item['type'] == 'function' && item['name'] == functionName,
            orElse: () => <String, dynamic>{},
          );
          
          if (function.isNotEmpty) {
            // Obtener los entrypoints externos
            final entrypoints = result['entry_points_by_type']['EXTERNAL'] as List;
            
            // El índice de la función en el ABI corresponde al function_idx en los entrypoints
            final functionIndex = interface['items'].indexOf(function);
            
            // Encontrar el entrypoint correspondiente
            final entrypoint = entrypoints.firstWhere(
              (ep) => ep['function_idx'] == functionIndex,
              orElse: () => <String, dynamic>{},
            );
            
            if (entrypoint.isNotEmpty) {
              final selectorHex = entrypoint['selector'] as String;
              
              // Asegurar que el selector tenga el formato correcto
              final cleanHex = selectorHex.startsWith('0x') ? selectorHex.substring(2) : selectorHex;
              final selector = Felt.fromHexString('0x$cleanHex');
              
              return selector;
            }
          }
        }
      }
      
      throw Exception('No se encontró el selector para la función $functionName');
    } catch (e) {
      print('❌ Error al obtener el selector: $e');
      rethrow;
    }
  }

  /// Parsea los records del contrato
 static List<ContractRecord> parseContractRecords(List<Felt> flat) {
  final records = <ContractRecord>[];
  
  try {
    // El primer elemento es la cantidad de records
    final count = BigInt.parse(flat[0].toString()).toInt();
    
    int index = 1; // Empezamos después de [cantidad]
    
    for (int i = 0; i < count; i++) {
      
      // 1. CID (ByteArray)
      final cidByteArray = _parseByteArray(flat, index);
      final cid = _byteArrayToString(cidByteArray);
      index = cidByteArray.nextIndex;
      
      // 2. Hash commit (felt252)
      final hashCommitFelt = flat[index].toBigInt();
      final hashCommit = '0x${hashCommitFelt.toRadixString(16).padLeft(64, '0')}';
      print('🔍 Hash commit original: $hashCommit');
      index++;
      
      // 3. Timestamp (felt252)
      final timestampRaw = BigInt.parse(flat[index].toString()).toInt();
      final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampRaw * 1000);
      index++;
      
      // 4. Access type (felt252)
      final accessTypeFelt = flat[index].toBigInt();
      String accessType;
      try {
        final accessTypeStr = _byteArrayToString(ByteArrayResult(
          data: [accessTypeFelt],
          pendingWord: BigInt.zero,
          pendingLen: 0,
          nextIndex: 0
        ));
        accessType = accessTypeStr == 'timestamp' || accessTypeStr == 'heirs' 
          ? accessTypeStr 
          : 'timestamp';
      } catch (e) {
        print('⚠️  Error decodificando access type: $e');
        accessType = 'timestamp';
      }
      index++;
      
      // 5. Name (ByteArray)
      final nameByteArray = _parseByteArray(flat, index);
      final name = _byteArrayToString(nameByteArray);
      index = nameByteArray.nextIndex;
      
      records.add(ContractRecord(
        cid: cid,
        hashCommit: hashCommit,
        timestamp: timestamp,
        accessType: accessType,
        name: name.isNotEmpty ? name : 'Memoria sin título',
      ));
      
      print('✅ Record parseado:');
      print('  - CID: $cid');
      print('  - Hash Commit: $hashCommit');
      print('  - Timestamp: $timestamp');
      print('  - Access Type: $accessType');
      print('  - Name: $name');
    }
  } catch (e) {
    print('❌ Error parseando records: $e');
  }
  
  return records;
}
}

/// Parsea los records del contrato
/// Estructura de cada record: (ByteArray, felt252, felt252, felt252, ByteArray)
/// Donde:
/// - ByteArray: CID
/// - felt252: hash_commit
/// - felt252: timestamp
/// - felt252: access_type
/// - ByteArray: name
class ContractRecord {
  final String cid;
  final String hashCommit;
  final DateTime timestamp;
  final String accessType;
  final String name;

  ContractRecord({
    required this.cid,
    required this.hashCommit,
    required this.timestamp,
    required this.accessType,
    required this.name,
  });
}

/// Parsea un ByteArray de Cairo
/// Estructura: [longitud_array, ...elementos, pending_word, pending_len]
ByteArrayResult _parseByteArray(List<Felt> flat, int startIndex) {
  int index = startIndex;
  
  try {
    
    // Leer longitud del array
    final length = BigInt.parse(flat[index].toString()).toInt();
    index++;
    
    // Leer elementos del array
    final data = <BigInt>[];
    for (int i = 0; i < length; i++) {
      final element = flat[index].toBigInt();
      data.add(element);
      index++;
    }
    
    // Leer pending_word y pending_len
    final pendingWord = flat[index].toBigInt();
    index++;
    
    final pendingLen = BigInt.parse(flat[index].toString()).toInt();
    index++;
    
    
    return ByteArrayResult(
      data: data,
      pendingWord: pendingWord,
      pendingLen: pendingLen,
      nextIndex: index
    );
  } catch (e, stack) {
    print('❌ Error parseando ByteArray: $e');
    print('📚 Stack trace: $stack');
    return ByteArrayResult(
      data: [],
      pendingWord: BigInt.zero,
      pendingLen: 0,
      nextIndex: startIndex + 1
    );
  }
}

/// Convierte un ByteArray a string
String _byteArrayToString(ByteArrayResult byteArray) {
  try {
    
    // Convertir los elementos del array principal
    final dataStr = byteArray.data.map((felt) {
      final hex = felt.toRadixString(16).padLeft(64, '0');
      final bytes = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        final byte = int.parse(hex.substring(i, i + 2), radix: 16);
        if (byte != 0) bytes.add(byte);
      }
      final str = String.fromCharCodes(bytes);
      return str;
    }).join();
    
    // Convertir el pending_word
    final pendingHex = byteArray.pendingWord.toRadixString(16).padLeft(64, '0');
    
    final pendingBytes = <int>[];
    // Procesar desde el final del hex, tomando solo los bytes necesarios según pendingLen
    final startIndex = pendingHex.length - (byteArray.pendingLen * 2);
    
    for (var i = startIndex; i < pendingHex.length; i += 2) {
      if (i + 1 < pendingHex.length) {
        final byteHex = pendingHex.substring(i, i + 2);
        final byte = int.parse(byteHex, radix: 16);
        if (byte != 0) {
          pendingBytes.add(byte);
        }
      }
    }
    
      final pendingStr = String.fromCharCodes(pendingBytes);
    
    final result = dataStr + pendingStr;
    
    return result;
  } catch (e, stack) {
    print('❌ Error convirtiendo ByteArray a string: $e');
    print('📚 Stack trace: $stack');
    return '';
  }
}

/// Convierte un string a ByteArray de Cairo
List<String> _stringToByteArray(String input) {
  print('🔄 Convirtiendo string a ByteArray:');
  print('  - Input: $input');
  
  // Remover el prefijo '0x' si existe
  final cleanInput = input.startsWith('0x') ? input.substring(2) : input;
  print('  - Clean input: $cleanInput');
  
  // Convertir cada byte a su valor decimal
  final bytes = <int>[];
  for (int i = 0; i < cleanInput.length; i += 2) {
    final byte = int.parse(cleanInput.substring(i, i + 2), radix: 16);
    bytes.add(byte);
  }
  print('  - Bytes: $bytes');
  
  // Construir el ByteArray en el formato de Cairo
  final result = <String>[];
  
  // Agregar la longitud del array
  result.add(bytes.length.toString());
  print('  - Length: ${bytes.length}');
  
  // Agregar los bytes
  for (final byte in bytes) {
    result.add(byte.toString());
  }
  print('  - Bytes added: ${result.length - 1}');
  
  // Agregar el pending_word (0) y pending_len (0)
  result.add('0'); // pending_word
  result.add('0'); // pending_len
  print('  - Added pending_word and pending_len');
  
  print('✅ ByteArray result: $result');
  return result;
}

class ByteArrayResult {
  final List<BigInt> data;
  final BigInt pendingWord;
  final int pendingLen;
  final int nextIndex;

  ByteArrayResult({
    required this.data,
    required this.pendingWord,
    required this.pendingLen,
    required this.nextIndex,
  });
}

/// Parsea el resultado de reclaim
/// Estructura: (ByteArray, ByteArray, felt252, felt252, felt252, ByteArray)
/// Donde:
/// - ByteArray: cipher_secret
/// - ByteArray: cid
/// - felt252: hash_commit
/// - felt252: owner
/// - felt252: access_type
/// - ByteArray: name
class ReclaimResult {
  final String cipherSecret;
  final String cid;
  final String hashCommit;
  final String owner;
  final String accessType;
  final String name;

  ReclaimResult({
    required this.cipherSecret,
    required this.cid,
    required this.hashCommit,
    required this.owner,
    required this.accessType,
    required this.name,
  });
}

/// Parsea el resultado de reclaim
ReclaimResult parseReclaimResult(List<Felt> flat) {
  try {
    int index = 0;
    
    // 1. cipher_secret (ByteArray)
    final cipherSecretByteArray = _parseByteArray(flat, index);
    final cipherSecret = _byteArrayToString(cipherSecretByteArray);
    index = cipherSecretByteArray.nextIndex;
    
    // 2. cid (ByteArray)
    final cidByteArray = _parseByteArray(flat, index);
    final cid = _byteArrayToString(cidByteArray);
    index = cidByteArray.nextIndex;
    
    // 3. hash_commit (felt252)
    final hashCommitFelt = flat[index].toBigInt();
    final hashCommit = '0x${hashCommitFelt.toRadixString(16).padLeft(64, '0')}';
    index++;
    
    // 4. owner (felt252)
    final ownerFelt = flat[index].toBigInt();
    final owner = '0x${ownerFelt.toRadixString(16).padLeft(64, '0')}';
    index++;
    
    // 5. access_type (felt252)
    final accessTypeFelt = flat[index].toBigInt();
    String accessType;
    try {
      final accessTypeStr = _byteArrayToString(ByteArrayResult(
        data: [accessTypeFelt],
        pendingWord: BigInt.zero,
        pendingLen: 0,
        nextIndex: 0
      ));
      accessType = accessTypeStr == 'timestamp' || accessTypeStr == 'heirs' 
        ? accessTypeStr 
        : 'timestamp';
    } catch (e) {
      print('⚠️ Error decodificando access type: $e');
      accessType = 'timestamp';
    }
    index++;
    
    // 6. name (ByteArray)
    final nameByteArray = _parseByteArray(flat, index);
    final name = _byteArrayToString(nameByteArray);
    
    print('✅ Reclaim result parseado:');
    print('  - Cipher Secret: $cipherSecret');
    print('  - CID: $cid');
    print('  - Hash Commit: $hashCommit');
    print('  - Owner: $owner');
    print('  - Access Type: $accessType');
    print('  - Name: $name');
    
    return ReclaimResult(
      cipherSecret: cipherSecret,
      cid: cid,
      hashCommit: hashCommit,
      owner: owner,
      accessType: accessType,
      name: name,
    );
  } catch (e) {
    print('❌ Error parseando reclaim result: $e');
    rethrow;
  }
}

/// Descifra el cipher secret usando RSA
Future<String> decryptCipherSecret({
  required String cipherSecret,
  required String encryptedPrivateKey,
  required String hashSecret,
}) async {
  try {
    print('🔐 Iniciando descifrado del cipher secret...');
    print('🔑 Cipher secret recibido: $cipherSecret');
    
    // 1. Obtener la clave pública que se usó para cifrar
    final publicKey = '0x7ec0a80af0e3bbc453768e87732e7b26a6cbf02462d7ef4e38547dddb62a054';
    print('🔑 Clave pública: $publicKey');
    
    // 2. Limpiar el prefijo 0x de la clave pública
    final cleanPublicKey = publicKey.startsWith('0x') ? publicKey.substring(2) : publicKey;
    print('🔑 Clave pública limpia: $cleanPublicKey');
    
    // 3. Descifrar el cipher secret usando RSA con la clave pública
    final decrypted = functions.decryptWithRSA(cipherSecret, cleanPublicKey);
    print('✅ Cipher secret descifrado exitosamente');
    print('🔑 Texto descifrado: $decrypted');
    
    return decrypted;
  } catch (e) {
    print('❌ Error descifrando cipher secret: $e');
    rethrow;
  }
}

/// Obtiene el contenido de IPFS usando el CID
Future<Uint8List> getIpfsContent(String cid) async {
  try {
    print('🌐 Obteniendo contenido de IPFS...');
    print('  - CID: $cid');
    
    final url = 'https://ipfs.io/ipfs/$cid';
    print('  - URL: $url');
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Error obteniendo contenido de IPFS: ${response.statusCode}');
    }
    
    print('✅ Contenido de IPFS obtenido exitosamente');
    return response.bodyBytes;
  } catch (e) {
    print('❌ Error obteniendo contenido de IPFS: $e');
    rethrow;
  }
}

/// Descifra el contenido de IPFS usando la clave AES
String decryptIpfsContent(Uint8List encryptedContent, String aesKey) {
  try {
    print('🔐 Descifrando contenido de IPFS...');
    
    // 1. Crear el objeto AES
    final key = base64Decode(aesKey);
    final iv = Uint8List(16); // IV de 16 bytes (ceros)
    
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.cbc));
    final encrypted = Encrypted(encryptedContent);
    
    // 2. Descifrar
    final decrypted = encrypter.decrypt(encrypted, iv: IV(iv));
    print('✅ Contenido de IPFS descifrado exitosamente');
    
    return decrypted;
  } catch (e) {
    print('❌ Error descifrando contenido de IPFS: $e');
    rethrow;
  }
} 