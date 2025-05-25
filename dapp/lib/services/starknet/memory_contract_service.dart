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
      final selector = await StarknetUtils.getFunctionSelector(
        provider,
        StarknetConfig.contractAddress,
        'get_records_by_owner',
      );
      print('🔍 Selector obtenido: 0x${selector.toHexString()}');

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
          final records = data as List;
          print('📦 Número de registros encontrados: ${records.length}');
          
          if (records.isNotEmpty) {
            print('📦 Primer registro:');
            print(records.first);
          }

          return records.map((record) {
            print('🔄 Procesando registro:');
            print(record);
            
            final hashCommit = record[0].toString();
            final unlockTimestamp = int.parse(record[1].toString());
            final accessType = int.parse(record[2].toString());
            final cid = record[3].toString();
            final name = record[4].toString();

            print('✅ Registro procesado:');
            print('  - Hash: $hashCommit');
            print('  - Timestamp: $unlockTimestamp');
            print('  - Access Type: $accessType');
            print('  - CID: $cid');
            print('  - Name: $name');

            return Memory(
              id: hashCommit,
              title: name,
              content: 'CID: $cid',
              imageUrl: '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(unlockTimestamp * 1000),
              accessType: accessType,
            );
          }).toList();
        },
        error: (error) {
          print('❌ Error en la llamada al contrato: $error');
          return [];
        },
      );
    } catch (e, stackTrace) {
      print('❌ Error al obtener memorias:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return [];
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