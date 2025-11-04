
# Blueprint: Aplicativo Scanner OBD2 ELM327

## Visão Geral

Este documento descreve o plano de desenvolvimento para um aplicativo Flutter projetado para se conectar a scanners OBD2 ELM327 via Bluetooth. O aplicativo permite que os usuários visualizem dados de diagnóstico do veículo em tempo real e leiam/apaguem códigos de falha (DTCs).

## Design e Estilo

- **Tema:** Moderno, utilizando Material 3, com suporte para modos claro e escuro.
- **Cores:** Esquema de cores primário baseado em Ciano para um visual tecnológico e limpo.
- **Tipografia:** Uso do pacote `google_fonts` com a fonte "Roboto" para garantir uma leitura clara e consistente em todas as telas.
- **Layout:** Interface limpa e intuitiva. A navegação principal é feita por uma `BottomNavigationBar`, separando as funcionalidades principais de forma clara.
- **Iconografia:** Ícones consistentes do Material Design para ações e indicadores de status.
- **Componentes:** Uso de componentes avançados como `syncfusion_flutter_gauges` para uma visualização de dados rica e animada.

## Funcionalidades Implementadas

- **Gerenciamento de Estado Centralizado:**
    - Utiliza o pacote `provider` com um `ChangeNotifier` (`OBD2Provider`) para gerenciar todo o estado da aplicação de forma centralizada, reativa e desacoplada.

- **Conexão e Descoberta de Dispositivos:**
    - **Verificação de Status:** Verifica ativamente se o Bluetooth do dispositivo está ligado e se as permissões necessárias foram concedidas.
    - **UI Guiada:** Fornece telas informativas e botões de ação para guiar o usuário a ativar o Bluetooth ou conceder permissões.
    - **Scanner Inteligente:** Escaneia dispositivos Bluetooth, identificando e destacando visualmente prováveis scanners OBD2.
    - **Gerenciamento de Conexão:** Conecta, inicializa a comunicação com o scanner (comandos AT) e gerencia o ciclo de vida da conexão, incluindo desconexão e limpeza de recursos.
    - **Navegação Automática:** Navega para o painel principal após a conexão bem-sucedida e retorna à tela de busca em caso de desconexão.

- **Painel de Dados em Tempo Real:**
    - **Polling Eficiente:** Realiza um polling sequencial e contínuo dos sensores (RPM, Velocidade, Temp. do Motor) para manter os dados atualizados.
    - **Visualização Rica:** Exibe os dados em medidores radiais e lineares animados, fornecendo uma leitura rápida e visualmente agradável.
    - **Feedback de Carregamento:** Exibe um `CircularProgressIndicator` nos medidores enquanto os dados iniciais estão sendo carregados, melhorando a percepção do usuário.

- **Diagnóstico de Códigos de Falha (DTC):**
    - **Leitura de Códigos:** Permite ao usuário solicitar a leitura dos códigos de falha armazenados na ECU do veículo (Modo 03).
    - **Limpeza de Códigos:** Permite ao usuário limpar os códigos de falha e apagar a luz de "Check Engine" (Modo 04), com uma caixa de diálogo de confirmação para segurança.
    - **Feedback de Ação:** Exibe indicadores de progresso claros durante a leitura e a limpeza dos códigos.
    - **Tradução de Códigos:** Inclui um dicionário (`dtc_descriptions.dart`) que traduz os códigos hexadecimais (ex: P0420) para descrições em português, tornando o diagnóstico compreensível para o usuário final.
    - **Gerenciamento Inteligente de Polling:** Pausa automaticamente o polling de sensores ao entrar na tela de DTC para evitar conflitos de comunicação no barramento OBD2 e o retoma ao voltar para o painel.

## Plano de Implementação Futuro

- A funcionalidade principal foi concluída e polida. O projeto está em um estado estável e completo.
- Ideias para futuras versões podem incluir:
    - Suporte a mais PIDs (Sensores) de OBD2.
    - Gráficos históricos dos dados dos sensores.
    - Salvamento e exportação de relatórios de DTC.
