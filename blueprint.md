# Blueprint do Projeto: OBD2 Pro

Este documento serve como a fonte central de verdade para o aplicativo Flutter OBD2 Pro, detalhando sua arquitetura, recursos implementados e o plano de desenvolvimento futuro.

## 1. Visão Geral do Aplicativo

O OBD2 Pro é um aplicativo de diagnóstico automotivo móvel que se conecta a um adaptador ELM327 via Bluetooth. Ele permite que os usuários monitorem dados de sensores do veículo em tempo real, leiam e limpem códigos de falha (DTCs), e visualizem informações importantes sobre o desempenho do motor em uma interface moderna e intuitiva.

## 2. Recursos Implementados

A aplicação atualmente possui a seguinte funcionalidade principal, construída sobre uma arquitetura reativa usando o `provider` para gerenciamento de estado.

- **Conectividade Bluetooth Low Energy (BLE):**
    - **Busca de Dispositivos:** Escaneia e exibe dispositivos BLE disponíveis.
    - **Gerenciamento de Conexão:** Estabelece e encerra a conexão com o adaptador ELM327 selecionado.
    - **Monitoramento de Estado:** A interface reage dinamicamente a mudanças no estado da conexão (conectando, conectado, desconectado).

- **Comunicação e Inicialização OBD2:**
    - **Sequência de Inicialização:** Envia uma série de comandos AT (`ATZ`, `ATE0`, `ATL0`, `ATSP0`) para configurar o adaptador ELM327 para comunicação com a ECU do veículo.
    - **Comunicação Robusta:** Inclui um sistema de envio de comandos com `Completer` e timeouts para garantir que os comandos sejam processados de forma síncrona.

- **Diagnóstico de Códigos de Falha (DTCs):**
    - **Leitura de DTCs:** Envia o comando para solicitar os códigos de falha armazenados e decodifica a resposta.
    - **Limpeza de DTCs:** Envia o comando para apagar os códigos de falha e a luz de "Verificar Motor".
    - **Interface Dedicada:** Apresenta os códigos de falha em uma tela separada com feedback claro para o usuário.

- **Painel de Dados em Tempo Real:**
    - **Polling Eficiente:** Realiza um polling sequencial e contínuo dos sensores (RPM, Velocidade, Temp. do Motor) para manter os dados atualizados.
    - **Visualização Rica:** Exibe os dados em medidores radiais e lineares animados, fornecendo uma leitura rápida e visualmente agradável.
    - **Feedback de Carregamento:** Exibe um `CircularProgressIndicator` nos medidores enquanto os dados iniciais estão sendo carregados, melhorando a percepção do usuário.

- **Overlay de Temperatura:**
    - **Permissões:** Solicita permissão para exibir um overlay na tela.
    - **Funcionalidade:** Exibe a temperatura do líquido de arrefecimento em uma janela flutuante, permitindo o monitoramento mesmo com o app em segundo plano.

## 3. Plano de Desenvolvimento (Próximos Passos)

Com a base do aplicativo estabelecida e os problemas de dependência resolvidos, o foco agora se volta para refinar a experiência do usuário e expandir o conjunto de recursos.

1.  **Melhorar a Interface do Usuário (UI/UX) do Painel:**
    - **Refinar o Layout:** Reorganizar os medidores e adicionar iconografia para uma aparência mais profissional e "ousada".
    - **Adicionar Animações:** Implementar animações de entrada e transições suaves para tornar a interface mais dinâmica.
    - **Tema Escuro/Claro:** Implementar um seletor de tema para permitir que o usuário escolha entre os modos claro e escuro.

2.  **Expandir Suporte a Sensores:**
    - Adicionar suporte para mais PIDs (Parameter IDs) do padrão OBD2, como Posição do Acelerador, Carga do Motor, etc.
    - Criar uma tela de seleção onde o usuário possa escolher quais sensores exibir no painel.

3.  **Aprimorar a Tela de DTCs:**
    - **Banco de Dados de DTCs:** Integrar um banco de dados local ou uma API para fornecer uma descrição detalhada de cada código de falha, em vez de apenas o código.

4.  **Adicionar Testes Unitários e de Widgets:**
    - **Escrever Testes:** Criar testes para a lógica de negócio no `OBD2Provider` (cálculos, parsing de dados) e para os principais widgets da UI para garantir a estabilidade e prevenir regressões.

5.  **Refinar o Tratamento de Erros:**
    - Fornecer feedback mais específico ao usuário em caso de falhas de conexão, timeouts de comando ou respostas inesperadas do adaptador.
