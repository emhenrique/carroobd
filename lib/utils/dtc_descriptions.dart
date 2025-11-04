
// Um mapa de exemplo com descrições de alguns DTCs comuns.
// Em um aplicativo real, isso poderia vir de um banco de dados ou de um arquivo JSON muito maior.

const Map<String, String> dtcDescriptionMap = {
  'P0101': 'Sensor de Massa de Ar (MAF) - Problema de Faixa/Desempenho',
  'P0102': 'Sensor de Massa de Ar (MAF) - Entrada Baixa',
  'P0113': 'Sensor de Temperatura do Ar de Admissão (IAT) - Entrada Alta',
  'P0128': 'Termostato do Líquido de Arrefecimento - Temperatura Abaixo da Regulamentação',
  'P0135': 'Sensor de O2 (Banco 1, Sensor 1) - Mau Funcionamento do Circuito do Aquecedor',
  'P0171': 'Sistema Muito Pobre (Banco 1)',
  'P0300': 'Falha de Ignição Aleatória/Múltiplos Cilindros Detectada',
  'P0301': 'Falha de Ignição no Cilindro 1 Detectada',
  'P0302': 'Falha de Ignição no Cilindro 2 Detectada',
  'P0420': 'Eficiência do Sistema de Catalisador Abaixo do Limite (Banco 1)',
  'P0442': 'Sistema de Controle de Emissões Evaporativas (EVAP) - Fuga Pequena Detectada',
  'P0500': 'Sensor de Velocidade do Veículo (VSS) - Mau Funcionamento',
};
