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
      print('🔍 Llamando al contrato con dirección: $ownerAddress');
      print('📝 Detalles de la llamada:');
      print('  - Contrato: ${StarknetConfig.contractAddress}');
      print('  - Owner Address: $ownerAddress');
      
      // Obtener el selector usando el nombre de la función
      Felt selector;
      try {
        selector = await StarknetUtils.getFunctionSelector(
          provider,
          StarknetConfig.contractAddress,
          'get_records_by_owner',
        );
        print('🔍 Selector obtenido del ABI: 0x${selector.toHexString()}');
      } catch (e) {
        print('⚠️ Error obteniendo selector del ABI: $e');
        print('🔄 Usando selector conocido directamente');
        // Usar el selector conocido directamente
        selector = Felt.fromHexString('0x1a8cfea6d1a66dfceba35b10f5a3cfebbfe033702a6713ff0af802f86667b3e');
        print('🔍 Selector directo: 0x${selector.toHexString()}');
      }

      // Usar el selector obtenido para la llamada
      final result = await provider.call(
        request: FunctionCall(
          contractAddress: Felt.fromHexString(StarknetConfig.contractAddress),
          entryPointSelector: selector,
          calldata: [Felt.fromHexString(ownerAddress)],
        ),
        blockId: BlockId.latest,
      );

      print('📦 Respuesta completa del contrato:');
      print(result);
      print('📦 Tipo de resultado: ${result.runtimeType}');
      
      // Manejar la respuesta usando when
      return result.when(
        result: (data) {
          print('📦 Datos recibidos del contrato: $data');
          print('📦 Tipo de datos: ${data.runtimeType}');
          
          if (data == null) {
            print('⚠️ Los datos recibidos son null');
            return <Memory>[];
          }
          
          if (data is! List) {
            print('⚠️ Los datos no son una lista: ${data.runtimeType}');
            return <Memory>[];
          }
          
          final outerList = data as List;
          print('📦 Número de elementos en la lista externa: ${outerList.length}');
          
          if (outerList.isEmpty) {
            print('📦 Lista externa vacía');
            return <Memory>[];
          }
          
          // La estructura real es: [[record_data]]
          final firstElement = outerList[0];
          print('📦 Primer elemento: $firstElement (${firstElement.runtimeType})');
          
          if (firstElement is! List) {
            print('⚠️ El primer elemento no es una lista: ${firstElement.runtimeType}');
            return <Memory>[];
          }
          
          final recordList = firstElement as List;
          print('📦 Número de elementos en el registro: ${recordList.length}');
          
          // Debug: mostrar todos los elementos del registro
          print('🔍 Elementos del registro:');
          for (int i = 0; i < recordList.length; i++) {
            final element = recordList[i];
            print('  [$i]: $element (${element.runtimeType})');
            
            // Si es un Map, mostrar su contenido
            if (element is Map) {
              print('    Contenido del Map:');
              element.forEach((key, value) {
                print('      $key: $value (${value.runtimeType})');
              });
            }
          }
          
          // Según la estructura que proporcionaste:
          // [0]: Map con data (CID), pending_word, pending_word_len
          // [1]: hash_commit (Felt)
          // [2]: unlock_timestamp (Felt) 
          // [3]: access_type (Felt)
          // [4]: Map con data (name), pending_word, pending_word_len
          
          if (recordList.length < 5) {
            print('⚠️ Registro incompleto. Elementos: ${recordList.length}');
            return <Memory>[];
          }

          final memories = <Memory>[];
          
          try {
                         // Extraer CID del primer Map
             final cidMap = recordList[0];
             String cid = '';
             if (cidMap is Map && cidMap.containsKey('data')) {
               cid = _extractStringFromDataMap(Map<String, dynamic>.from(cidMap));
             }
            
            // Extraer hash commit
            final hashCommit = _convertFeltToHex(recordList[1]);
            
            // Extraer timestamp
            final unlockTimestamp = _convertFeltToInt(recordList[2]);
            
            // Extraer access type
            final accessType = _convertFeltToInt(recordList[3]);
            
                         // Extraer name del último Map
             final nameMap = recordList[4];
             String name = '';
             if (nameMap is Map && nameMap.containsKey('data')) {
               name = _extractStringFromDataMap(Map<String, dynamic>.from(nameMap));
             }

            print('✅ Registro procesado:');
            print('  - Hash: $hashCommit');
            print('  - Timestamp: $unlockTimestamp');
            print('  - Access Type: $accessType');
            print('  - CID: $cid');
            print('  - Name: $name');

            memories.add(Memory(
              id: hashCommit,
              title: name.isNotEmpty ? name : 'Memoria sin título',
              content: cid.isNotEmpty ? 'CID: $cid' : 'Sin contenido',
              imageUrl: '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(unlockTimestamp * 1000),
              accessType: accessType,
            ));
          } catch (e) {
            print('❌ Error procesando registro: $e');
          }
          
          print('✅ Total de memorias procesadas: ${memories.length}');
          return memories;
        },
        error: (error) {
          print('❌ Error en la llamada al contrato: $error');
          return <Memory>[];
        },
      );
    } catch (e, stackTrace) {
      print('❌ Error al obtener memorias:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Convierte un valor a hexadecimal
  String _convertFeltToHex(dynamic value) {
    if (value is Felt) {
      return '0x${value.toHexString()}';
    }
    return value.toString();
  }
  
  /// Convierte un valor a entero
  int _convertFeltToInt(dynamic value) {
    if (value is Felt) {
      return value.toBigInt().toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
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