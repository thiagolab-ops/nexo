import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Constantes do Jogo
const int ROWS = 20;
const int COLS = 10;
const double BLOCK_SIZE = 30.0;
const double NEXT_PIECE_BLOCK_SIZE = 20.0;

// Cores para cada tipo de peça (Mantivemos suas cores, são ótimas!)
const List<Color> PIECE_COLORS = [
  Color(0xFF161b22), // Fundo do tabuleiro (Quase preto)
  Color(0xFFFF0D72), // T (Rosa)
  Color(0xFF0DC2FF), // I (Ciano)
  Color(0xFF0DFF72), // O (Verde)
  Color(0xFFF538FF), // L (Magenta)
  Color(0xFFFF8E0D), // J (Laranja)
  Color(0xFFFFE138), // S (Amarelo)
  Color(0xFF3877FF), // Z (Azul)
];

// Formatos das Peças (Tetrominós)
const Map<int, List<List<int>>> PIECES = {
  1: [[0, 1, 0], [1, 1, 1], [0, 0, 0]], // T
  2: [[0, 0, 0, 0], [2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0]], // I
  3: [[3, 3], [3, 3]], // O
  4: [[0, 4, 0], [0, 4, 0], [0, 4, 4]], // L
  5: [[0, 5, 0], [0, 5, 0], [5, 5, 0]], // J
  6: [[0, 6, 6], [6, 6, 0], [0, 0, 0]], // S
  7: [[7, 7, 0], [0, 7, 7], [0, 0, 0]], // Z
};

class Piece {
  Point<int> pos;
  List<List<int>> matrix;

  Piece(this.pos, this.matrix);
}

class NexoBuildScreen extends StatefulWidget {
  const NexoBuildScreen({super.key});

  @override
  State<NexoBuildScreen> createState() => _NexoBuildScreenState();
}

class _NexoBuildScreenState extends State<NexoBuildScreen> {
  late List<List<int>> _board;
  late Piece _currentPlayer;
  late Piece _nextPiece;
  late int _score;
  late bool _isGameOver;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicializa a _nextPiece aqui para evitar null check no build
    _nextPiece = _generateRandomPiece();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Piece _generateRandomPiece() {
    final random = Random();
    final pieceType = random.nextInt(PIECES.length) + 1;
    final newMatrix = PIECES[pieceType]!;
    return Piece(
      Point((COLS / 2 - newMatrix[0].length / 2).floor(), 0),
      newMatrix,
    );
  }

  void _startGame() {
    _board = List.generate(ROWS, (i) => List.generate(COLS, (j) => 0));
    _score = 0;
    _isGameOver = false;
    _spawnPiece(); // Move _nextPiece para _currentPlayer
    _spawnPiece(); // Gera a próxima _nextPiece
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isGameOver) {
        _drop();
      }
    });
    
    setState(() {});
  }

  void _spawnPiece() {
    _currentPlayer = _nextPiece;
    _nextPiece = _generateRandomPiece();

    if (_checkCollision(_currentPlayer)) {
      setState(() {
        _isGameOver = true;
        _timer?.cancel();
      });
    }
  }

  void _drop() {
    setState(() {
      final newPos = Point(_currentPlayer.pos.x, _currentPlayer.pos.y + 1);
      final testPiece = Piece(newPos, _currentPlayer.matrix);
      if (!_checkCollision(testPiece)) {
        _currentPlayer.pos = newPos;
      } else {
        _mergePiece();
        _sweepBoard();
        _spawnPiece();
      }
    });
  }

  void _move(int dir) {
    if (_isGameOver) return;
    setState(() {
      final newPos = Point(_currentPlayer.pos.x + dir, _currentPlayer.pos.y);
      final testPiece = Piece(newPos, _currentPlayer.matrix);
      if (!_checkCollision(testPiece)) {
        _currentPlayer.pos = newPos;
      }
    });
  }

  void _rotate() {
    if (_isGameOver) return;
    final matrix = _currentPlayer.matrix;
    final n = matrix.length;
    final rotated = List.generate(n, (i) => List.generate(n, (j) => 0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        rotated[j][n - 1 - i] = matrix[i][j];
      }
    }
    
    final testPiece = Piece(_currentPlayer.pos, rotated);
    if (!_checkCollision(testPiece)) {
        setState(() => _currentPlayer.matrix = rotated);
    }
  }

  bool _checkCollision(Piece piece) {
    for (int y = 0; y < piece.matrix.length; y++) {
      for (int x = 0; x < piece.matrix[y].length; x++) {
        if (piece.matrix[y][x] != 0) {
          int boardX = piece.pos.x + x;
          int boardY = piece.pos.y + y;
          if (boardX < 0 ||
              boardX >= COLS ||
              boardY >= ROWS ||
              (boardY >= 0 && _board[boardY][boardX] != 0)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _mergePiece() {
    for (int y = 0; y < _currentPlayer.matrix.length; y++) {
      for (int x = 0; x < _currentPlayer.matrix[y].length; x++) {
        if (_currentPlayer.matrix[y][x] != 0) {
          int boardY = _currentPlayer.pos.y + y;
          int boardX = _currentPlayer.pos.x + x;
          if (boardY >= 0 && boardX >= 0) {
              _board[boardY][boardX] = _currentPlayer.matrix[y][x];
          }
        }
      }
    }
  }

  void _sweepBoard() {
    int linesCleared = 0;
    for (int y = ROWS - 1; y >= 0; y--) {
      if (!_board[y].contains(0)) {
        linesCleared++;
        _board.removeAt(y);
        _board.insert(0, List.generate(COLS, (i) => 0));
      }
    }
    if (linesCleared > 0) {
      _score += (linesCleared * 10) * linesCleared;
    }
  }
  
  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16),
          backgroundColor: Theme.of(context).cardColor, // Cor do Tema
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Cor do Tema
      appBar: AppBar(
        title: Text('Nexo Build', style: GoogleFonts.pressStart2p(fontSize: 18)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 650) {
              // Layout para telas verticais (Mobile)
              return _buildVerticalLayout(context);
            } else {
              // Layout para telas horizontais (Tablet/Web)
              return _buildHorizontalLayout(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout(BuildContext context) {
     return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildInfoPanel(context),
        ),
        Expanded(child: _buildGameArea()),
         // Adiciona os controles do lado direito também no modo horizontal
         Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 80.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               _buildControlButton(Icons.rotate_right, _rotate),
               const SizedBox(height: 20),
               _buildControlButton(Icons.arrow_left, () => _move(-1)),
               const SizedBox(height: 20),
               _buildControlButton(Icons.arrow_right, () => _move(1)),
               const SizedBox(height: 20),
               _buildControlButton(Icons.arrow_downward, _drop),
             ],
           ),
         ),
      ],
    );
  }
  
  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      children: [
        _buildInfoPanel(context), // Painel de info no topo
        Expanded(child: _buildGameArea()),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(Icons.arrow_left, () => _move(-1)),
              _buildControlButton(Icons.arrow_right, () => _move(1)),
              _buildControlButton(Icons.arrow_downward, _drop),
              _buildControlButton(Icons.rotate_right, _rotate),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildGameArea() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[700]!, width: 4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          size: const Size(COLS * (BLOCK_SIZE * 0.75), ROWS * (BLOCK_SIZE * 0.75)), // Tamanho adaptável
          painter: GamePainter(
            board: _board,
            currentPlayer: _currentPlayer,
            isGameOver: _isGameOver,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Pontuação
        Container(
          width: 200,
          margin: const EdgeInsets.only(top: 16.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // Cor do Tema
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text('PONTOS', style: GoogleFonts.pressStart2p(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                '$_score',
                style: GoogleFonts.pressStart2p(fontSize: 24, color: Colors.yellow, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Próxima Peça
        Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // Cor do Tema
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text('PRÓXIMA', style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 10),
              CustomPaint(
                size: const Size(4 * NEXT_PIECE_BLOCK_SIZE, 4 * NEXT_PIECE_BLOCK_SIZE),
                painter: NextPiecePainter(piece: _nextPiece),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Botão de Iniciar/Reiniciar
        ElevatedButton.icon(
          onPressed: _startGame,
          icon: const Icon(Icons.refresh),
          label: Text('REINICIAR', style: GoogleFonts.pressStart2p(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            backgroundColor: Theme.of(context).primaryColor, // Cor do Tema
          ),
        ),
      ],
    );
  }
}

// --- CLASSE DO PAINTER (SEM MUDANÇAS DE LÓGICA, APENAS FONTES) ---
class GamePainter extends CustomPainter {
  final List<List<int>> board;
  final Piece currentPlayer;
  final bool isGameOver;

  GamePainter({required this.board, required this.currentPlayer, required this.isGameOver});

  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint();
    final borderPaint = Paint()
      ..color = const Color(0xFF0d1117)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1 * (size.width / COLS);

    final blockWidth = size.width / COLS;
    final blockHeight = size.height / ROWS;

    // Desenha o tabuleiro
    for (int y = 0; y < ROWS; y++) {
      for (int x = 0; x < COLS; x++) {
        if (board[y][x] != 0) {
          blockPaint.color = PIECE_COLORS[board[y][x]];
          final rect = Rect.fromLTWH(
            x * blockWidth,
            y * blockHeight,
            blockWidth,
            blockHeight,
          );
          canvas.drawRect(rect, blockPaint);
          canvas.drawRect(rect, borderPaint);
        }
      }
    }
    
    // Desenha a peça atual
    for (int y = 0; y < currentPlayer.matrix.length; y++) {
      for (int x = 0; x < currentPlayer.matrix[y].length; x++) {
        if (currentPlayer.matrix[y][x] != 0) {
          blockPaint.color = PIECE_COLORS[currentPlayer.matrix[y][x]];
           final rect = Rect.fromLTWH(
            (currentPlayer.pos.x + x) * blockWidth,
            (currentPlayer.pos.y + y) * blockHeight,
            blockWidth,
            blockHeight,
          );
          canvas.drawRect(rect, blockPaint);
          canvas.drawRect(rect, borderPaint);
        }
      }
    }

    if (isGameOver) {
      final gameOverPaint = Paint()..color = Colors.black.withOpacity(0.75);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gameOverPaint);

      final textStyle = GoogleFonts.pressStart2p(
        fontSize: 30.0, 
        color: Colors.redAccent, 
        fontWeight: FontWeight.bold
      );
      final textSpan = TextSpan(text: 'FIM DE\n JOGO', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      final offset = Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2);
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class NextPiecePainter extends CustomPainter {
  final Piece piece;

  NextPiecePainter({required this.piece});

  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint();
    final borderPaint = Paint()
      ..color = const Color(0xFF0d1117)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1 * (size.width / 4);
    
    final matrix = piece.matrix;
    final blockWidth = size.width / 4;
    final blockHeight = size.height / 4;
    final offsetX = (4 - matrix.length) / 2;
    final offsetY = (4 - matrix.length) / 2;

    for (int y = 0; y < matrix.length; y++) {
      for (int x = 0; x < matrix[y].length; x++) {
        if (matrix[y][x] != 0) {
          blockPaint.color = PIECE_COLORS[matrix[y][x]];
          final rect = Rect.fromLTWH(
            (x + offsetX) * blockWidth,
            (y + offsetY) * blockHeight,
            blockWidth,
            blockHeight,
          );
          canvas.drawRect(rect, blockPaint);
          canvas.drawRect(rect, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
