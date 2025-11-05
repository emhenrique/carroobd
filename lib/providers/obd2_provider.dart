
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:myapp/services/obd2_service.dart';
import 'package:myapp/utils/obd_constants.dart';

// Estrutura para agrupar comando e seu completer
class _CommandRequest {
  final String command;
  final Completer<String> completer;

  _CommandRequest(this.command, this.completer);
}

class OBD2Provider with ChangeNotifier {
  final OBD2Service _obd2Service = OBD2Service();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  // Fila para gerenciar os comandos OBD2 de forma sequencial
  final Queue<_CommandRequest> _commandQueue = Queue();
  bool _isProcessingCommand = false;
  String _responseBuffer = '';

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
    if (_isConnecting || _connectionState == BluetoothConnectionState.connected) return;

    _isConnecting = true;
    _device = device;
    notifyListeners();

    try {
      _connectionSubscription = device.connectionState.listen((state) {
        _connectionState = state;
         developer.log('Connection State: $state', name: 'OBD2Provider');
        if (state == BluetoothConnectionState.disconnected) {
          _resetAllState();
        }
        notifyListeners();
      });

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      
      if (device.isConnected) {
         developer.log('Device connected successfully', name: 'OBD2Provider');
        await _discoverServices(device);
      } else {
        developer.log('Failed to connect to device', name: 'OBD2Provider');
        await disconnect();
      }

    } catch (e) {
      developer.log('Erro ao conectar: $e', name: 'OBD2Provider');
      await disconnect();
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _sensorPollingTimer?.cancel();
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    // Não chame _device?.disconnect() diretamente aqui para evitar loop se a desconexão já ocorreu
    if(_device?.isConnected ?? false){
        await _device?.disconnect();
    }
    await FlutterOverlayWindow.closeOverlay();
    _resetAllState();
  }

  void _resetAllState() {
    _device = null;
    _writeCharacteristic = null;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _sensorPollingTimer?.cancel();
    _sensorPollingTimer = null;
    _commandQueue.clear();
    _isProcessingCommand = false;
    _responseBuffer = '';
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
        // Tenta encontrar uma característica ideal (Notify e Write)
        for (var char in service.characteristics) {
          if (char.properties.write && char.properties.notify) {
             developer.log('Found optimal characteristic: ${char.uuid}', name: 'OBD2Provider');
            _writeCharacteristic = char;
            await _setupDataListener(char);
            _startInitializationSequence();
            return;
          }
        }
      }
       developer.log('Nenhuma característica ideal encontrada. Procurando por alternativas.', name: 'OBD2Provider');
       // Fallback: Procura por características de escrita e notificação separadas se necessário
      // (Implementação de fallback omitida para simplicidade, mas seria aqui)

    } catch (e) {
      developer.log("Erro ao descobrir serviços: $e", name: 'OBD2Provider');
      await disconnect();
    }
  }

  Future<void> _setupDataListener(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    _dataSubscription = characteristic.lastValueStream.listen(_onDataReceived, onError: _onStreamError);
     developer.log('Data listener setup complete for ${characteristic.uuid}', name: 'OBD2Provider');
  }

  void _onDataReceived(List<int> data) {
    // Acumula a resposta
    _responseBuffer += utf8.decode(data, allowMalformed: true);
    
    // O caractere '>' indica o fim de uma resposta do ELM327
    if (_responseBuffer.contains('>')) {
      // Processa todas as respostas completas no buffer
      while(_responseBuffer.contains('>')) {
        final endOfResponse = _responseBuffer.indexOf('>');
        final response = _responseBuffer.substring(0, endOfResponse).trim();
        
        developer.log("Response Processed: $response", name: "OBD2Provider");

        if (_commandQueue.isNotEmpty) {
          final request = _commandQueue.first;
          if (!request.completer.isCompleted) {
            request.completer.complete(response);
          }
        }
        
        // Remove a resposta processada (e o '>') do buffer
        _responseBuffer = _responseBuffer.substring(endOfResponse + 1);
      }
      
      // Após processar a resposta, podemos estar prontos para o próximo comando
      _isProcessingCommand = false;
      _processCommandQueue();
    }
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
      if (!response.contains('OK') && !response.contains('ELM327')) { // A resposta do reset pode ser a versão
        developer.log("Falha na inicialização no comando '${command.key}'. Resposta: $response", name: "OBD2Provider");
        // Opcional: Adicionar lógica para parar a inicialização em caso de falha
      }
      await Future.delayed(const Duration(milliseconds: 100)); // Pequeno delay entre comandos
    }

    _initializationStatus = 'Inicialização completa!';
    _isInitializing = false;
    notifyListeners();
    startSensorPolling();
  }

  // Lógica de Comandos, Fila e Polling

  Future<String> _sendCommand(String command, {Duration timeout = const Duration(seconds: 5)}) async {
      if (_writeCharacteristic == null || _connectionState != BluetoothConnectionState.connected) {
      developer.log("Tentativa de enviar comando sem conexão ou característica.", name: 'OBD2Provider');
      return "ERROR: NOT CONNECTED";
    }

    final completer = Completer<String>();
    _commandQueue.add(_CommandRequest(command, completer));
    _processCommandQueue();

    return completer.future.timeout(timeout, onTimeout: () {
      developer.log('TIMEOUT para o comando: $command', name: 'OBD2Provider');
      // Remove o comando da fila em caso de timeout para não travar
      if(_commandQueue.isNotEmpty && _commandQueue.first.command == command) {
          _commandQueue.removeFirst();
          _isProcessingCommand = false;
      }
      return "TIMEOUT";
    });
  }

  void _processCommandQueue() async {
    if (_isProcessingCommand || _commandQueue.isEmpty || _writeCharacteristic == null) {
      return;
    }

    _isProcessingCommand = true;
    final request = _commandQueue.first;
    
    developer.log("Enviando Comando: ${request.command}", name: "OBD2Provider");
    
    try {
        await _writeCharacteristic!.write(utf8.encode('${request.command}\r'));
        // A lógica de conclusão agora está em _onDataReceived
    } catch (e) {
        developer.log("Erro ao escrever no característico: $e", name: "OBD2Provider");
        if (!request.completer.isCompleted) {
            request.completer.complete("ERROR: WRITE FAILED");
        }
        _isProcessingCommand = false;
        _commandQueue.removeFirst(); // Remove o comando que falhou
    }
  }
  
  void startSensorPolling() {
    _sensorPollingTimer?.cancel();
    _sensorPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_connectionState == BluetoothConnectionState.connected && !_isInitializing && !_isReadingDtcs) {
        // Enfileira os comandos dos sensores
        final rpmResponseFuture = _sendCommand('${OBDModes.showCurrentData} ${PIDs.engineRPM}');
        final speedResponseFuture = _sendCommand('${OBDModes.showCurrentData} ${PIDs.vehicleSpeed}');
        final coolantResponseFuture = _sendCommand('${OBDModes.showCurrentData} ${PIDs.engineCoolantTemp}');
        
        // Espera todas as respostas e então atualiza a UI
        final responses = await Future.wait([rpmResponseFuture, speedResponseFuture, coolantResponseFuture]);

        _rpm = _obd2Service.parseSensorResponse(responses[0]);
        _speed = _obd2Service.parseSensorResponse(responses[1]);
        _coolantTemp = _obd2Service.parseSensorResponse(responses[2]);

        notifyListeners();

        if (await FlutterOverlayWindow.isActive()) {
          FlutterOverlayWindow.shareData(_coolantTemp?.toStringAsFixed(1) ?? "--");
        }
      }
    });
  }

  void stopSensorPolling() {
    _sensorPollingTimer?.cancel();
    _sensorPollingTimer = null;
  }
  
  // Lógica de DTC
  Future<void> readDTCs() async {
    if(_isReadingDtcs) return;
    stopSensorPolling(); // Pausa a leitura dos sensores
    _isReadingDtcs = true;
    notifyListeners();

    try {
      final response = await _sendCommand(OBDModes.showDTCs, timeout: const Duration(seconds: 15));
      _dtcList = _obd2Service.parseDtcResponse(response);
    } catch (e) {
      developer.log("Erro ao ler DTCs: $e", name: "OBD2Provider");
    } finally {
      _isReadingDtcs = false;
      notifyListeners();
      startSensorPolling(); // Retoma a leitura dos sensores
    }
  }
  
  Future<void> clearDTCs() async {
     if(_isClearingDtcs) return;
    stopSensorPolling();
    _isClearingDtcs = true;
    notifyListeners();
    
    try {
      await _sendCommand(OBDModes.clearDTCs, timeout: const Duration(seconds: 10));
      _dtcList.clear(); // Limpa a lista localmente
    } catch (e) {
        developer.log("Erro ao limpar DTCs: $e", name: "OBD2Provider");
    } finally {
      _isClearingDtcs = false;
      notifyListeners();
      await readDTCs(); // Relê os códigos para confirmar a limpeza
    }
  }
}
