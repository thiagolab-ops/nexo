import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/models.dart';

class BaralhoCardWidget extends StatefulWidget {
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
  State<BaralhoCardWidget> createState() => _BaralhoCardWidgetState();
}

class _BaralhoCardWidgetState extends State<BaralhoCardWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                color: _isHovering ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.15),
                border: Border.all(
                  color: _isHovering ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.baralho.nome, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white70),
                          tooltip: 'Compartilhar no Hub',
                          onPressed: widget.onShare,
                        ),
                        IconButton(
                          icon: const Icon(Icons.videogame_asset_outlined, color: Colors.white),
                          tooltip: 'Jogar',
                          onPressed: widget.onPlay,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') widget.onEdit();
                            if (value == 'delete') widget.onDelete();
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Editar Nome'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Excluir Baralho'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
