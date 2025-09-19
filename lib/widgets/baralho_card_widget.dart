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
    // --- INÍCIO DA CORREÇÃO DE TEMA ---
    // 1. Verificamos manualmente qual é o tema atual
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 2. Criamos estilos de texto explícitos baseados no tema
    final TextStyle? titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: isDarkMode ? Colors.white : Colors.black87, // Texto branco no escuro, preto no claro
    );
    
    final TextStyle? descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isDarkMode ? Colors.grey[400] : Colors.grey[700], // Cores de subtítulo apropriadas
    );
    // --- FIM DA CORREÇÃO ---

    return Card(
      elevation: 4,
      // A cor do Card (branco no claro, cinza-escuro no escuro) vem do nexo_theme.dart e está correta.
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
                style: titleStyle, // 3. Aplicamos o estilo explícito
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
                    style: descriptionStyle, // 4. Aplicamos o estilo explícito
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: onShare,
                    tooltip: 'Compartilhar no Hub',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: onDelete,
                    tooltip: 'Excluir Baralho',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                    tooltip: 'Editar Nome',
                  ),
                  ElevatedButton(
                    onPressed: onPlay,
                    child: const Icon(Icons.play_arrow),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
