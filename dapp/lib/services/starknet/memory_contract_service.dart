import 'package:starknet_provider/starknet_provider.dart';
import 'package:starknet/starknet.dart' show Felt;
import '../../config/starknet_config.dart';
import '../../utils/starknet_utils.dart';

class MemoryContractService {
  final JsonRpcProvider provider;

  MemoryContractService({
    required this.provider,
  });

Future<List<Memory>> getMemoriesByOwner(String ownerAddress) async {
  try {
    Felt selector;
    try {
      selector = await StarknetUtils.getFunctionSelector(
        provider,
        StarknetConfig.contractAddress,
        'get_records_by_owner',
      );
    } catch (e) {
      selector = Felt.fromHexString('0x1a8cfea6d1a66dfceba35b10f5a3cfebbfe033702a6713ff0af802f86667b3e');
    }

    final result = await provider.call(
      request: FunctionCall(
        contractAddress: Felt.fromHexString(StarknetConfig.contractAddress),
        entryPointSelector: selector,
        calldata: [Felt.fromHexString(ownerAddress)],
      ),
      blockId: BlockId.latest,
    );

    return result.when(
      result: (data) {
        if (data == null || data is! List || data.length < 2) return <Memory>[];

        final flat = data.cast<Felt>();
        final cantidad = BigInt.parse(flat[0].toString()).toInt();
        
        print('🔎 Se reportan $cantidad memorias');
        print('📦 Datos totales recibidos: ${flat.length}');
        print('📋 Datos completos: ${flat.map((f) => f.toString()).toList()}');

        final memories = <Memory>[];
        
        // Usar una función dinámica para parsear cada memoria
        final memoriesParsed = _parseMemoriesFromFlatArray(flat, cantidad);
        memories.addAll(memoriesParsed);

        print('✅ Memorias cargadas: ${memories.length}');
        return memories;
      },
      error: (error) {
        print('❌ Error al llamar el contrato: $error');
        return <Memory>[];
      },
    );
  } catch (e, stack) {
    print('❌ Error general: $e');
    print(stack);
    return [];
  }
}

/// Parsea las memorias desde el array plano de manera dinámica
List<Memory> _parseMemoriesFromFlatArray(List<Felt> flat, int expectedCount) {
  final memories = <Memory>[];
  
  try {
    int index = 2; // Empezamos después de [cantidad, version]
    
    for (int i = 0; i < expectedCount; i++) {
      print('\n🔄 Procesando memoria #${i + 1}');
      print('📍 Índice actual: $index');
      
      try {
        // Detectar automáticamente la estructura de cada memoria
        final memoryData = _extractMemoryFromIndex(flat, index);
        
        if (memoryData != null) {
          memories.add(memoryData.memory);
          index = memoryData.nextIndex;
          
          print('✅ Memoria #${i + 1} procesada exitosamente');
          print('📄 Título: ${memoryData.memory.title}');
          print('🔗 Content: ${memoryData.memory.content}');
        } else {
          print('❌ No se pudo procesar la memoria #${i + 1}');
          break;
        }
      } catch (e) {
        print('❌ Error procesando memoria #${i + 1}: $e');
        break;
      }
    }
  } catch (e) {
    print('❌ Error general en parsing: $e');
  }
  
  return memories;
}

/// Extrae una memoria desde un índice específico del array
MemoryParsingResult? _extractMemoryFromIndex(List<Felt> flat, int startIndex) {
  int index = startIndex;
  
  try {
    print('🔍 Elementos disponibles desde índice $startIndex: ${flat.length - startIndex}');
    
    // Verificar que tengamos suficientes elementos
    if (index + 8 >= flat.length) {
      print('❌ No hay suficientes elementos desde el índice $startIndex');
      return null;
    }
    
    // Detectar automáticamente cuántos elementos tiene cada sección
    final cidData = _extractCIDFromIndex(flat, index);
    index = cidData.nextIndex;
    
    print('📍 Después del CID, índice: $index');
    
    // Verificar que aún tengamos elementos suficientes
    if (index + 4 >= flat.length) {
      print('❌ No hay suficientes elementos para el resto de la memoria');
      return null;
    }
    
    // Hash commit (1 elemento)
    final hashCommit = _convertFeltToHex(flat[index]);
    print('🔑 Hash commit: $hashCommit');
    index++;
    
    // Timestamp (1 elemento) - con validación
    final timestampRaw = _convertFeltToInt(flat[index]);
    print('⏰ Timestamp raw: $timestampRaw');
    
    // Validar timestamp - debe ser un valor razonable
    DateTime createdAt;
    if (timestampRaw < 0 || timestampRaw > 4102444800) { // Año 2100
      print('⚠️  Timestamp inválido, usando fecha actual');
      createdAt = DateTime.now();
    } else {
      try {
        createdAt = DateTime.fromMillisecondsSinceEpoch(timestampRaw * 1000);
        print('📅 Fecha creada: $createdAt');
      } catch (e) {
        print('⚠️  Error creando fecha: $e, usando fecha actual');
        createdAt = DateTime.now();
      }
    }
    index++;
    
    // ID (1 elemento)
    final id = flat[index];
    print('🆔 ID: $id');
    index++;
    
    // Access type (1 elemento)
    final accessType = _convertFeltToInt(flat[index]);
    print('🔒 Access type: $accessType');
    index++;
    
    // Name - puede tener estructura variable
    final nameData = _extractNameFromIndex(flat, index);
    index = nameData.nextIndex;
    
    final memory = Memory(
      id: hashCommit,
      title: nameData.name.isNotEmpty ? nameData.name : 'Memoria sin título',
      content: 'https://ipfs.io/ipfs/${cidData.cid}',
      imageUrl: '',
      createdAt: createdAt,
      accessType: accessType,
    );
    
    return MemoryParsingResult(memory: memory, nextIndex: index);
    
  } catch (e, stackTrace) {
    print('❌ Error extrayendo memoria desde índice $startIndex: $e');
    print('📚 Stack trace: $stackTrace');
    return null;
  }
}

/// Extrae el CID de manera dinámica
CIDExtractionResult _extractCIDFromIndex(List<Felt> flat, int startIndex) {
  int index = startIndex;
  
  try {
    // Detectar si tiene estructura ByteArray o simple
    // Si los siguientes elementos parecen ser partes de CID
    
    final part1 = BigInt.parse(flat[index++].toString());
    final part2 = BigInt.parse(flat[index++].toString());
    final pendingWord = BigInt.parse(flat[index++].toString());
    final pendingLen = int.parse(flat[index++].toString());
    
    final cid = _combineFeltParts([part1, part2], pendingWord, pendingLen);
    
    print('🔗 CID extraído: $cid');
    
    return CIDExtractionResult(cid: cid, nextIndex: index);
  } catch (e) {
    print('❌ Error extrayendo CID: $e');
    // Fallback: intentar extraer como texto simple
    final cidFallback = _decodeFeltToText(BigInt.parse(flat[startIndex].toString()));
    return CIDExtractionResult(cid: cidFallback, nextIndex: startIndex + 1);
  }
}

/// Extrae el nombre de manera dinámica
NameExtractionResult _extractNameFromIndex(List<Felt> flat, int startIndex) {
  int index = startIndex;
  
  try {
    // Verificar que tengamos al menos 2 elementos
    if (index + 1 >= flat.length) {
      print('❌ No hay suficientes elementos para extraer el nombre');
      return NameExtractionResult(name: 'Sin nombre', nextIndex: index);
    }
    
    // Patrón: nameWord + nameLen
    final nameWord = BigInt.parse(flat[index].toString());
    print('📝 Name word raw: $nameWord');
    index++;
    
    final nameLenRaw = flat[index].toString();
    print('📏 Name length raw: $nameLenRaw');
    
    // Manejar nameLen que puede ser muy grande (como 2.3655539966064812e+28)
    int nameLen;
    try {
      // Si es notación científica, convertir primero
      if (nameLenRaw.contains('e') || nameLenRaw.contains('E')) {
        final bigIntLen = BigInt.parse(nameLenRaw.split('.')[0]);
        nameLen = bigIntLen.toInt();
      } else {
        nameLen = BigInt.parse(nameLenRaw).toInt();
      }
    } catch (e) {
      print('⚠️  Error parseando longitud del nombre: $e');
      nameLen = 0;
    }
    
    // Validar nameLen - debe ser razonable
    if (nameLen < 0 || nameLen > 1000) {
      print('⚠️  Longitud de nombre inválida ($nameLen), usando 0');
      nameLen = 0;
    }
    
    index++;
    
    String name = '';
    if (nameLen > 0) {
      try {
        final decodedName = _decodeFeltToText(nameWord);
        name = decodedName.substring(0, nameLen.clamp(0, decodedName.length));
      } catch (e) {
        print('⚠️  Error decodificando nombre: $e');
        name = 'Memoria';
      }
    }
    
    // Si el nombre está vacío, usar un nombre por defecto
    if (name.isEmpty) {
      name = 'Memoria';
    }
    
    print('📝 Nombre extraído: "$name" (longitud: $nameLen)');
    
    return NameExtractionResult(name: name, nextIndex: index);
  } catch (e) {
    print('❌ Error extrayendo nombre: $e');
    // Fallback: intentar como texto simple
    try {
      final nameFallback = _decodeFeltToText(BigInt.parse(flat[startIndex].toString()));
      return NameExtractionResult(name: nameFallback.isNotEmpty ? nameFallback : 'Memoria', nextIndex: startIndex + 1);
    } catch (e2) {
      return NameExtractionResult(name: 'Memoria', nextIndex: startIndex + 1);
    }
  }
}

String _decodeFeltToText(BigInt felt) {
  final hex = felt.toRadixString(16).padLeft(64, '0');
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final byte = int.parse(hex.substring(i, i + 2), radix: 16);
    if (byte != 0) bytes.add(byte);
  }
  return String.fromCharCodes(bytes);
}

String _combineFeltParts(List<BigInt> dataParts, BigInt pendingWord, int pendingLen) {
  final decoded = dataParts.map(_decodeFeltToText).join();
  final pendingDecoded = _decodeFeltToText(pendingWord);
  final pending = pendingDecoded.substring(0, pendingLen.clamp(0, pendingDecoded.length));
  return decoded + pending;
}

String _convertFeltToHex(dynamic value) {
  final felt = BigInt.parse(value.toString());
  return '0x${felt.toRadixString(16)}';
}

int _convertFeltToInt(dynamic value) {
  return BigInt.parse(value.toString()).toInt();
}

/// Convierte un valor a string, manejando la codificación de texto
String _convertFeltToString(dynamic value) {
  if (value is! Felt) {
    return value.toString();
  }
  
  final felt = value as Felt;
  try {
    final bigInt = felt.toBigInt();
    
    // Si es un número pequeño, probablemente es un ID o número
    if (bigInt < BigInt.from(256)) {
      return bigInt.toString();
    }
    
    // Intentar convertir a string (asumiendo codificación ASCII/UTF-8)
    final bytes = <int>[];
    var temp = bigInt;
    
    while (temp > BigInt.zero) {
      final byte = (temp & BigInt.from(0xFF)).toInt();
      if (byte == 0) break; // Terminar en null byte
      bytes.insert(0, byte);
      temp = temp >> 8;
    }
    
    if (bytes.isEmpty) {
      return bigInt.toString();
    }
    
    try {
      final string = String.fromCharCodes(bytes);
      // Verificar si es un string válido (solo caracteres imprimibles)
      if (string.runes.every((rune) => rune >= 32 && rune <= 126)) {
        return string;
      }
    } catch (e) {
      // Si falla la conversión a string, devolver como número
    }
    
    return bigInt.toString();
  } catch (e) {
    return felt.toString();
  }
}

/// Extrae un string de un Map con estructura {data: [...], pending_word: "...", pending_word_len: "..."}
String _extractStringFromDataMap(Map<String, dynamic> dataMap) {
  try {
    print('🔍 Extrayendo string de Map: $dataMap');
    
    final dataList = dataMap['data'] as List?;
    final pendingWord = dataMap['pending_word'] as String?;
    final pendingWordLen = dataMap['pending_word_len'] as String?;
    
    print('  - data: $dataList');
    print('  - pending_word: $pendingWord');
    print('  - pending_word_len: $pendingWordLen');
    
    final allBytes = <int>[];
    
    // Procesar elementos de data
    if (dataList != null) {
      for (final item in dataList) {
        final hexString = item.toString();
        if (hexString.startsWith('0x')) {
          final hex = hexString.substring(2);
          // Convertir hex a bytes
          for (int i = 0; i < hex.length; i += 2) {
            if (i + 1 < hex.length) {
              final byteHex = hex.substring(i, i + 2);
              final byte = int.tryParse(byteHex, radix: 16);
              if (byte != null && byte != 0) {
                allBytes.add(byte);
              }
            }
          }
        }
      }
    }
    
    // Procesar pending_word si existe
    if (pendingWord != null && pendingWord.startsWith('0x')) {
      final hex = pendingWord.substring(2);
      final pendingLen = int.tryParse(pendingWordLen?.substring(2) ?? '0', radix: 16) ?? 0;
      
      // Solo tomar los bytes especificados por pending_word_len
      for (int i = 0; i < hex.length && i < pendingLen * 2; i += 2) {
        if (i + 1 < hex.length) {
          final byteHex = hex.substring(i, i + 2);
          final byte = int.tryParse(byteHex, radix: 16);
          if (byte != null && byte != 0) {
            allBytes.add(byte);
          }
        }
      }
    }
    
    if (allBytes.isEmpty) {
      return '';
    }
    
    final result = String.fromCharCodes(allBytes);
    print('  ✅ String extraído: "$result"');
    return result;
  } catch (e) {
    print('  ❌ Error extrayendo string: $e');
    return '';
  }
}
}

// Clases auxiliares para el parsing dinámico
class MemoryParsingResult {
  final Memory memory;
  final int nextIndex;

  MemoryParsingResult({
    required this.memory,
    required this.nextIndex,
  });
}

class CIDExtractionResult {
  final String cid;
  final int nextIndex;

  CIDExtractionResult({
    required this.cid,
    required this.nextIndex,
  });
}

class NameExtractionResult {
  final String name;
  final int nextIndex;

  NameExtractionResult({
    required this.name,
    required this.nextIndex,
  });
}

// Modelo para representar una memoria
class Memory {
  final String id;
  final String title;
  final String content;
  final String imageUrl;
  final DateTime createdAt;
  final int accessType;

  Memory({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.createdAt,
    required this.accessType,
  });
} 