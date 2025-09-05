import 'package:flutter/material.dart';
import 'package:nexo/services/report_service.dart';
import '../models/models.dart';
import 'package:timeago/timeago.dart' as timeago;

class TelaModeracao extends StatefulWidget {
  const TelaModeracao({super.key});

  @override
  State<TelaModeracao> createState() => _TelaModeracaoState();
}

class _TelaModeracaoState extends State<TelaModeracao> {
  final ReportService _reportService = ReportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderação de Denúncias'),
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: _reportService.getReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar denúncias: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Nenhuma denúncia pendente. Bom trabalho!'),
            );
          }

          final reports = snapshot.data!;

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Denúncia: ${report.reason}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildReportInfo('Tipo de Conteúdo:', report.contentType),
                      _buildReportInfo('ID do Conteúdo:', report.contentId, selectable: true),
                      _buildReportInfo('Usuário Denunciado:', report.reportedUserId, selectable: true),
                      _buildReportInfo('Denunciado Por:', report.reporterId, selectable: true),
                      _buildReportInfo('Data:', timeago.format(report.createdAt.toDate(), locale: 'pt_BR')),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Ignorar', style: TextStyle(color: Colors.grey)),
                            onPressed: () {
                              _reportService.updateReportStatus(report.id, 'dismissed');
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            child: const Text('Tomar Ação'),
                            onPressed: () {
                              // TODO: Implementar lógica de ação (ex: deletar post, banir usuário)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ação ainda não implementada.')),
                              );
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReportInfo(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: selectable
                ? SelectableText(value, style: const TextStyle(fontFamily: 'monospace'))
                : Text(value),
          ),
        ],
      ),
    );
  }
}
