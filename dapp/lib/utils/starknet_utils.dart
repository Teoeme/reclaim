import 'package:starknet_provider/starknet_provider.dart';
import 'package:starknet/starknet.dart' show Felt;
import 'dart:convert';
import 'package:crypto/crypto.dart';

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
      final hashCommit = '0x${flat[index].toBigInt().toRadixString(16)}';
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