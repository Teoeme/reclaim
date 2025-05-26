import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/services/starknet/memory_contract_service.dart';
import '/services/starknet_service.dart';
import '/backend/api_requests/api_calls.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/utils/starknet_utils.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:convert';

class UnlockMemoryWidget extends StatefulWidget {
  final Memory memory;

  const UnlockMemoryWidget({
    Key? key,
    required this.memory,
  }) : super(key: key);

  static String routeName = 'UnlockMemory';
  static String routePath = '/unlock_memory';

  @override
  State<UnlockMemoryWidget> createState() => _UnlockMemoryWidgetState();
}

class _UnlockMemoryWidgetState extends State<UnlockMemoryWidget> {
  String? _transactionHash;
  ReclaimResult? reclaimResult;
  bool _isLoading = false;
  String? _error;
  Uint8List? _decryptedImage;

  Future<void> _decryptAndLoadImage() async {
    if (reclaimResult == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 1. Obtener wallet info
      final walletResponse = await CreateOGetWalletCall.call(
        firebaseUserUuid: currentUserUid,
      );

      if (!(walletResponse?.succeeded ?? false)) {
        throw Exception('No se pudo obtener la información del wallet');
      }

      final userPrivateKey = CreateOGetWalletCall.encryptedPrivateKey(walletResponse?.jsonBody);
      if (userPrivateKey == null || userPrivateKey.isEmpty) {
        throw Exception('La clave privada del wallet está incompleta');
      }

      // 2. Descifrar el cipher secret usando RSA
      final aesKey = await decryptCipherSecret(
        cipherSecret: reclaimResult!.cipherSecret,
        encryptedPrivateKey: userPrivateKey,
        hashSecret: FFDevEnvironmentValues().HashSecret,
      );
      print('✅ AES Key obtenida: $aesKey');

      // 3. Obtener el contenido de IPFS
      final encryptedContent = await getIpfsContent(reclaimResult!.cid);
      print('✅ Contenido de IPFS obtenido');

      // 4. Descifrar el contenido usando la clave AES
      final decryptedContent = decryptIpfsContent(encryptedContent, aesKey);
      print('✅ Contenido descifrado');

      // 5. Convertir el contenido descifrado a bytes (asumiendo que es una imagen)
      final imageBytes = base64Decode(decryptedContent);
      
      setState(() {
        _decryptedImage = imageBytes;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Error al descifrar la imagen: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        automaticallyImplyLeading: false,
        leading: FlutterFlowIconButton(
          borderColor: Colors.transparent,
          borderRadius: 30.0,
          borderWidth: 1.0,
          buttonSize: 60.0,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: FlutterFlowTheme.of(context).tertiary,
            size: 30.0,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Desbloquear Memoria',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.interTight(
                  fontWeight: FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).tertiary,
                fontSize: 22.0,
                letterSpacing: 0.0,
              ),
        ),
        centerTitle: true,
        elevation: 2.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalles de la Memoria',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.roboto(
                          fontWeight: FontWeight.w600,
                        ),
                        fontSize: 28.0,
                      ),
                ),
                SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Título: ${widget.memory.title}',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Fecha de desbloqueo: ${widget.memory.createdAt.toString().split('.')[0]}',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tipo de acceso: ${widget.memory.accessType}',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (_decryptedImage != null) ...[
                  Text(
                    'Contenido de la Memoria:',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.roboto(
                            fontWeight: FontWeight.w600,
                          ),
                          fontSize: 20.0,
                        ),
                  ),
                  SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _decryptedImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _unlockMemory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Desbloquear Memoria',
                            style: TextStyle(
                              color: FlutterFlowTheme.of(context).tertiary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlockMemory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Obtener wallet info
      final walletResponse = await CreateOGetWalletCall.call(
        firebaseUserUuid: currentUserUid,
      );

      if (!(walletResponse?.succeeded ?? false)) {
        throw Exception('No se pudo obtener la información del wallet');
      }

      final userPublicKey = CreateOGetWalletCall.publicKey(walletResponse?.jsonBody);
      final userPrivateKey = CreateOGetWalletCall.encryptedPrivateKey(walletResponse?.jsonBody);
      final userWalletAddress = CreateOGetWalletCall.address(walletResponse?.jsonBody);

      if (userPublicKey == null || userPublicKey.isEmpty ||
          userPrivateKey == null || userPrivateKey.isEmpty ||
          userWalletAddress == null || userWalletAddress.isEmpty) {
        throw Exception('Los datos del wallet están incompletos');
      }

      // 2. Verificar AVNU
      final starknetService = StarknetService();
      final avnuStatus = await starknetService.checkAvnuStatus();
      if (!avnuStatus) {
        throw Exception('El servicio AVNU no está disponible en este momento');
      }

      // 3. Llamar al contrato
      reclaimResult = await starknetService.reclaimMemory(
        userAddress: userWalletAddress,
        hashCommit: widget.memory.id,
        encryptedPrivateKey: userPrivateKey,
        userPublicKey: userPublicKey,
      );

      if (reclaimResult == null) {
        throw Exception('No se pudo desbloquear la memoria');
      }

      // 4. Descifrar y cargar la imagen
      await _decryptAndLoadImage();

      // 5. Mostrar éxito
      if (mounted) {
        final result = reclaimResult!;
        await showDialog(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: Text('¡Memoria Desbloqueada!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu memoria ha sido desbloqueada exitosamente.'),
                  SizedBox(height: 10),
                  Text('Detalles de la memoria:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(
                    'Cipher Secret: ${result.cipherSecret}\n'
                    'CID: ${result.cid}\n'
                    'Hash Commit: ${result.hashCommit}\n'
                    'Owner: ${result.owner}\n'
                    'Access Type: ${result.accessType}\n'
                    'Name: ${result.name}',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(alertDialogContext);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }

    } catch (e) {
      setState(() {
        _error = 'Error al desbloquear la memoria: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 