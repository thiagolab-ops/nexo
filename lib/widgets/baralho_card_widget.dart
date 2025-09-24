import 'package:flutter/material.dart';
import '../models/models.dart';

class BaralhoCardWidget extends StatelessWidget {
  final Baralho baralho;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const BaralhoCardWidget({
    super.key,
    required this.baralho,
    required this.onTap,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final TextStyle? titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: isDarkMode ? Colors.white : Colors.black87,
    );
    
    final TextStyle? descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
    );

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baralho.nome,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (baralho.descricao != null && baralho.descricao!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    baralho.descricao!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: descriptionStyle,
                  ),
                ),
              const Spacer(),
              // --- INÍCIO DA CORREÇÃO DE LAYOUT ---
              // A fileira de botões foi completamente refatorada
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Ação Principal: Botão de Play
                  ElevatedButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Jogar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(width: 8), // Espaçamento
                  // Ações Secundárias: Menu "..."
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'share') onShare();
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'share',
                        child: ListTile(leading: Icon(Icons.share), title: Text('Compartilhar')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                      ),
                    ],
                  ),
                ],
              )
              // --- FIM DA CORREÇÃO ---
            ],
          ),
        ),
      ),
    );
  }
}
