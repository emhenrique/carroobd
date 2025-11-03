
# Blueprint: Aplicativo Scanner OBD2 ELM327

## Visão Geral

Este documento descreve o plano de desenvolvimento para um aplicativo Flutter projetado para se conectar a scanners OBD2 ELM327 via Bluetooth. O aplicativo permitirá que os usuários visualizem dados de diagnóstico do veículo em tempo real.

## Design e Estilo

- **Tema:** Moderno, utilizando Material 3.
- **Cores:** Um esquema de cores primário baseado em azul escuro, com detalhes em ciano para realçar a interatividade. Suporte completo para modos claro e escuro (Light/Dark).
- **Tipografia:** Uso do pacote `google_fonts` com a fonte "Roboto" para garantir uma leitura clara e consistente.
- **Layout:** Interface limpa e intuitiva. A tela principal listará os dispositivos Bluetooth encontrados, e uma tela de detalhes mostrará os dados do veículo após a conexão.
- **Iconografia:** Ícones do Material Design para ações como "Scan," "Connect," "Disconnect," e indicadores de status.

## Funcionalidades Planejadas

1.  **Scanner de Dispositivos Bluetooth:**
    -   Verificar e solicitar permissões de Bluetooth.
    -   Listar dispositivos pareados e disponíveis.
    -   Exibir nome e endereço dos dispositivos.

2.  **Conexão com o Dispositivo:**
    -   Permitir que o usuário selecione um dispositivo ELM327 da lista.
    -   Estabelecer e gerenciar uma conexão serial Bluetooth (SPP).
    -   Fornecer feedback visual sobre o status da conexão (conectando, conectado, erro, desconectado).

3.  **Tela de Diagnóstico (Pós-conexão):**
    -   Enviar comandos OBD2 básicos (ex: "ATZ" para reset, "010C" para RPM).
    -   Receber, analisar e exibir as respostas do scanner.
    -   Interface para exibir dados como RPM do motor, velocidade do veículo, temperatura do líquido de arrefecimento, etc.

## Plano de Implementação Atual

**Etapa 1: Estrutura Inicial e Dependências**

-   [x] **Criar `blueprint.md`:** Documentar o plano do projeto.
-   [ ] **Adicionar Dependências:** Instalar os pacotes necessários:
    -   `flutter_bluetooth_serial`: Para comunicação Bluetooth com o ELM327.
    -   `provider`: Para gerenciamento de estado da conexão.
    -   `google_fonts`: Para a tipografia customizada.
-   [ ] **Configurar `main.dart`:**
    -   Implementar a estrutura básica do `MaterialApp`.
    -   Configurar o `ThemeProvider` para alternar entre os modos claro e escuro.
    -   Definir os temas (light e dark) com `ColorScheme.fromSeed` e `google_fonts`.
-   [ ] **Configurar Permissões (Android):**
    -   Adicionar as permissões `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` e `ACCESS_FINE_LOCATION` ao `AndroidManifest.xml`.
