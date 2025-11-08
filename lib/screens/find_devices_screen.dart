
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:myapp/providers/obd2_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class FindDevicesScreen extends StatefulWidget {
  const FindDevicesScreen({super.key});

  @override
  State<FindDevicesScreen> createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if(mounted) setState(() => _adapterState = state);
      if (state == BluetoothAdapterState.on) _startScan(); // Inicia o scan se o bluetooth for ligado
    });
    _checkPermissionsAndBluetooth();
  }

  @override
  void dispose() {
    _stopScan();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndBluetooth() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Localização é necessária para o scan BLE
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (mounted) setState(() => _permissionsGranted = allGranted);

    if (allGranted) {
       _adapterState = await FlutterBluePlus.adapterState.first;
       if (_adapterState == BluetoothAdapterState.on) _startScan();
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return; // Se já está escaneando, não faz nada

    if (!_permissionsGranted || _adapterState != BluetoothAdapterState.on) {
        developer.log("Scan não iniciado: Permissões ou Bluetooth não estão prontos.", name: "FindDevicesScreen");
        return;
    }

    setState(() {
        _isScanning = true;
        _scanResults = []; // Limpa resultados antigos
    });

    // Garante que o scan anterior seja parado e a inscrição cancelada
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    // Começa a escutar os resultados do scan
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
            setState(() {
              // Filtra dispositivos sem nome e atualiza a lista
                _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
                 // Ordena por força do sinal (RSSI)
                _scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
            });
        }
    }, onError: (e) => developer.log("Erro no Stream de Scan: $e", name: "FindDevicesScreen"));

    // Inicia o scan com um timeout
    try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
        developer.log("Erro ao iniciar o scan: $e", name: "FindDevicesScreen");
        _stopScan(); // Para tudo em caso de erro
    } finally {
        // O `finally` pode não ser o ideal aqui se `stopScan` for chamado manualmente
        // Apenas garantimos que o estado de `_isScanning` seja falso ao final
        if (mounted) {
            // O timeout vai parar o scan, mas podemos deixar o estado de scanning
            // ser controlado pelo stopScan para maior clareza.
        }
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted && _isScanning) {
        setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Para o scan antes de tentar conectar para economizar bateria e evitar interferência
    await _stopScan(); 
    if (mounted) {
        await context.read<OBD2Provider>().connect(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obdProvider = context.watch<OBD2Provider>();
    final isConnecting = obdProvider.isConnecting;

    return Scaffold(
      appBar: AppBar(title: const Text('Procurar Dispositivo OBD2')),
      body: AbsorbPointer(
        absorbing: isConnecting,
        child: Stack(
          children: [
            _buildBody(context),
             if (isConnecting)
              Container(
                color: Colors.black.withAlpha(128),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Conectando...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_adapterState != BluetoothAdapterState.on || !_permissionsGranted || isConnecting)
          ? null 
          : (_isScanning ? _stopScan : _startScan), // Alterna entre iniciar e parar
        backgroundColor: (_adapterState != BluetoothAdapterState.on || !_permissionsGranted || isConnecting) ? Colors.grey : Theme.of(context).colorScheme.secondary,
        tooltip: _isScanning ? 'Parar Scan' : 'Procurar Dispositivos',
        child: _isScanning ? const Icon(Icons.stop) : const Icon(Icons.search),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_permissionsGranted) {
      return _buildInfoView(
        icon: Icons.lock, 
        title: "Permissões necessárias", 
        message: "Este aplicativo precisa de permissão de Bluetooth e Localização para escanear e se conectar a dispositivos. Por favor, conceda as permissões.",
        onPressed: _checkPermissionsAndBluetooth,
        buttonText: "Conceder Permissões",
      );
    }

    if (_adapterState != BluetoothAdapterState.on) {
      return _buildInfoView(
        icon: Icons.bluetooth_disabled, 
        title: "Bluetooth Desligado",
        message: "Por favor, ligue o Bluetooth do seu dispositivo para procurar scanners OBD2.",
      );
    }

    if (_isScanning && _scanResults.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16), 
          Text("Procurando dispositivos...")
        ]),
      );
    }

    if (!_isScanning && _scanResults.isEmpty) {
       return _buildInfoView(
        icon: Icons.search_off,
        title: "Nenhum dispositivo encontrado",
        message: "Verifique se o seu scanner OBD2 está ligado e ao alcance. Toque no botão de busca para tentar novamente.",
        onPressed: _startScan,
        buttonText: "Tentar Novamente",
      );
    }

    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        // UUID Padrão para Serial Port Profile (SPP), comum em adaptadores ELM327
        final isObd = result.advertisementData.serviceUuids.any((uuid) => uuid.toString().toUpperCase().startsWith("00001101"));
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isObd ? colorScheme.primaryContainer.withAlpha(77) : null,
          shape: isObd ? RoundedRectangleBorder(side: BorderSide(color: colorScheme.primary, width: 1.5), borderRadius: BorderRadius.circular(12)) : null,
          child: ListTile(
            title: Text(result.device.platformName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(result.device.remoteId.toString()),
            leading: CircleAvatar(
              backgroundColor: isObd ? colorScheme.primary : Colors.grey.shade300,
              child: Icon(Icons.bluetooth, color: isObd ? colorScheme.onPrimary : Colors.grey.shade700),
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _connectToDevice(result.device),
          ),
        );
      },
    );
  }
  
  Widget _buildInfoView({required IconData icon, required String title, required String message, VoidCallback? onPressed, String? buttonText}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,),
          if(onPressed != null && buttonText != null)
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
            ),
        ]),
      ),
    );
  }
}
