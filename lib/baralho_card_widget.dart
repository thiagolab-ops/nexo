import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart';

class BaralhoCardWidget extends StatefulWidget {
  final Baralho baralho;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const BaralhoCardWidget({
    super.key,
    required this.baralho,
    required this.onTap,
    required this.onPlay,
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Título do baralho
                        Expanded(
                          child: Text(widget.baralho.nome, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        // Ícones de Ofensiva e Jogo
                        Row(
                          children: [
                            if (widget.baralho.ofensiva > 0)
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.baralho.ofensiva.toString(),
                                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                              ),
                            IconButton(
                              icon: const Icon(Icons.videogame_asset_outlined, color: Colors.white, size: 30),
                              tooltip: 'Jogar',
                              onPressed: widget.onPlay,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // <<< MUDANÇA: BARRA DE PROGRESSO E TEXTO >>>
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: widget.baralho.progresso,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightGreenAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(widget.baralho.progresso * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
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
