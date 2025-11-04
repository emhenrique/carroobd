
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
  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndBluetooth();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if(mounted) {
        setState(() => _adapterState = state);
      }
      if (state == BluetoothAdapterState.on && _permissionsGranted) {
        _startScan();
      }
    });
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
      Permission.location,
    ].request();

    final permissionsGranted = statuses[Permission.bluetoothScan]!.isGranted &&
                             statuses[Permission.bluetoothConnect]!.isGranted &&
                             statuses[Permission.location]!.isGranted;
    if(mounted) {
      setState(() => _permissionsGranted = permissionsGranted);
    }

    if (permissionsGranted) {
       final adapterState = await FlutterBluePlus.adapterState.first;
       if(mounted) {
         setState(() => _adapterState = adapterState);
       }
       if(adapterState == BluetoothAdapterState.on) {
         _startScan();
       }
    } 
  }

  Future<void> _startScan() async {
    if (!_permissionsGranted || _adapterState != BluetoothAdapterState.on || _isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          if (mounted) {
            setState(() {
              for (var res in results) {
                final index = _scanResults.indexWhere((r) => r.device.remoteId == res.device.remoteId);
                if(index == -1 && res.device.platformName.isNotEmpty) {
                  _scanResults.add(res);
                }
              }
              _scanResults.sort((a, b) => b.rssi.compareTo(a.rssi)); 
            });
          }
      }, onError: (e) => developer.log("Erro no Scan: $e", name: "FindDevicesScreen"));

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } finally {
       if(mounted) {
         setState(() => _isScanning = false);
       }
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    if(mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _stopScan();
    await context.read<OBD2Provider>().connect(device);
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
        onPressed: _adapterState != BluetoothAdapterState.on || !_permissionsGranted || isConnecting
          ? null 
          : (_isScanning ? _stopScan : _startScan),
        backgroundColor: _adapterState != BluetoothAdapterState.on || !_permissionsGranted || isConnecting ? Colors.grey : null,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
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
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [ 
                const Icon(Icons.search_off, size: 80, color: Colors.grey), 
                const SizedBox(height: 16),
                const Text("Nenhum dispositivo encontrado.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Verifique se o seu scanner OBD2 está ligado e ao alcance. Toque no botão de busca para tentar novamente.", textAlign: TextAlign.center),
             ]
           ),
         ),
       );
    }

    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        final isObd = result.advertisementData.serviceUuids.any((uuid) => uuid.toString().toUpperCase().startsWith("00001101"));
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isObd ? colorScheme.primaryContainer.withAlpha(77) : null,
          shape: isObd ? RoundedRectangleBorder(side: BorderSide(color: colorScheme.primary, width: 1.5), borderRadius: BorderRadius.circular(12)) : null,
          child: ListTile(
            title: Text(result.device.platformName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(result.device.remoteId.toString()),
            leading: const Icon(Icons.bluetooth, color: Colors.blueAccent),
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
