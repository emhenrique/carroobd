
import 'package:flutter/material.dart';
import 'package:myapp/providers/obd2_provider.dart';
import 'package:myapp/services/obd2_service.dart'; // Importação adicionada
import 'package:provider/provider.dart';

class DtcScreen extends StatelessWidget {
  const DtcScreen({super.key});

  Future<void> _showClearConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // O usuário deve tocar em um botão
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Limpeza de Códigos'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Você tem certeza que deseja limpar todos os códigos de falha?'),
                SizedBox(height: 8),
                Text('Esta ação não pode ser desfeita.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: const Text('Limpar Códigos'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<OBD2Provider>().clearDTCs();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OBD2Provider>();
    final dtcList = provider.dtcList;

    return Scaffold(
      body: _buildBody(context, provider, dtcList),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isReadingDtcs || provider.isClearingDtcs
            ? null
            : () => provider.readDTCs(),
        label: const Text('Ler Códigos'),
        icon: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, OBD2Provider provider, List<DTC> dtcList) {
    if (provider.isReadingDtcs) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Lendo códigos de falha..."),
          ],
        ),
      );
    }

    if (provider.isClearingDtcs) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Limpando códigos..."),
          ],
        ),
      );
    }

    if (dtcList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text("Nenhum Código de Falha Encontrado",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text("O sistema de diagnóstico do veículo não reportou erros.",
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showClearConfirmation(context),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Limpar Todos os Códigos de Falha"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: dtcList.length,
            itemBuilder: (context, index) {
              final dtc = dtcList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(dtc.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(dtc.description, style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
