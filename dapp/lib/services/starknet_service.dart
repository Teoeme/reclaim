import 'package:starknet/starknet.dart' hide Signer;
import 'package:starknet/starknet.dart' as starknet show Signer;
import 'package:avnu_provider/avnu_provider.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
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
      // Validar que todos los parámetros requeridos estén presentes
      if (userAddress.isEmpty || 
          memoryName.isEmpty || 
          hashCommit.isEmpty || 
          cid.isEmpty || 
          encryptedSecret.isEmpty ||
          encryptedPrivateKey.isEmpty) {
        print('Error: Parámetros requeridos faltantes');
        return null;
      }
      
      // Descifrar la clave privada usando la función de custom_functions
      final hashSecret = FFDevEnvironmentValues().HashSecret;
      String decryptedPrivateKey;
      
      try {
        print('🔐 Hash secret: $hashSecret');
        decryptedPrivateKey = functions.decryptWithAES(encryptedPrivateKey, hashSecret);
        print('🔐 Private key desencriptada exitosamente: $decryptedPrivateKey');
      } catch (e) {
        print('Error: No se pudo descifrar la clave privada: $e');
        return null;
      }
      
      // Convertir timestamp a hex
      final unlockTimestampHex = '0x${(unlockTimestamp.millisecondsSinceEpoch ~/ 1000).toRadixString(16)}';
      
      // Preparar los datos para el contrato usando el formato ByteArray correcto
      print('Preparando calldata con:');
      print('- hashCommit: $hashCommit');
      print('- encryptedSecret: $encryptedSecret');
      print('- cid: $cid');
      print('- unlockTimestampHex: $unlockTimestampHex');
      print('- memoryName: $memoryName');
      
      // hash_commit del IPFS (ByteArray)
      final hashCommitByteArray = _stringToByteArray(hashCommit);
      print('hashCommitByteArray: $hashCommitByteArray');
      
      // cipher_secret (encryptedSecret) (ByteArray)
      final encryptedSecretByteArray = _stringToByteArray(encryptedSecret);
      print('encryptedSecretByteArray: $encryptedSecretByteArray');
      
      // cid del IPFS (ByteArray)
      final cidByteArray = _stringToByteArray(cid);
      print('cidByteArray: $cidByteArray');
      
      // access_type (felt252) - convertir "timestamp" a felt252
      final accessTypeFelt = _stringToFelt252('timestamp');
      print('accessTypeFelt: $accessTypeFelt');
      
      // name del formulario (ByteArray)
      final nameByteArray = _stringToByteArray(memoryName);
      print('nameByteArray: $nameByteArray');
      
      // Construir calldata completo en el orden correcto
      final calldata = <String>[];
      calldata.addAll(hashCommitByteArray);
      calldata.addAll(encryptedSecretByteArray);
      calldata.addAll(cidByteArray);
      calldata.add(unlockTimestampHex);
      calldata.add(accessTypeFelt);
      calldata.addAll(nameByteArray);
      
      print('calldata final: $calldata');
      
      final calls = [
        {
          'contractAddress': FFDevEnvironmentValues().ContractAddress,
          'entrypoint': 'save_metadata',
          'calldata': calldata,
        }
      ];

      // Usar class hash conocido de Argent (el método getClassHashAt no está disponible en AVNU provider)
      final accountClassHash = '0x01a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003';
      print('Usando class hash de Argent: $accountClassHash');
      
      // Construir typed data usando AVNU Provider
      print('Construyendo typed data con:');
      print('- userAddress: $userAddress');
      print('- calls: ${jsonEncode(calls)}');
      print('- accountClassHash: $accountClassHash');
      
      final buildTypedDataResult = await avnuProvider.buildTypedData(
        userAddress,
        calls,
        '', // gasTokenAddress vacío para usar rewards
        '', // maxGasTokenAmount vacío para usar rewards
        accountClassHash,
      );

      print('Typed data construido exitosamente');
      print('- Domain: ${jsonEncode(buildTypedDataResult.domain.toJson())}');
      print('- Types: ${jsonEncode(buildTypedDataResult.types)}');
      print('- PrimaryType: ${buildTypedDataResult.primaryType}');
      print('- Message: ${jsonEncode(buildTypedDataResult.message.toJson())}');
      
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
      print('Iniciando generación de firma...');
      
      // Limpiar el prefijo 0x si existe
      final cleanPrivateKey = privateKeyHex.startsWith('0x') 
          ? privateKeyHex.substring(2) 
          : privateKeyHex;
      
      print('Clave privada limpia: ${cleanPrivateKey.substring(0, 8)}...');
      
      // Convertir la clave privada a BigInt
      BigInt privateKey;
      try {
        privateKey = BigInt.parse(cleanPrivateKey, radix: 16);
        print('Clave privada convertida a BigInt exitosamente');
      } catch (e) {
        print('Error parseando clave privada: $e');
        return null;
      }
      
      // Convertir el typed data a JSON string y luego parsearlo
      final String typedDataJson = jsonEncode(typedData.toJson());
      print('Typed data JSON generado');
      
      final Map<String, dynamic> typedDataMap = jsonDecode(typedDataJson);
      
      // Remover campos nulos y runtimeType
      _removeNullFields(typedDataMap);
      typedDataMap.remove('runtimeType');
      
      print('Campos nulos removidos del typed data');
      
      // Crear el objeto TypedData
      TypedData typedDataObject;
      try {
        typedDataObject = TypedData.fromJson(typedDataMap);
        print('TypedData object creado exitosamente');
      } catch (e) {
        print('Error creando TypedData object: $e');
        print('TypedData map: ${jsonEncode(typedDataMap)}');
        return null;
      }
      
      // Generar el hash del mensaje
      BigInt messageHash;
      try {
        messageHash = getMessageHash(typedDataObject, Felt.fromHexString(userAddress).toBigInt());
        print('Message hash generado exitosamente: 0x${messageHash.toRadixString(16)}');
      } catch (e) {
        print('Error generando message hash: $e');
        return null;
      }
      
      // Firmar el hash
      dynamic signature;
      try {
        signature = starknetSign(
          privateKey: privateKey,
          messageHash: messageHash,
          seed: BigInt.from(32),
        );
        print('Firma generada exitosamente - r: 0x${signature.r.toRadixString(16)}, s: 0x${signature.s.toRadixString(16)}');
      } catch (e) {
        print('Error firmando: $e');
        return null;
      }
      
      // Formatear la firma según el formato esperado por AVNU
      // Según la documentación de AVNU: [signCount, starknetSignatureId, publicKey, signatureR, signatureS]
      final signatureR = Felt(signature.r).toHexString();
      final signatureS = Felt(signature.s).toHexString();
      
      // Obtener la clave pública del usuario
      final userPublicKey = _getPublicKeyFromPrivate(privateKey);
      
      // Formato correcto para AVNU según documentación
      final formattedSignature = [
        '0x1', // signCount (número de firmas)
        '0x0', // starknetSignatureId (tipo de firma Starknet)
        userPublicKey, // clave pública del usuario
        signatureR, // componente R de la firma
        signatureS, // componente S de la firma
      ];
      
      print('Firma formateada para AVNU (formato correcto): $formattedSignature');
      
      return formattedSignature;
    } catch (e) {
      print('Error generando firma: $e');
      print('Stack trace: ${StackTrace.current}');
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
      // typedData ya está validado por el tipo, no puede ser null
      
      // Convertir typed data a JSON string limpio
      final String typedDataJson = jsonEncode(typedData.toJson());
      print('🔍 typedDataJson generado: ${typedDataJson.substring(0, 200)}...');
      
      final Map<String, dynamic> typedDataMap = jsonDecode(typedDataJson);
      _removeNullFields(typedDataMap);
      typedDataMap.remove('runtimeType');
      final String cleanTypedData = jsonEncode(typedDataMap);
      
      print('🧹 cleanTypedData después de limpiar: ${cleanTypedData.substring(0, 200)}...');
      
      print('Ejecutando transacción con:');
      print('- userAddress: $userAddress');
      print('- signature length: ${signature.length}');
      print('- signature: $signature');
      print('- cleanTypedData length: ${cleanTypedData.length}');
      
      // Validar que la firma tenga el formato correcto para AVNU
      if (signature.length != 5) {
        print('Error: La firma debe tener exactamente 5 elementos para AVNU (signCount, signatureId, publicKey, r, s), pero tiene ${signature.length}');
        return null;
      }
      
      // Validar que los elementos de la firma sean válidos
      for (int i = 0; i < signature.length; i++) {
        if (!signature[i].startsWith('0x')) {
          print('Error: Elemento de firma $i no tiene formato hexadecimal: ${signature[i]}');
          return null;
        }
        try {
          BigInt.parse(signature[i].substring(2), radix: 16);
        } catch (e) {
          print('Error: Elemento de firma $i no es un hexadecimal válido: ${signature[i]}');
          return null;
        }
      }
      
      // Validar que todos los parámetros requeridos no sean null
      if (userAddress.isEmpty) {
        print('Error: userAddress está vacío');
        return null;
      }
      
      if (cleanTypedData.isEmpty) {
        print('Error: cleanTypedData está vacío');
        return null;
      }
      
      if (signature.isEmpty) {
        print('Error: signature está vacía');
        return null;
      }
      
      // Validar que cleanTypedData sea JSON válido
      try {
        jsonDecode(cleanTypedData);
      } catch (e) {
        print('Error: cleanTypedData no es JSON válido: $e');
        return null;
      }
      
      print('🚀 Ejecutando transacción con AVNU Provider...');
      print('📋 Parámetros validados:');
      print('   - userAddress: $userAddress');
      print('   - cleanTypedData: ${cleanTypedData.substring(0, 100)}...');
      print('   - signature: $signature');
      
      // Ejecutar usando AVNU Provider
      // Para cuentas ya desplegadas, deploymentData puede ser un mapa vacío
      final deploymentData = <String, dynamic>{};
      
      final executeResult = await avnuProvider.execute(
        userAddress,
        cleanTypedData,
        signature,
        deploymentData,
      );

      // Validar que transactionHash no sea vacío
      if (executeResult.transactionHash.isEmpty) {
        print('Error: transactionHash está vacío en executeResult');
        print('executeResult completo: $executeResult');
        return null;
      }
      
      print('✅ Transacción ejecutada exitosamente: ${executeResult.transactionHash}');
      return executeResult.transactionHash;
          } catch (e) {
        print('Error en _executeTransaction: $e');
        print('Tipo de error: ${e.runtimeType}');
        
        // Analizar errores específicos de AVNU/Argent
        final errorString = e.toString();
        if (errorString.contains('argent/multicall-failed')) {
          print('❌ Error específico de Argent multicall - posible problema con la firma o el formato de la transacción');
        }
        if (errorString.contains('argent/invalid-signature-length')) {
          print('❌ Error específico de Argent - longitud de firma inválida');
          print('💡 Sugerencia: Verificar que la firma tenga exactamente 2 elementos (r, s)');
        }
        if (errorString.contains('ENTRYPOINT_FAILED')) {
          print('❌ Error de entrypoint - la función del contrato falló');
        }
        if (errorString.contains('500')) {
          print('❌ Error 500 del servidor AVNU - problema interno del servicio');
        }
        
        // Intentar extraer más información del error
        if (errorString.contains('revertError')) {
          final revertStart = errorString.indexOf('revertError');
          final revertEnd = errorString.indexOf('}', revertStart);
          if (revertEnd > revertStart) {
            final revertInfo = errorString.substring(revertStart, revertEnd + 1);
            print('📋 Información de revert: $revertInfo');
          }
        }
        
        print('Stack trace: ${StackTrace.current}');
        return null;
      }
  }

  /// Convertir string a hexadecimal
  String _stringToHex(String input) {
    return '0x${input.codeUnits.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Convertir string a ByteArray para el contrato Cairo
  List<String> _stringToByteArray(String input) {
    final bytes = utf8.encode(input);
    
    // Si el string es menor a 31 bytes, usar pending_word
    if (bytes.length <= 31) {
      final hexValue = bytes.isEmpty 
          ? '0x0' 
          : '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      return [
        '0x0', // data_len (0 chunks completos)
        hexValue, // pending_word
        '0x${bytes.length.toRadixString(16)}', // pending_word_len
      ];
    }
    
    // Para strings más largos, dividir en chunks de 31 bytes
    final chunks = <String>[];
    int i = 0;
    
    // Procesar chunks completos de 31 bytes
    while (i + 31 <= bytes.length) {
      final chunk = bytes.sublist(i, i + 31);
      final hexChunk = '0x${chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      chunks.add(hexChunk);
      i += 31;
    }
    
    // Procesar bytes restantes como pending_word
    final remainingBytes = bytes.sublist(i);
    final pendingWord = remainingBytes.isEmpty 
        ? '0x0' 
        : '0x${remainingBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    
    // Formato ByteArray: [data_len, data..., pending_word, pending_word_len]
    final result = <String>[];
    result.add('0x${chunks.length.toRadixString(16)}'); // data_len
    result.addAll(chunks); // data chunks
    result.add(pendingWord); // pending_word
    result.add('0x${remainingBytes.length.toRadixString(16)}'); // pending_word_len
    
    return result;
  }

  /// Convertir hex string a ByteArray para el contrato Cairo
  List<String> _hexStringToByteArray(String hexInput) {
    // Remover el prefijo 0x si existe
    String cleanHex = hexInput.startsWith('0x') ? hexInput.substring(2) : hexInput;
    
    // Asegurar que la longitud sea par
    if (cleanHex.length % 2 != 0) {
      cleanHex = '0$cleanHex';
    }
    
    // Convertir hex a bytes
    final bytes = <int>[];
    for (int i = 0; i < cleanHex.length; i += 2) {
      final hexByte = cleanHex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    
    final chunks = <String>[];
    
    // Dividir en chunks de 31 bytes (máximo para felt252)
    for (int i = 0; i < bytes.length; i += 31) {
      final chunk = bytes.sublist(i, (i + 31 < bytes.length) ? i + 31 : bytes.length);
      final hexChunk = '0x${chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      chunks.add(hexChunk);
    }
    
    // Formato ByteArray: [data_len, data..., pending_word, pending_word_len]
    final result = <String>[];
    result.add('0x${chunks.length.toRadixString(16)}'); // data_len
    result.addAll(chunks); // data chunks
    result.add('0x0'); // pending_word (vacío)
    result.add('0x0'); // pending_word_len (0)
    
    return result;
  }

  /// Convertir string a felt252
  String _stringToFelt252(String input) {
    // Para strings cortos, convertir directamente a felt252
    final bytes = utf8.encode(input);
    if (bytes.length > 31) {
      throw ArgumentError('String demasiado largo para felt252');
    }
    
    if (bytes.isEmpty) {
      return '0x0';
    }
    
    // Convertir string a felt252 como lo hace Cairo
    BigInt value = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      value = value * BigInt.from(256) + BigInt.from(bytes[i]);
    }
    
    final result = '0x${value.toRadixString(16)}';
    
    // Validar que el resultado sea parseable
    try {
      BigInt.parse(result.substring(2), radix: 16);
      return result;
    } catch (e) {
      print('Error validando felt252 generado: $result');
      return '0x0';
    }
  }

  /// Remover campos nulos de un mapa recursivamente
  void _removeNullFields(Map<String, dynamic> map) {
    // Crear una lista de claves a remover para evitar modificar el mapa durante la iteración
    final keysToRemove = <String>[];
    
    map.forEach((key, value) {
      if (value == null) {
        keysToRemove.add(key);
      } else if (value is Map<String, dynamic>) {
        _removeNullFields(value);
        // Si el mapa queda vacío después de limpiar, también lo removemos
        if (value.isEmpty) {
          keysToRemove.add(key);
        }
      } else if (value is List) {
        // Limpiar elementos nulos de la lista
        value.removeWhere((item) => item == null);
        // Limpiar mapas dentro de la lista
        for (var item in value) {
          if (item is Map<String, dynamic>) {
            _removeNullFields(item);
          }
        }
        // Si la lista queda vacía, la removemos
        if (value.isEmpty) {
          keysToRemove.add(key);
        }
      } else if (value is String) {
        // Validar que los strings hexadecimales sean válidos
        if (value.startsWith('0x')) {
          try {
            // Intentar parsear como BigInt para validar
            BigInt.parse(value.substring(2), radix: 16);
          } catch (e) {
            print('Valor hexadecimal inválido encontrado: $key = $value');
            // Convertir a 0x0 si es inválido
            map[key] = '0x0';
          }
        }
      }
    });
    
    // Remover todas las claves marcadas
    for (final key in keysToRemove) {
      map.remove(key);
    }
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

  /// Función de prueba para verificar el formato de ByteArray
  void _testByteArrayFormat() {
    // Probar con ejemplos de los tests del contrato
    final testHashCommit = "440c506dc4d939ccac762dc1ced8e965";
    final testResult = _stringToByteArray(testHashCommit);
    print('Test ByteArray para hashCommit "$testHashCommit": $testResult');
    
    final testName = "test_file.txt";
    final testNameResult = _stringToByteArray(testName);
    print('Test ByteArray para name "$testName": $testNameResult');
    
    final testAccessType = _stringToFelt252('timestamp');
    print('Test felt252 para "timestamp": $testAccessType');
  }
} 