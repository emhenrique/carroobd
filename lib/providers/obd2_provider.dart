
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:myapp/services/obd2_service.dart';
import 'package:myapp/utils/obd_constants.dart';

class OBD2Provider with ChangeNotifier {
  final OBD2Service _obd2Service = OBD2Service();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  // Estado da Conexão e Inicialização
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isConnecting = false;
  bool _isInitializing = false;
  String _initializationStatus = '';

  // Sensores
  double? _rpm;
  double? _speed;
  double? _coolantTemp;
  Timer? _sensorPollingTimer;

  // DTCs (Códigos de Falha)
  List<DTC> _dtcList = [];
  bool _isReadingDtcs = false;
  bool _isClearingDtcs = false;

  // Getters Públicos
  BluetoothDevice? get device => _device;
  BluetoothConnectionState get connectionState => _connectionState;
  bool get isConnecting => _isConnecting;
  bool get isInitializing => _isInitializing;
  String get initializationStatus => _initializationStatus;

  double? get rpm => _rpm;
  double? get speed => _speed;
  double? get coolantTemp => _coolantTemp;

  List<DTC> get dtcList => _dtcList;
  bool get isReadingDtcs => _isReadingDtcs;
  bool get isClearingDtcs => _isClearingDtcs;

  // Lógica de Conexão e Desconexão

  Future<void> connect(BluetoothDevice device) async {
    if (_isConnecting) return;

    _isConnecting = true;
    _device = device;
    notifyListeners();

    try {
      _connectionSubscription = device.connectionState.listen((state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          _resetAllState();
        }
        notifyListeners();
      });

      await device.connect(autoConnect: false, license: null);
      if (_connectionState == BluetoothConnectionState.connected) {
        await _discoverServices(device);
      }
    } catch (e) {
      developer.log('Erro ao conectar: $e', name: 'OBD2Provider');
      disconnect();
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _sensorPollingTimer?.cancel();
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    await _device?.disconnect();
    await FlutterOverlayWindow.closeOverlay();
    _resetAllState();
  }

  void _resetAllState() {
    _device = null;
    _writeCharacteristic = null;
    _dataSubscription = null;
    _connectionSubscription = null;
    _sensorPollingTimer = null;
    _connectionState = BluetoothConnectionState.disconnected;
    _isConnecting = false;
    _isInitializing = false;
    _rpm = null;
    _speed = null;
    _coolantTemp = null;
    _dtcList = [];
    _isReadingDtcs = false;
    _isClearingDtcs = false;
    notifyListeners();
  }

  // Lógica de Serviços e Características

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write && char.properties.notify) {
            _writeCharacteristic = char;
            await char.setNotifyValue(true);
            _dataSubscription = char.lastValueStream.listen(_onDataReceived, onError: _onStreamError);
            _startInitializationSequence();
            return;
          }
        }
      }
    } catch (e) {
      developer.log("Erro ao descobrir serviços: $e", name: 'OBD2Provider');
      await disconnect();
    }
  }

  void _onDataReceived(List<int> data) {
    final response = utf8.decode(data, allowMalformed: true).trim();
    developer.log("Dados Recebidos: $response", name: "OBD2Provider");
  }

  void _onStreamError(dynamic error) {
    developer.log("Erro no Stream de Dados: $error", name: 'OBD2Provider');
    disconnect();
  }

  // Sequência de Inicialização do OBD2

  Future<void> _startInitializationSequence() async {
    _isInitializing = true;
    notifyListeners();

    final initCommands = {
      ATCommands.reset: "Resetando ELM327...",
      ATCommands.echoOff: "Desligando eco...",
      ATCommands.linefeedsOff: "Desligando linefeeds...",
      ATCommands.setProtocolAuto: "Configurando protocolo automático...",
    };

    for (var command in initCommands.entries) {
      _initializationStatus = command.value;
      notifyListeners();
      final response = await _sendCommand(command.key);
      if (!response.contains('OK')) {
        developer.log("Falha na inicialização no comando '${command.key}'", name: "OBD2Provider");
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _initializationStatus = 'Inicialização completa!';
    _isInitializing = false;
    notifyListeners();
    startSensorPolling();
  }

  // Lógica de Comandos e Polling

  Future<String> _sendCommand(String command, {Duration timeout = const Duration(seconds: 3)}) async {
    if (_writeCharacteristic == null || _connectionState != BluetoothConnectionState.connected) {
      return "";
    }

    final completer = Completer<String>();
    StreamSubscription<List<int>>? subscription;

    subscription = _writeCharacteristic!.lastValueStream.listen((data) {
      final response = utf8.decode(data, allowMalformed: true).trim();
      if (response.endsWith('>')) {
        if (!completer.isCompleted) {
          completer.complete(response.replaceAll('>', '').trim());
          subscription?.cancel();
        }
      }
    });

    await _writeCharacteristic!.write(utf8.encode('$command\r'));

    return completer.future.timeout(timeout, onTimeout: () {
      subscription?.cancel();
      return "TIMEOUT";
    });
  }
  
  void startSensorPolling() {
    _sensorPollingTimer?.cancel();
    _sensorPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_connectionState == BluetoothConnectionState.connected && !_isInitializing) {
        _rpm = _obd2Service.parseSensorResponse(await _sendCommand('${OBDModes.showCurrentData} ${PIDs.engineRPM}'));
        _speed = _obd2Service.parseSensorResponse(await _sendCommand('${OBDModes.showCurrentData} ${PIDs.vehicleSpeed}'));
        _coolantTemp = _obd2Service.parseSensorResponse(await _sendCommand('${OBDModes.showCurrentData} ${PIDs.engineCoolantTemp}'));
        notifyListeners();

        if (await FlutterOverlayWindow.isActive() ?? false) {
          FlutterOverlayWindow.shareData(_coolantTemp?.toStringAsFixed(1) ?? "--");
        }
      }
    });
  }

  void stopSensorPolling() {
    _sensorPollingTimer?.cancel();
  }
  
  // Lógica de DTC
  Future<void> readDTCs() async {
    if(_isReadingDtcs) return;
    stopSensorPolling();
    _isReadingDtcs = true;
    notifyListeners();

    final response = await _sendCommand(OBDModes.showDTCs, timeout: const Duration(seconds: 10));
    _dtcList = _obd2Service.parseDtcResponse(response);

    _isReadingDtcs = false;
    notifyListeners();
  }
  
  Future<void> clearDTCs() async {
     if(_isClearingDtcs) return;
    stopSensorPolling();
    _isClearingDtcs = true;
    notifyListeners();
    
    await _sendCommand(OBDModes.clearDTCs, timeout: const Duration(seconds: 5));
    _dtcList.clear();
    
    _isClearingDtcs = false;
    notifyListeners();

    readDTCs();
  }
}
