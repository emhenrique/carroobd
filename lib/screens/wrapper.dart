
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Importação adicionada
import 'package:myapp/providers/obd2_provider.dart';
import 'package:myapp/screens/dashboard_screen.dart';
import 'package:myapp/screens/find_devices_screen.dart';
import 'package:provider/provider.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final obdProvider = context.watch<OBD2Provider>();

    // Se estiver conectado e não desconectando, mostra o painel.
    if (obdProvider.device != null && obdProvider.connectionState == BluetoothConnectionState.connected) {
      return const DashboardScreen();
    }
    
    // Caso contrário, mostra a tela de busca.
    return const FindDevicesScreen();
  }
}
