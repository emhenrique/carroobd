
// Comandos AT para inicialização e controle do ELM327
class ATCommands {
  static const String reset = "ATZ";
  static const String echoOff = "ATE0";
  static const String linefeedsOff = "ATL0"; 
  static const String setProtocolAuto = "ATSP0";
  static const String describeProtocol = "ATDP";
  static const String headersOn = "ATH1";
}

// PIDs (Parameter IDs) do modo 01 do OBD2 para dados em tempo real
class PIDs {
  static const String engineRPM = "0C";
  static const String vehicleSpeed = "0D";
  static const String engineCoolantTemp = "05";
}

// Modos de Serviço OBD2
class OBDModes {
  static const String showCurrentData = "01";
  static const String showDTCs = "03"; // Diagnostic Trouble Codes
  static const String clearDTCs = "04";
}
