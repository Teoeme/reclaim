import 'package:starknet_provider/starknet_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_util.dart';

class StarknetConfig {
  static const String rpcUrl = 'https://starknet-sepolia.public.blastapi.io/rpc/v0_8';
  static const String contractAddress = '0x023398f48021e7fc236e1f57b4b332cf26c3b29b5e06697186efba134bde5650';
  
  static const List<Map<String, dynamic>> contractAbi = [
    {
      "type": "impl",
      "name": "ReclaimImpl",
      "interface_name": "contracts::reclaim::IReclaim"
    },
    {
      "type": "struct",
      "name": "core::byte_array::ByteArray",
      "members": [
        {
          "name": "data",
          "type": "core::array::Array::<core::bytes_31::bytes31>"
        },
        {
          "name": "pending_word",
          "type": "core::felt252"
        },
        {
          "name": "pending_word_len",
          "type": "core::integer::u32"
        }
      ]
    },
    {
      "type": "interface",
      "name": "contracts::reclaim::IReclaim",
      "items": [
        {
          "type": "function",
          "name": "get_records_by_owner",
          "inputs": [
            {
              "name": "owner",
              "type": "core::felt252"
            }
          ],
          "outputs": [
            {
              "type": "core::array::Array::<(core::byte_array::ByteArray, core::felt252, core::felt252, core::felt252, core::byte_array::ByteArray)>"
            }
          ],
          "state_mutability": "view"
        }
      ]
    }
  ];
  
  static JsonRpcProvider getProvider() {
    return JsonRpcProvider.new(
      nodeUri: Uri.parse(rpcUrl),
    );
  }
  
  static Future<JsonRpcProvider> getProviderWithAccount() async {
    final provider = getProvider();
    
    // Obtener el usuario actual de Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    // Obtener la wallet del usuario
    final walletResult = await CreateOGetWalletCall.call(
      firebaseUserUuid: user.uid,
    );

    if (!walletResult.succeeded) {
      throw Exception('No se pudo obtener la wallet del usuario');
    }

    final encryptedPrivateKey = CreateOGetWalletCall.encryptedPrivateKey(walletResult.jsonBody);
    if (encryptedPrivateKey == null) {
      throw Exception('No se pudo obtener la private key');
    }

    try {
      // Desencriptar la private key usando la función de custom_functions.dart
      final hashSecret = FFDevEnvironmentValues().HashSecret;
      final decryptedPrivateKey = decryptWithRSA(
        encryptedPrivateKey,
        hashSecret, 
      );

      print('🔐 Private key desencriptada exitosamente');
      
      // TODO: Usar la private key desencriptada para crear la cuenta
      // Por ahora retornamos el provider sin cuenta
      return provider;
    } catch (e) {
      print('❌ Error al desencriptar la private key: $e');
      throw Exception('Error al desencriptar la private key: $e');
    }
  }
} 