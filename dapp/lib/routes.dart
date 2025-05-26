import 'package:flutter/material.dart';
import '/pages/unlock_memory/unlock_memory_widget.dart';
import '/services/starknet/memory_contract_service.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/unlock_memory': (context) => UnlockMemoryWidget(
          memory: ModalRoute.of(context)!.settings.arguments as Memory,
        ),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/unlock_memory':
        return MaterialPageRoute(
          builder: (context) => UnlockMemoryWidget(
            memory: settings.arguments as Memory,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('Ruta no encontrada: ${settings.name}'),
            ),
          ),
        );
    }
  }
} 