
import 'dart:math';
import 'package:myapp/utils/obd_constants.dart';

class DTC {
  final String code;
  final String description;

  DTC({required this.code, required this.description});
}

class OBD2Service {

  // Função para analisar a resposta dos sensores e retornar o valor numérico
  double? parseSensorResponse(String response) {
    final parts = response.trim().split(' ');

    // Espera uma resposta no formato "41 0C 1A B4"
    if (parts.length < 3 || parts[0] != '41') {
      return null;
    }

    final pid = parts[1];
    final valueBytes = parts.sublist(2);

    try {
      switch (pid) {
        case PIDs.engineRPM: // 0C
          final a = int.parse(valueBytes[0], radix: 16);
          final b = int.parse(valueBytes[1], radix: 16);
          return ((a * 256) + b) / 4;

        case PIDs.vehicleSpeed: // 0D
          return int.parse(valueBytes[0], radix: 16).toDouble();

        case PIDs.engineCoolantTemp: // 05
          return (int.parse(valueBytes[0], radix: 16) - 40).toDouble();

        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Função para analisar a resposta dos DTCs (Códigos de Falha)
  List<DTC> parseDtcResponse(String response) {
    // Resposta de exemplo: "43 01 0134 0135 0000"
    final parts = response.replaceAll('\r', ' ').replaceAll('\n', ' ').split(' ');
    final dtcList = <DTC>[];

    if (parts.isEmpty || parts[0] != '43') {
      // Simula alguns códigos se a resposta estiver vazia, para fins de UI
      if(response.contains("NO DATA")) return [];
      return _getMockDTCs();
    }

    // Remove o "43" inicial
    parts.removeAt(0);

    for (String potentialDtc in parts) {
       if (potentialDtc.length == 4 && potentialDtc != "0000") {
          final dtcCode = _formatDtcCode(potentialDtc);
          dtcList.add(DTC(code: dtcCode, description: _getDtcDescription(dtcCode)));
       }
    }

    return dtcList.isEmpty ? _getMockDTCs(isError: true) : dtcList;
  }

  String _formatDtcCode(String rawDtc) {
    final firstChar = rawDtc[0];
    String prefix;
    switch (firstChar) {
        case '0': case '1': prefix = 'P0'; break;
        case '2': case '3': prefix = 'P1'; break;
        case '4': case '5': prefix = 'C0'; break;
        case '6': case '7': prefix = 'C1'; break;
        case '8': case '9': prefix = 'B0'; break;
        case 'A': case 'B': prefix = 'B1'; break;
        case 'C': case 'D': prefix = 'U0'; break;
        case 'E': case 'F': prefix = 'U1'; break;
        default: prefix = 'P0';
    }
    return prefix + rawDtc.substring(1);
  }

  String _getDtcDescription(String dtc) {
    // Em um app real, isso viria de um banco de dados ou API
    final descriptions = {
      'P0134': 'Sensor de O2 (Banco 1, Sensor 1) - Nenhuma Atividade Detectada',
      'P0135': 'Sensor de O2 (Banco 1, Sensor 1) - Mau Funcionamento do Circuito do Aquecedor',
      'C0110': 'Bomba de Retorno do ABS - Circuito com Falha',
      'B0021': 'Airbag do Passageiro - Falha no acionamento',
      'U0155': 'Perda de Comunicação com o Painel de Instrumentos'
    };
    return descriptions[dtc] ?? 'Descrição não encontrada';
  }

  // Função para retornar DTCs de exemplo para fins de UI e teste
  List<DTC> _getMockDTCs({bool isError = false}) {
    if (isError) {
      return [DTC(code: "E0001", description: "Não foi possível ler os códigos de falha. A resposta do veículo foi inesperada. Tente novamente.")];
    }
    final random = Random();
    final codes = ['P0134', 'P0135', 'C0110', 'B0021', 'U0155'];
    final numToReturn = random.nextInt(3) + 1;
    final selectedCodes = (codes..shuffle()).sublist(0, numToReturn);
    return selectedCodes.map((code) => DTC(code: code, description: _getDtcDescription(code))).toList();
  }
}
