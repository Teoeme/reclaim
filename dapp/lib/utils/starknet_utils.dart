import 'package:starknet_provider/starknet_provider.dart';
import 'package:starknet/starknet.dart' show Felt;
import 'dart:convert';

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
      print('🔍 Contract Data: $contractData');
      
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
              final selector = Felt.fromHexString(entrypoint['selector']);
              print('🔍 Selector encontrado para $functionName: 0x${selector.toHexString()}');
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
} 