import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/services/starknet/memory_contract_service.dart';
import '/services/starknet_service.dart';
import '/backend/api_requests/api_calls.dart';
import '/auth/firebase_auth/auth_util.dart';

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
  bool _isLoading = false;
  String? _error;

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
      final reclaimResult = await starknetService.reclaimMemory(
        userAddress: userWalletAddress,
        hashCommit: widget.memory.id,
        encryptedPrivateKey: userPrivateKey,
        userPublicKey: userPublicKey,
      );

      if (reclaimResult == null) {
        throw Exception('No se pudo desbloquear la memoria');
      }

      // 4. Mostrar éxito
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
                Text('Hash de transacción:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(reclaimResult, style: TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(alertDialogContext);
                  Navigator.pop(context); // Volver a la lista de memorias
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );

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