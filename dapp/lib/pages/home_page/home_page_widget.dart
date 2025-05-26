import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/backend/api_requests/api_calls.dart';
import 'home_page_model.dart';
import '../../services/starknet/memory_contract_service.dart';
import '../../config/starknet_config.dart';
import '../../widgets/memory_list.dart';

export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget>
    with TickerProviderStateMixin {
  late HomePageModel _model;
  late MemoryContractService _memoryService;
  bool _isInitialized = false;
  String? _ownerAddress;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
    _initializeStarknet();
  }

  Future<void> _initializeStarknet() async {
    try {
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

      // Obtener la dirección de la wallet del resultado
      final walletData = walletResult.jsonBody;
      print('📦 Datos de la wallet: $walletData');
      
      final walletAddress = walletData['address'] as String?;
      if (walletAddress == null) {
        throw Exception('No se pudo obtener la dirección de la wallet');
      }

      print('👛 Dirección de la wallet obtenida: $walletAddress');

try{
      final account = await StarknetConfig.getAccount();
  
      print('👤 Cuenta obtenida: $account');
} catch (e){
  print('❌ Error al obtener la cuenta: $e');
  return;
}

      // Obtener el provider con la cuenta
      final provider = await StarknetConfig.getProvider();
      
      setState(() {
        _ownerAddress = walletAddress;
        _memoryService = MemoryContractService(
          provider: provider,
        );
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Error al inicializar Starknet: $e');
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            context.pushNamed(ServicesWidget.routeName);
          },
          backgroundColor: FlutterFlowTheme.of(context).secondary,
          elevation: 8.0,
          child: Icon(
            Icons.add_rounded,
            color: FlutterFlowTheme.of(context).info,
            size: 24.0,
          ),
        ),
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          title: Text(
            'Memories',
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
        body: !_isInitialized || _ownerAddress == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : MemoryList(
                memoryService: _memoryService,
                ownerAddress: _ownerAddress!,
        ),
      ),
    );
  }
}
