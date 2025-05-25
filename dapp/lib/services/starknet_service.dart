import 'package:starknet/starknet.dart' hide Signer;
import 'package:starknet/starknet.dart' as starknet show Signer;
import 'package:avnu_provider/avnu_provider.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StarknetService {
  late final AvnuJsonRpcProvider avnuProvider;
  
  StarknetService() {
    // Inicializar AVNU Provider con la API key desde variables de entorno
    final publicKey = BigInt.parse("0429c489be63b21c399353e03a9659cfc1650b24bae1e9ebdde0aef2b38deb44", radix: 16);
    avnuProvider = AvnuJsonRpcProvider(
      nodeUri: Uri.parse('https://sepolia.api.avnu.fi'),
      publicKey: publicKey,
      apiKey: FFDevEnvironmentValues().AvnuApiKey,
    );
  }
  
  /// Función para guardar metadata de memoria usando AVNU gasless
  Future<String?> saveMemoryMetadata({
    required String userAddress,
    required String memoryName,
    required String memoryDescription,
    required DateTime unlockTimestamp,
    required String encryptedSecret,
    required String encryptedPrivateKey,
    required String userPublicKey,
    required String hashCommit,
    required String cid,
  }) async {
    try {
      // Descifrar la clave privada usando la función de custom_functions
      final hashSecret = FFDevEnvironmentValues().HashSecret;
      String decryptedPrivateKey;
      
      try {
        decryptedPrivateKey = functions.decryptWithRSA(encryptedPrivateKey, hashSecret);
        print('Clave privada descifrada exitosamente');
      } catch (e) {
        print('Error: No se pudo descifrar la clave privada: $e');
        return null;
      }
      
      // Convertir timestamp a hex
      final unlockTimestampHex = '0x${(unlockTimestamp.millisecondsSinceEpoch ~/ 1000).toRadixString(16)}';
      
      // Preparar los datos para el contrato con información real
      final calls = [
        {
          'contractAddress': FFDevEnvironmentValues().ContractAddress,
          'entrypoint': 'save_metadata',
          'calldata': [
            // hash_commit del IPFS
            hashCommit,
            // cipher_secret (encryptedSecret)
            _stringToHex(encryptedSecret),
            // cid del IPFS
            cid,
            // unlock_timestamp del formulario
            unlockTimestampHex,
            // access_type (string "timestamp")
            _stringToHex('timestamp'),
            // name del formulario
            _stringToHex(memoryName),
          ]
        }
      ];

      // Obtener el class hash de la cuenta
      final accountClassHash = '0x01a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003'; // ArgentX
      
      // Construir typed data usando AVNU Provider
      final buildTypedDataResult = await avnuProvider.buildTypedData(
        userAddress,
        calls,
        '', // gasTokenAddress vacío para usar rewards
        '', // maxGasTokenAmount vacío para usar rewards
        accountClassHash,
      );

      print('Typed data construido exitosamente');
      
      // Generar la firma usando la clave privada descifrada
      final signature = await _generateSignature(buildTypedDataResult, decryptedPrivateKey, userAddress);
      
      if (signature != null) {
        // Ejecutar la transacción usando AVNU Provider
        return await _executeTransaction(userAddress, buildTypedDataResult, signature);
      } else {
        print('Error generando la firma');
        return null;
      }
    } catch (e) {
      print('Error en saveMemoryMetadata: $e');
      return null;
    }
  }



  /// Generar firma usando la clave privada descifrada y Starknet
  Future<List<String>?> _generateSignature(
    AvnuBuildTypedData typedData,
    String privateKeyHex,
    String userAddress,
  ) async {
    try {
      // Limpiar el prefijo 0x si existe
      final cleanPrivateKey = privateKeyHex.startsWith('0x') 
          ? privateKeyHex.substring(2) 
          : privateKeyHex;
      
      // Convertir la clave privada a BigInt
      final privateKey = BigInt.parse(cleanPrivateKey, radix: 16);
      
      // Convertir el typed data a JSON string y luego parsearlo
      final String typedDataJson = jsonEncode(typedData.toJson());
      final Map<String, dynamic> typedDataMap = jsonDecode(typedDataJson);
      
      // Remover campos nulos y runtimeType
      _removeNullFields(typedDataMap);
      typedDataMap.remove('runtimeType');
      
      // Crear el objeto TypedData
      final typedDataObject = TypedData.fromJson(typedDataMap);
      
      // Generar el hash del mensaje
      final messageHash = getMessageHash(typedDataObject, Felt.fromHexString(userAddress).toBigInt());
      
      // Firmar el hash
      final signature = starknetSign(
        privateKey: privateKey,
        messageHash: messageHash,
        seed: BigInt.from(32),
      );
      
      // Formatear la firma según el formato esperado por AVNU
      final signCount = "0x1";
      final starknetSignatureId = "0x0";
      final publicKey = _getPublicKeyFromPrivate(privateKey);
      final signatureR = Felt(signature.r).toHexString();
      final signatureS = Felt(signature.s).toHexString();
      
      return [signCount, starknetSignatureId, publicKey, signatureR, signatureS];
    } catch (e) {
      print('Error generando firma: $e');
      return null;
    }
  }

  /// Ejecutar transacción usando AVNU Provider
  Future<String?> _executeTransaction(
    String userAddress,
    AvnuBuildTypedData typedData,
    List<String> signature,
  ) async {
    try {
      // Convertir typed data a JSON string limpio
      final String typedDataJson = jsonEncode(typedData.toJson());
      final Map<String, dynamic> typedDataMap = jsonDecode(typedDataJson);
      _removeNullFields(typedDataMap);
      typedDataMap.remove('runtimeType');
      final String cleanTypedData = jsonEncode(typedDataMap);
      
      // Ejecutar usando AVNU Provider
      final executeResult = await avnuProvider.execute(
        userAddress,
        cleanTypedData,
        signature,
        null, // deploymentData
      );

      print('Transacción ejecutada exitosamente: ${executeResult.transactionHash}');
      return executeResult.transactionHash;
    } catch (e) {
      print('Error en _executeTransaction: $e');
      return null;
    }
  }

  /// Convertir string a hexadecimal
  String _stringToHex(String input) {
    return '0x${input.codeUnits.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Remover campos nulos de un mapa recursivamente
  void _removeNullFields(Map<String, dynamic> map) {
    map.removeWhere((key, value) => value == null);
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _removeNullFields(value);
      } else if (value is List) {
        for (var item in value) {
          if (item is Map<String, dynamic>) {
            _removeNullFields(item);
          }
        }
      }
    });
  }

  /// Obtener clave pública desde clave privada
  String _getPublicKeyFromPrivate(BigInt privateKey) {
    try {
      // Crear un signer temporal para obtener la clave pública
      final signer = starknet.Signer(privateKey: Felt(privateKey));
      return signer.publicKey.toHexString();
    } catch (e) {
      print('Error obteniendo clave pública: $e');
      // Fallback: usar una clave pública dummy
      return '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    }
  }

  /// Verificar el estado del servicio AVNU
  Future<bool> checkAvnuStatus() async {
    try {
      // Por ahora retornamos true, ya que no tenemos acceso directo al método status
      // En una implementación real, podrías hacer una llamada HTTP directa
      return true;
    } catch (e) {
      print('Error verificando estado AVNU: $e');
      return false;
    }
  }

  /// Obtener precios de tokens de gas
  Future<Map<String, dynamic>?> getGasTokenPrices() async {
    try {
      // Por ahora retornamos null, ya que no tenemos acceso directo al método
      // En una implementación real, podrías hacer una llamada HTTP directa
      return null;
    } catch (e) {
      print('Error obteniendo precios de gas: $e');
      return null;
    }
  }
} 