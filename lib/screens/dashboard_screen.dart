
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:myapp/providers/obd2_provider.dart';
import 'package:myapp/screens/dtc_screen.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final provider = context.read<OBD2Provider>();
    setState(() => _pageIndex = index);
    if (index == 0) {
      provider.startSensorPolling();
    } else {
      provider.stopSensorPolling();
      if (provider.dtcList.isEmpty && !provider.isReadingDtcs) provider.readDTCs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OBD2Provider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.device?.platformName ?? "Painel OBD2"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: () => context.read<OBD2Provider>().disconnect(),
            tooltip: "Desconectar",
          )
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: const [
              SensorPanel(),
              DtcScreen(),
            ],
          ),
          if (provider.isInitializing)
            Container(
              color: Colors.black.withAlpha(204),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(provider.initializationStatus, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: provider.isInitializing ? null : _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _pageIndex,
      onTap: (index) => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Painel'),
        BottomNavigationBarItem(icon: Icon(Icons.error_outline), label: 'Códigos de Falha'),
      ],
    );
  }
}

class SensorPanel extends StatefulWidget {
  const SensorPanel({super.key});

  @override
  State<SensorPanel> createState() => _SensorPanelState();
}

class _SensorPanelState extends State<SensorPanel> {
  bool _isOverlayActive = false;

  @override
  void initState() {
    super.initState();
    // Garante que o estado do switch reflita o estado real da sobreposição ao iniciar a tela
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isActive = await FlutterOverlayWindow.isActive() ?? false;
      if (mounted) setState(() => _isOverlayActive = isActive);
    });
  }

  Future<void> _toggleOverlay(bool value) async {
    if (value) {
      final hasPermission = await FlutterOverlayWindow.requestPermission();
      if (!hasPermission) return;
      
      await FlutterOverlayWindow.showOverlay(
          height: 60,
          width: 200,
          alignment: OverlayAlignment.topCenter,
          overlayTitle: "Temperatura do Motor",
          enableDrag: true);
       if (mounted) setState(() => _isOverlayActive = true);

    } else {
      await FlutterOverlayWindow.closeOverlay();
       if (mounted) setState(() => _isOverlayActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OBD2Provider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildStatusIndicator(context, provider.connectionState),
          if (Platform.isAndroid) _buildOverlaySwitch(),
          const SizedBox(height: 20),
          _buildRPMGauge(provider.rpm),
          const SizedBox(height: 20),
          _buildSpeedGauge(provider.speed),
          const SizedBox(height: 20),
          _buildCoolantGauge(provider.coolantTemp),
        ],
      ),
    );
  }

  Widget _buildOverlaySwitch(){
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: SwitchListTile(
        title: const Text('Pop-up de Temperatura'),
        subtitle: const Text('Exibe a temperatura sobre outros apps'),
        value: _isOverlayActive,
        onChanged: _toggleOverlay,
        secondary: const Icon(Icons.thermostat_outlined),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, BluetoothConnectionState connectionState) {
    final isConnected = connectionState == BluetoothConnectionState.connected;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: isConnected ? colorScheme.primaryContainer.withAlpha(128) : colorScheme.errorContainer.withAlpha(128),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isConnected ? colorScheme.primary : colorScheme.error, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: isConnected ? colorScheme.primary : colorScheme.error),
            const SizedBox(width: 8),
            Text(isConnected ? "CONECTADO" : "DESCONECTADO", style: TextStyle(fontWeight: FontWeight.bold, color: isConnected ? colorScheme.primary : colorScheme.error)),
        ]),
    );
  }

  Widget _buildRPMGauge(double? rpm) => _buildGauge('RPM', rpm, 8000, [0, 2000, 4000, 8000]);
  Widget _buildSpeedGauge(double? speed) => _buildGauge('Velocidade (km/h)', speed, 220, [0, 60, 120, 220]);

  Widget _buildGauge(String title, double? value, double max, List<double> ranges) {
    return SfRadialGauge(
      title: GaugeTitle(text: title, textStyle: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold)),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: max,
          ranges: <GaugeRange>[
            GaugeRange(startValue: ranges[0], endValue: ranges[1], color: Colors.green),
            GaugeRange(startValue: ranges[1], endValue: ranges[2], color: Colors.orange),
            GaugeRange(startValue: ranges[2], endValue: ranges[3], color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: value ?? 0, enableAnimation: true, animationDuration: 300, needleStartWidth: 1, needleEndWidth: 5, knobStyle: const KnobStyle(knobRadius: 0.08)),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: value != null
                  ? Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold))
                  : const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3)),
              angle: 90,
              positionFactor: 0.5,
            )
          ],
        ),
      ],
    );
  }

   Widget _buildCoolantGauge(double? temp) {
    return Column(
      children: [
        Text(
          temp != null ? 'Temp. do Motor: ${temp.toStringAsFixed(1)}°C' : 'Lendo temperatura...',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SfLinearGauge(
          orientation: LinearGaugeOrientation.horizontal,
          minimum: -20,
          maximum: 120,
          axisLabelStyle: const TextStyle(fontSize: 12),
          markerPointers: [if (temp != null) LinearShapePointer(value: temp, animationDuration: 200)],
          barPointers: [
            if (temp != null)
              LinearBarPointer(
                value: temp,
                animationDuration: 200,
                shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
                    stops: [0.25, 0.5, 0.75, 1.0]).createShader(bounds),
              ),
          ],
        ),
      ],
    );
  }
}
