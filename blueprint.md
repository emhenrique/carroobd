# Blueprint do Projeto: OBD2 Pro

Este documento serve como a fonte central de verdade para o aplicativo Flutter OBD2 Pro, detalhando sua arquitetura, recursos implementados e o plano de desenvolvimento futuro.

## 1. Visão Geral do Aplicativo

O OBD2 Pro é um aplicativo de diagnóstico automotivo móvel que se conecta a um adaptador ELM327 via Bluetooth. Ele permite que os usuários monitorem dados de sensores do veículo em tempo real, leiam e limpem códigos de falha (DTCs), e visualizem informações importantes sobre o desempenho do motor em uma interface moderna e intuitiva.

## 2. Detalhes da Correção Atual: Resolução do Problema de Atualização em Tempo Real

Esta seção detalha as modificações realizadas para corrigir a falha na exibição em tempo real dos dados de velocidade e temperatura do líquido de arrefecimento.

- **Problema Identificado:** A implementação anterior enviava comandos OBD2 sequencialmente e criava um novo *listener* para cada comando. Essa abordagem se mostrou instável, levando à perda de respostas do adaptador ELM327 e, consequentemente, à não atualização dos dados na interface. A comunicação falhava porque não havia um mecanismo centralizado para gerenciar a fila de comandos e o processamento das respostas.

- **Solução Implementada:** A comunicação com o adaptador foi completamente refatorada no `OBD2Provider` para garantir robustez e confiabilidade.
    1.  **Fila de Comandos (`Queue`):** Foi introduzida uma fila (`Queue<_CommandRequest>`) para gerenciar todos os comandos enviados ao adaptador. Isso garante que os comandos sejam processados de forma organizada (FIFO - First-In, First-Out) e evita conflitos.
    2.  **Processador de Resposta Centralizado:** A lógica de escuta de dados (`_onDataReceived`) foi unificada. Agora, um único *buffer* (`_responseBuffer`) acumula os dados recebidos até que o caractere terminador `>` seja encontrado, indicando o fim de uma resposta. Isso resolve o problema de respostas fragmentadas e garante que cada resposta seja processada corretamente.
    3.  **Gerenciamento de Estado do Comando:** Um *flag* (`_isProcessingCommand`) foi adicionado para garantir que apenas um comando seja enviado e processado por vez, prevenindo condições de corrida.
    4.  **Polling Sincronizado:** O método `startSensorPolling` foi otimizado para enfileirar todas as solicitações de sensores (RPM, velocidade, temperatura) de uma vez e usar `Future.wait` para aguardar todas as respostas. A interface do usuário só é notificada (`notifyListeners()`) após a chegada de todos os dados, garantindo uma atualização de tela consistente e sincronizada.
    5.  **Melhoria na Robustez:** Foram adicionados mais logs de desenvolvimento e um tratamento de *timeout* mais eficaz, que remove um comando da fila se ele não for respondido a tempo, evitando que toda a comunicação fique travada.

## 3. Recursos Implementados

A aplicação possui a seguinte funcionalidade principal, construída sobre uma arquitetura reativa usando o `provider` para gerenciamento de estado.

- **Conectividade Bluetooth Low Energy (BLE):**
    - **Busca de Dispositivos:** Escaneia e exibe dispositivos BLE disponíveis.
    - **Gerenciamento de Conexão:** Estabelece e encerra a conexão com o adaptador ELM327 selecionado.
    - **Monitoramento de Estado:** A interface reage dinamicamente a mudanças no estado da conexão (conectando, conectado, desconectado).

- **Comunicação e Inicialização OBD2:**
    - **Comunicação Robusta com Fila:** Utiliza uma fila de comandos para gerenciar a comunicação com o adaptador ELM327 de forma sequencial e confiável, prevenindo perda de dados.
    - **Sequência de Inicialização:** Envia uma série de comandos AT (`ATZ`, `ATE0`, `ATL0`, `ATSP0`) para configurar o adaptador para comunicação com a ECU do veículo.

- **Diagnóstico de Códigos de Falha (DTCs):**
    - **Leitura de DTCs:** Envia o comando para solicitar os códigos de falha armazenados e decodifica a resposta.
    - **Limpeza de DTCs:** Envia o comando para apagar os códigos de falha e a luz de "Verificar Motor".
    - **Interface Dedicada:** Apresenta os códigos de falha em uma tela separada com feedback claro para o usuário.

- **Painel de Dados em Tempo Real:**
    - **Polling Eficiente e Sincronizado:** Realiza um polling contínuo dos sensores (RPM, Velocidade, Temp. do Motor), aguardando a resposta de todos antes de atualizar a interface para garantir consistência.
    - **Visualização Rica:** Exibe os dados em medidores radiais e lineares animados, fornecendo uma leitura rápida e visualmente agradável.

- **Overlay de Temperatura:**
    - **Permissões:** Solicita permissão para exibir um overlay na tela.
    - **Funcionalidade:** Exibe a temperatura do líquido de arrefecimento em uma janela flutuante, permitindo o monitoramento mesmo com o app em segundo plano.

## 4. Plano de Desenvolvimento (Próximos Passos)

1.  **Melhorar a Interface do Usuário (UI/UX) do Painel:**
    - Refinar o layout, adicionar iconografia e animações para uma aparência mais profissional.
    - Implementar um seletor de tema (claro/escuro).

2.  **Expandir Suporte a Sensores:**
    - Adicionar suporte para mais PIDs (Parameter IDs) e permitir que o usuário personalize o painel.

3.  **Aprimorar a Tela de DTCs:**
    - Integrar um banco de dados para fornecer descrições detalhadas para cada código de falha.

4.  **Adicionar Testes Unitários e de Widgets:**
    - Criar testes para a lógica no `OBD2Provider` e para os principais widgets da UI.
