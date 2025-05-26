import 'package:starknet/starknet.dart' hide Signer;
import 'package:starknet/starknet.dart' as starknet show Signer;
import 'package:avnu_provider/avnu_provider.dart';
import 'package:starknet_provider/starknet_provider.dart' show FunctionCall, BlockId;
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/config/starknet_config.dart';
import '/utils/starknet_utils.dart';

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
      
      // Limpiar el hash_commit
      String cleanHashCommit;
      if (hashCommit.startsWith('0x')) {
        // Si empieza con 0x, remover ese prefijo
        cleanHashCommit = hashCommit.substring(2);
        print('  - hashCommit limpio (removido 0x): $cleanHashCommit');
      } else {
        cleanHashCommit = hashCommit;
        print('  - hashCommit limpio (sin cambios): $cleanHashCommit');
      }

      // Convertir el hash hexadecimal a UTF-8
      print('  - hashCommit original en hex: $cleanHashCommit');
      
      // Convertir cada par de caracteres hexadecimales a bytes
      final bytes = <int>[];
      for (int i = 0; i < cleanHashCommit.length; i += 2) {
        final hexPair = cleanHashCommit.substring(i, i + 2);
        final byte = int.parse(hexPair, radix: 16);
        bytes.add(byte);
      }
      
      // Convertir los bytes a string UTF-8
      final hashCommitString = String.fromCharCodes(bytes);
      print('  - hashCommit convertido a UTF-8: $hashCommitString');

      // Convertir el hash_commit a ByteArray
      final hashCommitByteArray = _stringToByteArray(hashCommitString);
      print('  - hashCommitByteArray: $hashCommitByteArray');
      
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

      // Obtener el class hash de la cuenta del usuario
      String accountClassHash;
      try {
        // Intentar obtener el class hash usando una llamada HTTP directa
        accountClassHash = await _getAccountClassHash(userAddress);
        print('✅ Class hash obtenido dinámicamente: $accountClassHash');
      } catch (e) {
        print('⚠️ No se pudo obtener class hash dinámicamente, usando Argent por defecto: $e');
        // Fallback a class hash conocido de Argent
        accountClassHash = '0x01a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003';
        print('Usando class hash de Argent por defecto: $accountClassHash');
      }
      
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
        final userAddressFelt = Felt.fromHexString(userAddress).toBigInt();
        print('🔍 User address como BigInt: 0x${userAddressFelt.toRadixString(16)}');
        
        messageHash = getMessageHash(typedDataObject, userAddressFelt);
        print('✅ Message hash generado exitosamente: 0x${messageHash.toRadixString(16)}');
        
        // Validar que el message hash sea válido
        if (messageHash == BigInt.zero) {
          print('❌ Error: Message hash es cero, esto indica un problema');
          return null;
        }
      } catch (e) {
        print('❌ Error generando message hash: $e');
        print('📋 User address: $userAddress');
        print('📋 TypedData map: ${jsonEncode(typedDataMap)}');
        return null;
      }
      
      // Firmar el hash
      dynamic signature;
      try {
        print('🔐 Iniciando proceso de firma...');
        print('🔐 Private key (primeros 8 chars): ${privateKey.toRadixString(16).substring(0, 8)}...');
        print('🔐 Message hash: 0x${messageHash.toRadixString(16)}');
        
        signature = starknetSign(
          privateKey: privateKey,
          messageHash: messageHash,
          seed: BigInt.from(32),
        );
        
        print('✅ Firma generada exitosamente:');
        print('   - r: 0x${signature.r.toRadixString(16)}');
        print('   - s: 0x${signature.s.toRadixString(16)}');
        
        // Validar que los componentes de la firma no sean cero
        if (signature.r == BigInt.zero || signature.s == BigInt.zero) {
          print('❌ Error: Componentes de firma inválidos (r o s es cero)');
          return null;
        }
      } catch (e) {
        print('❌ Error firmando: $e');
        print('📋 Stack trace: ${StackTrace.current}');
        return null;
      }
      
      // Formatear la firma según el formato esperado por cuentas Argent
      // Para cuentas Argent, solo necesitamos los componentes r y s de la firma
      final signatureR = Felt(signature.r).toHexString();
      final signatureS = Felt(signature.s).toHexString();
      
      // Formato correcto para cuentas Argent: solo [r, s]
      final formattedSignature = [
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
    // Validar y normalizar userAddress antes del try-catch
    if (userAddress.isEmpty) {
      print('❌ Error: userAddress está vacío');
      return null;
    }
    
    if (!_isValidStarknetAddress(userAddress)) {
      print('❌ Error: userAddress no es válido: $userAddress');
      return null;
    }
    
    // Normalizar la dirección para asegurar formato consistente
    final normalizedUserAddress = _normalizeStarknetAddress(userAddress);
    print('📍 Dirección normalizada: $userAddress -> $normalizedUserAddress');
    
    try {
      // Validar que la firma tenga el formato correcto para cuentas Argent
      if (!_isValidAvnuSignature(signature)) {
        print('❌ Error: Firma no válida para cuenta Argent');
        return null;
      }
      
      // Procesar typed data siguiendo exactamente el patrón de la documentación AVNU
      final String typedDataJson = jsonEncode(typedData.toJson());
      print('🔍 typedData inicial: ${typedDataJson.substring(0, 200)}...');
      
      // Crear TypedData object para validación
      final typedDataObject = TypedData.fromJson(jsonDecode(typedDataJson));
      print('✅ TypedData object creado exitosamente');
      
      // Remove null fields from typedData and remove runtimeType field (siguiendo documentación)
      final Map<String, dynamic> typedDataMap = jsonDecode(typedDataJson);
      _removeNullFields(typedDataMap);
      typedDataMap.remove('runtimeType');
      final String cleanTypedData = jsonEncode(typedDataMap);
      
      print('🧹 cleanTypedData después de limpiar: ${cleanTypedData.substring(0, 200)}...');
      
      print('🚀 Ejecutando transacción con AVNU Provider...');
      print('📋 Parámetros validados:');
      print('   - userAddress: $normalizedUserAddress');
      print('   - signature: $signature');
      print('   - cleanTypedData length: ${cleanTypedData.length}');
      print('   - typedData primaryType: ${typedDataMap['primaryType']}');
      print('   - typedData domain: ${jsonEncode(typedDataMap['domain'])}');
      
      // Para cuentas ya desplegadas, deploymentData debe ser null
      final deploymentData = null;
      
      print('📤 Enviando petición al endpoint /paymaster/v1/execute con:');
      print('   - userAddress: $normalizedUserAddress');
      print('   - typedData: ${cleanTypedData.substring(0, 100)}...');
      print('   - signature: $signature');
      print('   - deploymentData: $deploymentData');
      
      final executeResult = await avnuProvider.execute(
        normalizedUserAddress,
        cleanTypedData,
        signature,
        deploymentData,
      );
      print('executeResult: $executeResult');
      // Validar que executeResult no sea null
      if (executeResult == null) {
        print('❌ Error: executeResult es null');
        return null;
      }
      
      // Validar que transactionHash no sea vacío
      if (executeResult.transactionHash.isEmpty) {
        print('❌ Error: transactionHash está vacío en executeResult');
        print('executeResult completo: $executeResult');
        return null;
      }
      
      print('✅ Transacción ejecutada exitosamente: ${executeResult.transactionHash}');
      return executeResult.transactionHash;
      
    } catch (e) {
      print('❌ Error en _executeTransaction: $e');
      print('🔍 Tipo de error: ${e.runtimeType}');
      
      // Analizar errores específicos de AVNU/Argent
      final errorString = e.toString();
      
      if (errorString.contains('400')) {
        print('❌ Error 400 Bad Request - Parámetros inválidos enviados al paymaster');
        print('💡 Posibles causas:');
        print('   - Formato incorrecto del userAddress');
        print('   - Estructura inválida del typedData');
        print('   - Firma con formato incorrecto');
        print('   - deploymentData con estructura incorrecta');
        
        // Imprimir detalles adicionales para debugging
        print('🔍 Detalles de debugging:');
        print('   - userAddress original: $userAddress');
        print('   - userAddress normalizada: $normalizedUserAddress');
        print('   - userAddress length: ${normalizedUserAddress.length}');
        print('   - signature length: ${signature.length}');
        print('   - userAddress starts with 0x: ${normalizedUserAddress.startsWith('0x')}');
        
        // Validar cada elemento de la firma
        for (int i = 0; i < signature.length; i++) {
          print('   - signature[$i]: ${signature[i]} (length: ${signature[i].length})');
        }
      }
      
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
      
      print('📚 Stack trace: ${StackTrace.current}');
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

  /// Función removeNullFields según documentación AVNU
  void removeNullFields(Map<String, dynamic> map) {
    map.removeWhere((key, value) => value == null);
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        removeNullFields(value);
      } else if (value is List) {
        value.removeWhere((item) => item == null);
        for (var item in value) {
          if (item is Map<String, dynamic>) {
            removeNullFields(item);
          }
        }
      }
    });
  }

  /// Remover campos nulos de un mapa recursivamente (versión extendida)
  void _removeNullFields(Map<String, dynamic> map) {
    // Crear una lista de claves a remover para evitar modificar el mapa durante la iteración
    final keysToRemove = <String>[];
    
    map.forEach((key, value) {
      if (value == null) {
        keysToRemove.add(key);
        print('🧹 Removiendo campo nulo: $key');
      } else if (value is Map<String, dynamic>) {
        _removeNullFields(value);
        // Si el mapa queda vacío después de limpiar, también lo removemos
        if (value.isEmpty) {
          keysToRemove.add(key);
          print('🧹 Removiendo mapa vacío: $key');
        }
      } else if (value is List) {
        // Limpiar elementos nulos de la lista
        final originalLength = value.length;
        value.removeWhere((item) => item == null);
        if (value.length != originalLength) {
          print('🧹 Removidos ${originalLength - value.length} elementos nulos de la lista: $key');
        }
        
        // Limpiar mapas dentro de la lista
        for (var item in value) {
          if (item is Map<String, dynamic>) {
            _removeNullFields(item);
          }
        }
        
        // Si la lista queda vacía, la removemos
        if (value.isEmpty) {
          keysToRemove.add(key);
          print('🧹 Removiendo lista vacía: $key');
        }
      } else if (value is String) {
        // Validar strings vacíos
        if (value.isEmpty) {
          keysToRemove.add(key);
          print('🧹 Removiendo string vacío: $key');
        }
        // Validar que los strings hexadecimales sean válidos
        else if (value.startsWith('0x')) {
          if (value.length < 3) {
            print('⚠️ Valor hexadecimal muy corto: $key = $value, convirtiendo a 0x0');
            map[key] = '0x0';
          } else {
            try {
              // Intentar parsear como BigInt para validar
              BigInt.parse(value.substring(2), radix: 16);
            } catch (e) {
              print('⚠️ Valor hexadecimal inválido encontrado: $key = $value, convirtiendo a 0x0');
              // Convertir a 0x0 si es inválido
              map[key] = '0x0';
            }
          }
        }
      } else if (value is num) {
        // Validar números
        if (value.isNaN || value.isInfinite) {
          keysToRemove.add(key);
          print('🧹 Removiendo número inválido: $key = $value');
        }
      }
    });
    
    // Remover todas las claves marcadas
    for (final key in keysToRemove) {
      map.remove(key);
      print('🗑️ Campo removido: $key');
    }
  }

  /// Validar formato de dirección de Starknet
  bool _isValidStarknetAddress(String address) {
    try {
      // Debe empezar con 0x
      if (!address.startsWith('0x')) {
        print('❌ Dirección debe empezar con 0x: $address');
        return false;
      }
      
      // Remover el prefijo 0x
      final hexPart = address.substring(2);
      
      // Debe tener entre 1 y 64 caracteres hexadecimales (felt252 máximo)
      if (hexPart.isEmpty || hexPart.length > 64) {
        print('❌ Dirección tiene longitud inválida: ${hexPart.length} (debe ser 1-64)');
        return false;
      }
      
      // Debe ser hexadecimal válido
      BigInt.parse(hexPart, radix: 16);
      
      // Validar que no sea 0x0 (dirección inválida)
      if (address == '0x0' || address == '0x00') {
        print('❌ Dirección no puede ser 0x0');
        return false;
      }
      
      print('✅ Dirección válida: $address');
      return true;
    } catch (e) {
      print('❌ Error validando dirección $address: $e');
      return false;
    }
  }

  /// Normalizar dirección de Starknet (asegurar formato correcto)
  String _normalizeStarknetAddress(String address) {
    try {
      if (!address.startsWith('0x')) {
        address = '0x$address';
      }
      
      // Parsear y volver a formatear para normalizar
      final hexPart = address.substring(2);
      final bigIntValue = BigInt.parse(hexPart, radix: 16);
      
      // Convertir de vuelta a hex sin ceros innecesarios al inicio
      return '0x${bigIntValue.toRadixString(16)}';
    } catch (e) {
      print('❌ Error normalizando dirección $address: $e');
      return address; // Retornar original si hay error
    }
  }

  /// Validar formato de firma para cuentas Argent
  bool _isValidAvnuSignature(List<String> signature) {
    try {
      // Cuentas Argent requieren exactamente 2 elementos: [r, s]
      if (signature.length != 2) {
        print('❌ Firma debe tener exactamente 2 elementos, tiene: ${signature.length}');
        return false;
      }
      
      // Validar cada elemento
      for (int i = 0; i < signature.length; i++) {
        final element = signature[i];
        
        // Debe empezar con 0x
        if (!element.startsWith('0x')) {
          print('❌ Elemento de firma $i debe empezar con 0x: $element');
          return false;
        }
        
        // Debe ser hexadecimal válido
        try {
          BigInt.parse(element.substring(2), radix: 16);
        } catch (e) {
          print('❌ Elemento de firma $i no es hexadecimal válido: $element');
          return false;
        }
        
        // Validaciones específicas por posición
        switch (i) {
          case 0: // r
          case 1: // s
            final hexPart = element.substring(2);
            if (hexPart.length > 64) {
              print('❌ Componente de firma ${i == 0 ? 'r' : 's'} muy largo: ${hexPart.length} caracteres');
              return false;
            }
            if (element == '0x0') {
              print('❌ Componente de firma ${i == 0 ? 'r' : 's'} no puede ser 0x0');
              return false;
            }
            break;
        }
      }
      
      print('✅ Firma válida para cuenta Argent: $signature');
      return true;
    } catch (e) {
      print('❌ Error validando firma: $e');
      return false;
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

  /// Obtener el class hash de una cuenta usando llamada HTTP directa
  Future<String> _getAccountClassHash(String accountAddress) async {
    try {
      // Hacer una llamada HTTP directa al RPC de Starknet
      final response = await http.post(
        Uri.parse('https://starknet-sepolia.public.blastapi.io/rpc/v0_8'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'starknet_getClassHashAt',
          'params': [
            'latest',
            accountAddress,
          ],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['result'] != null) {
          final classHash = responseData['result'] as String;
          print('✅ Class hash obtenido: $classHash');
          return classHash;
        } else if (responseData['error'] != null) {
          throw Exception('Error RPC: ${responseData['error']}');
        }
      }
      
      throw Exception('Error HTTP: ${response.statusCode}');
    } catch (e) {
      print('❌ Error obteniendo class hash: $e');
      rethrow;
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

  /// Reclama una memoria usando una llamada simple al contrato
  Future<ReclaimResult?> reclaimMemory({
    required String userAddress,
    required String hashCommit,
    required String encryptedPrivateKey,
    required String userPublicKey,
  }) async {
    try {
      print('🔍 Iniciando reclaimMemory con:');
      print('  - userAddress: $userAddress');
      print('  - hashCommit original: $hashCommit');
      
      // Validar que todos los parámetros requeridos estén presentes
      if (userAddress.isEmpty || hashCommit.isEmpty) {
        print('❌ Error: Parámetros requeridos faltantes');
        return null;
      }

      // Limpiar el hash_commit
      String cleanHashCommit;
      if (hashCommit.startsWith('0x')) {
        // Si empieza con 0x, remover ese prefijo
        cleanHashCommit = hashCommit.substring(2);
        print('  - hashCommit limpio (removido 0x): $cleanHashCommit');
      } else {
        cleanHashCommit = hashCommit;
        print('  - hashCommit limpio (sin cambios): $cleanHashCommit');
      }

      // Construir el ByteArray manualmente
      final hashCommitByteArray = <String>[
        '0x1', // longitud del array (1 chunk)
        '0x${cleanHashCommit}', // el hash completo como un chunk
        '0x0', // pending_word
        '0x0'  // pending_len
      ];
      print('  - hashCommitByteArray: $hashCommitByteArray');

      // Obtener el provider configurado
      final provider = StarknetConfig.getProvider();

      // Obtener el selector de la función
      Felt selector;
      try {
        selector = await StarknetUtils.getFunctionSelector(
          provider,
          StarknetConfig.contractAddress,
          'reclaim',
        );
      } catch (e) {
        selector = Felt.fromHexString('0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e');
      }

      // Hacer la llamada al contrato usando el provider
      final result = await provider.call(
        request: FunctionCall(
          contractAddress: Felt.fromHexString(StarknetConfig.contractAddress),
          entryPointSelector: selector,
          calldata: hashCommitByteArray.map((e) => Felt.fromHexString(e)).toList(),
        ),
        blockId: BlockId.latest,
      );

      return result.when(
        result: (data) {
          print('✅ Resultado de la llamada al contrato:');
          print('  - Result: $data');
          
          // Parsear el resultado usando la nueva función
          try {
            final reclaimResult = parseReclaimResult(data);
            print('✅ Reclaim result parseado exitosamente');
            return reclaimResult;
          } catch (e) {
            print('❌ Error parseando reclaim result: $e');
            return null;
          }
        },
        error: (error) {
          print('❌ Error al llamar el contrato: $error');
          return null;
        },
      );
    } catch (e) {
      print('❌ Error en reclaimMemory: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }
} 