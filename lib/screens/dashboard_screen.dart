
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:myapp/providers/obd2_provider.dart';
import 'package:myapp/screens/dtc_screen.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isActive = await FlutterOverlayWindow.isActive();
      if (mounted) setState(() => _isOverlayActive = isActive);
    });
  }

  Future<void> _toggleOverlay(bool value) async {
    if (value) {
      final hasPermission = await FlutterOverlayWindow.requestPermission();
      if (hasPermission != true) return;
      
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
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildStatusIndicator(context, provider.connectionState),
          const SizedBox(height: 20),
          _buildRpmIndicator(provider.rpm, colorScheme),
          const SizedBox(height: 30),
          _buildLinearIndicator(
            title: 'Velocidade',
            value: provider.speed,
            maxValue: 220,
            unit: 'km/h',
            icon: Icons.speed,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 20),
          _buildLinearIndicator(
            title: 'Temperatura do Motor',
            value: provider.coolantTemp,
            maxValue: 120,
            unit: '°C',
            icon: Icons.thermostat,
            color: Colors.red.shade400,
            linearGradient: const LinearGradient(colors: [Colors.blue, Colors.green, Colors.red]),
          ),
          const SizedBox(height: 20),
          if (Platform.isAndroid) _buildOverlaySwitch(),
        ],
      ),
    );
  }

  Widget _buildRpmIndicator(double? rpm, ColorScheme colorScheme) {
    final percent = (rpm ?? 0) / 8000;
    final progressColor = rpm == null ? Colors.grey.shade300 :
                          percent > 0.75 ? Colors.red.shade600 :
                          percent > 0.5 ? Colors.orange.shade600 : colorScheme.primary;

    return CircularPercentIndicator(
      radius: 120.0,
      lineWidth: 15.0,
      percent: percent.clamp(0.0, 1.0),
      animation: true,
      animationDuration: 300,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rpm?.toStringAsFixed(0) ?? '--',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text("RPM", style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
      progressColor: progressColor,
      backgroundColor: colorScheme.surfaceContainerHighest,
      circularStrokeCap: CircularStrokeCap.round,
    );
  }

  Widget _buildLinearIndicator({
    required String title,
    required double? value,
    required double maxValue,
    required String unit,
    required IconData icon,
    required Color color,
    LinearGradient? linearGradient,
  }) {
    final percent = (value ?? 0) / maxValue;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  value != null ? '${value.toStringAsFixed(0)} $unit' : '-- $unit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              percent: percent.clamp(0.0, 1.0),
              lineHeight: 12.0,
              animation: true,
              animationDuration: 300,
              progressColor: linearGradient == null ? color : null,
              linearGradient: linearGradient,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              barRadius: const Radius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOverlaySwitch(){
    return Card(
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
}
