import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Classe para representar uma posição no tabuleiro
class BoardPosition {
  final int row;
  final int col;

  BoardPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}


class NexoChessScreen extends StatefulWidget {
  const NexoChessScreen({super.key});

  @override
  State<NexoChessScreen> createState() => _NexoChessScreenState();
}

class _NexoChessScreenState extends State<NexoChessScreen> {
  static const PIECES = {
    'wR': '♖', 'wN': '♘', 'wB': '♗', 'wQ': '♕', 'wK': '♔', 'wP': '♙',
    'bR': '♜', 'bN': '♞', 'bB': '♝', 'bQ': '♛', 'bK': '♚', 'bP': '♟'
  };

  static const PIECE_VALUES = {
    'P': 10, 'N': 30, 'B': 30, 'R': 50, 'Q': 90, 'K': 900
  };

  late List<List<String?>> _board;
  String _turn = 'w';
  BoardPosition? _selectedPiece;
  List<BoardPosition> _validMoves = [];
  int _playerTime = 60;
  int _computerTime = 60;
  Timer? _timer;
  Map<String, BoardPosition?> _lastMove = {'from': null, 'to': null};
  bool _gameOver = false;
  String _status = "Sua vez de jogar.";

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initGame() {
    setState(() {
      _board = _createInitialBoard();
      _turn = 'w';
      _selectedPiece = null;
      _validMoves = [];
      _playerTime = 60;
      _computerTime = 60;
      _lastMove = {'from': null, 'to': null};
      _gameOver = false;
      _status = 'Sua vez de jogar.';
    });
    _timer?.cancel();
    _startTimer();
  }

  List<List<String?>> _createInitialBoard() {
    return [
      ['bR', 'bN', 'bB', 'bQ', 'bK', 'bB', 'bN', 'bR'],
      ['bP', 'bP', 'bP', 'bP', 'bP', 'bP', 'bP', 'bP'],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      ['wP', 'wP', 'wP', 'wP', 'wP', 'wP', 'wP', 'wP'],
      ['wR', 'wN', 'wB', 'wQ', 'wK', 'wB', 'wN', 'wR']
    ];
  }
  
  void _handleSquareTap(int row, int col) {
    if (_gameOver || _turn != 'w') return;

    final position = BoardPosition(row, col);

    if (_selectedPiece != null && _validMoves.contains(position)) {
      _movePiece(_selectedPiece!, position);
      return;
    }

    setState(() {
      _selectedPiece = null;
      _validMoves = [];

      final piece = _board[row][col];
      if (piece != null && piece.startsWith('w')) {
        _selectedPiece = position;
        _validMoves = _getValidMoves(piece, row, col);
      }
    });
  }

  void _movePiece(BoardPosition from, BoardPosition to) {
    final piece = _board[from.row][from.col];
    
    setState(() {
      _board[to.row][to.col] = piece;
      _board[from.row][from.col] = null;
      
      if (piece == 'wP' && to.row == 0) _board[to.row][to.col] = 'wQ';
      if (piece == 'bP' && to.row == 7) _board[to.row][to.col] = 'bQ';
      
      _lastMove = {'from': from, 'to': to};
      _selectedPiece = null;
      _validMoves = [];
    });
    
    _switchTurn();
  }
  
  void _switchTurn() {
    _timer?.cancel();
    _turn = (_turn == 'w') ? 'b' : 'w';
    
    if (_isCheckmate('w')) {
        _endGame('b', 'Checkmate');
        return;
    } else if (_isCheckmate('b')) {
        _endGame('w', 'Checkmate');
        return;
    } else if (_isStalemate(_turn)) {
        _endGame('draw', 'Stalemate');
        return;
    }

    setState(() {
      if (_turn == 'w') {
        _status = "Sua vez de jogar.";
        _playerTime = 60;
      } else {
        _status = "Computador está pensando...";
        _computerTime = 60;
      }
    });
    
    _startTimer();
    
    if (_turn == 'b') {
        Future.delayed(const Duration(milliseconds: 500), _makeComputerMove);
    }
  }

  void _makeComputerMove() {
      if (_gameOver) return;
      final bestMove = _findBestMove();
      if (bestMove != null) {
          _movePiece(bestMove['from']!, bestMove['to']!);
      } else {
          _endGame('draw', 'No moves for computer');
      }
  }

  Map<String, BoardPosition>? _findBestMove() {
      int bestScore = -99999;
      Map<String, BoardPosition>? move;
      final allMoves = _getAllPossibleMoves('b');

      allMoves.shuffle();

      for (final m in allMoves) {
          final tempBoard = List.generate(8, (r) => List<String?>.from(_board[r]));
          final piece = tempBoard[m['from']!.row][m['from']!.col];
          tempBoard[m['to']!.row][m['to']!.col] = piece;
          tempBoard[m['from']!.row][m['from']!.col] = null;
          
          int score = _evaluateBoard(tempBoard);

          if (score > bestScore) {
              bestScore = score;
              move = m;
          }
      }
      return move;
  }

  int _evaluateBoard(List<List<String?>> currentBoard) {
      int score = 0;
      for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
              final piece = currentBoard[r][c];
              if (piece != null) {
                  final value = PIECE_VALUES[piece[1]]!;
                  score += (piece[0] == 'b' ? value : -value);
              }
          }
      }
      return score;
  }

  List<Map<String, BoardPosition>> _getAllPossibleMoves(String color) {
      final moves = <Map<String, BoardPosition>>[];
      for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
              final piece = _board[r][c];
              if (piece != null && piece.startsWith(color)) {
                  final valid = _getValidMoves(piece, r, c);
                  for (var v in valid) {
                      moves.add({'from': BoardPosition(r, c), 'to': v});
                  }
              }
          }
      }
      return moves;
  }
  
   List<BoardPosition> _getValidMoves(String piece, int row, int col) {
      final moves = <BoardPosition>[];
      final color = piece[0];

      bool addMove(int r, int c, {bool isCaptureOnly = false, bool isMoveOnly = false}) {
          if (r >= 0 && r < 8 && c >= 0 && c < 8) {
              final target = _board[r][c];
              if (isCaptureOnly) {
                  if (target != null && !target.startsWith(color)) moves.add(BoardPosition(r, c));
              } else if (isMoveOnly) {
                  if (target == null) moves.add(BoardPosition(r, c));
              } else {
                  if (target == null || !target.startsWith(color)) moves.add(BoardPosition(r, c));
              }
              return target == null;
          }
          return false;
      }

      void addSlidingMoves(List<List<int>> directions) {
          for (final dir in directions) {
              int r = row + dir[0], c = col + dir[1];
              while (addMove(r, c)) {
                  r += dir[0]; c += dir[1];
              }
          }
      }

      switch (piece[1]) {
          case 'P':
              final dir = color == 'w' ? -1 : 1;
              final startRow = color == 'w' ? 6 : 1;
              if (addMove(row + dir, col, isMoveOnly: true)) {
                 if (row == startRow) addMove(row + 2 * dir, col, isMoveOnly: true);
              }
              addMove(row + dir, col - 1, isCaptureOnly: true);
              addMove(row + dir, col + 1, isCaptureOnly: true);
              break;
          case 'R': addSlidingMoves([[0, 1], [0, -1], [1, 0], [-1, 0]]); break;
          case 'B': addSlidingMoves([[1, 1], [1, -1], [-1, 1], [-1, -1]]); break;
          case 'Q': addSlidingMoves([[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]]); break;
          case 'N':
              final knightMoves = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
              for (var m in knightMoves) { addMove(row + m[0], col + m[1]); }
              break;
          case 'K':
              final kingMoves = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
              for (var m in kingMoves) { addMove(row + m[0], col + m[1]); }
              break;
      }
      
      return moves.where((move) {
          final tempBoard = List.generate(8, (r) => List<String?>.from(_board[r]));
          tempBoard[move.row][move.col] = tempBoard[row][col];
          tempBoard[row][col] = null;
          return !_isInCheck(color, tempBoard);
      }).toList();
  }

  BoardPosition? _findKing(String color, List<List<String?>> currentBoard) {
      final kingPiece = '${color}K';
      for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
              if (currentBoard[r][c] == kingPiece) {
                  return BoardPosition(r, c);
              }
          }
      }
      return null;
  }

  bool _isInCheck(String kingColor, List<List<String?>> currentBoard) {
      final kingPos = _findKing(kingColor, currentBoard);
      if (kingPos == null) return true;
      final opponentColor = kingColor == 'w' ? 'b' : 'w';
      
      for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
              final piece = currentBoard[r][c];
              if (piece != null && piece.startsWith(opponentColor)) {
                  final moves = _getRawMoves(piece, r, c, currentBoard);
                  if (moves.any((m) => m.row == kingPos.row && m.col == kingPos.col)) {
                      return true;
                  }
              }
          }
      }
      return false;
  }

  List<BoardPosition> _getRawMoves(String piece, int row, int col, List<List<String?>> currentBoard) {
      final moves = <BoardPosition>[];
      final color = piece[0];

      bool addMove(int r, int c, {bool isCaptureOnly = false}) {
          if (r >= 0 && r < 8 && c >= 0 && c < 8) {
              final target = currentBoard[r][c];
              if (isCaptureOnly) {
                  if (target != null && !target.startsWith(color)) moves.add(BoardPosition(r, c));
              } else {
                  if (target == null || !target.startsWith(color)) moves.add(BoardPosition(r, c));
              }
              return target == null;
          }
          return false;
      }

      void addSlidingMoves(List<List<int>> directions) {
          for (final dir in directions) {
              int r = row + dir[0], c = col + dir[1];
              while (addMove(r, c)) { r += dir[0]; c += dir[1]; }
          }
      }

      switch (piece[1]) {
          case 'P':
              final dir = color == 'w' ? -1 : 1;
              addMove(row + dir, col - 1, isCaptureOnly: true);
              addMove(row + dir, col + 1, isCaptureOnly: true);
              break;
          case 'R': addSlidingMoves([[0, 1], [0, -1], [1, 0], [-1, 0]]); break;
          case 'B': addSlidingMoves([[1, 1], [1, -1], [-1, 1], [-1, -1]]); break;
          case 'Q': addSlidingMoves([[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]]); break;
          case 'N':
              final knightMoves = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
              for (var m in knightMoves) { addMove(row + m[0], col + m[1]); }
              break;
          case 'K':
              final kingMoves = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
              for (var m in kingMoves) { addMove(row + m[0], col + m[1]); }
              break;
      }
      return moves;
  }
  
  bool _isCheckmate(String color) {
      return _isInCheck(color, _board) && _getAllPossibleMoves(color).isEmpty;
  }

  bool _isStalemate(String color) {
      return !_isInCheck(color, _board) && _getAllPossibleMoves(color).isEmpty;
  }

  void _startTimer() {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_gameOver) {
              timer.cancel();
              return;
          }
          setState(() {
              if (_turn == 'w') {
                  _playerTime--;
                  if (_playerTime <= 0) {
                      _endGame('b', 'Timeout');
                  }
              } else {
                  _computerTime--;
                  if (_computerTime <= 0) {
                      _endGame('w', 'Timeout');
                  }
              }
          });
      });
  }

  void _endGame(String winner, String reason) {
    if (_gameOver) return;
    
    _timer?.cancel();
    _gameOver = true;
    
    setState(() {
      _status = 'Fim de Jogo!';
    });

    String message = '';
    if (winner == 'draw') {
        message = 'Empate por $reason.';
    } else if (winner == 'w') {
        message = 'Você venceu! ($reason)';
    } else {
        message = 'O Computador venceu. ($reason)';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Fim de Jogo!', style: GoogleFonts.pressStart2p(fontSize: 18)),
        content: Text(message, style: GoogleFonts.lato()),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () {
              Navigator.of(context).pop();
              _initGame();
            },
            child: const Text('Jogar Novamente'),
          ),
        ],
      ),
    );
  }


  // --- MÉTODO BUILD CORRIGIDO (v3) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Nexo Chess', style: GoogleFonts.pressStart2p(fontSize: 18)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        // O widget 'Center' foi removido da raiz para permitir a rolagem vertical
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // Layout Vertical (Mobile): Já é um SingleChildScrollView
              return _buildVerticalLayout(context);
            } else {
              // Layout Horizontal (Desktop): Envolvido em um Center para telas largas
              return Center(child: _buildHorizontalLayout(context));
            }
          },
        ),
      ),
    );
  }
  // --- FIM DA CORREÇÃO ---


  Widget _buildVerticalLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPlayerInfo(context, 'Computador', _computerTime),
            const SizedBox(height: 16),
            _buildBoard(context),
            const SizedBox(height: 16),
            _buildPlayerInfo(context, 'Você (Brancas)', _playerTime),
            const SizedBox(height: 24),
            _buildControls(context),
          ],
        ),
      ),
    );
  }

  // --- LAYOUT HORIZONTAL CORRIGIDO ---
  Widget _buildHorizontalLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            // Adicionado SingleChildScrollView para a coluna do tabuleiro
            child: SingleChildScrollView( 
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPlayerInfo(context, 'Computador', _computerTime),
                  const SizedBox(height: 24),
                  _buildBoard(context), 
                  const SizedBox(height: 24),
                  _buildPlayerInfo(context, 'Você (Brancas)', _playerTime),
                ],
              ),
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 2,
            // Adicionado SingleChildScrollView para os controles
            child: SingleChildScrollView( 
              child: _buildControls(context),
            ),
          ),
        ],
      ),
    );
  }
  // --- FIM DA CORREÇÃO ---

  Widget _buildPlayerInfo(BuildContext context, String name, int time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              time.toString(),
              style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBoard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = min(screenWidth * 0.9, 500.0);

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
         width: boardSize,
         height: boardSize,
         decoration: BoxDecoration(
           border: Border.all(color: Theme.of(context).cardColor, width: 2),
           borderRadius: BorderRadius.circular(8),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.4),
               spreadRadius: 2,
               blurRadius: 10,
             ),
           ],
         ),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final col = index % 8;
            final isLight = (row + col) % 2 == 0;
            final piece = _board[row][col];
            final position = BoardPosition(row, col);
            
            final isSelected = _selectedPiece == position;
            final isValidMove = _validMoves.contains(position);
            final isLastMove = _lastMove['from'] == position || _lastMove['to'] == position;

            Color squareColor = isLight ? const Color(0xFFB0BEC5) : const Color(0xFF455A64); // Azul-Cinza
            if (isLastMove) {
              squareColor = Colors.yellow.withOpacity(0.5);
            }

            return GestureDetector(
              onTap: () => _handleSquareTap(row, col),
              child: Container(
                color: squareColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if(isSelected)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.7),
                          border: Border.all(color: Colors.white, width: 2)
                        ),
                      ),
                    if (piece != null)
                      Text(
                        PIECES[piece]!,
                        style: TextStyle(
                          fontSize: min(boardSize / 10, 40),
                          color: piece.startsWith('w') ? Colors.white : const Color(0xFF212121),
                           shadows: [
                             Shadow(
                               blurRadius: 4.0,
                               color: Colors.black.withOpacity(0.3),
                               offset: const Offset(1.0, 1.0),
                             ),
                           ],
                        ),
                      ),
                    if (isValidMove)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      )
                  ],
                ),
              ),
            );
          },
          itemCount: 64,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Container(
           width: double.infinity,
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: Theme.of(context).cardColor,
             borderRadius: BorderRadius.circular(8),
           ),
           child: Column(
             children: [
               Text('Status do Jogo', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Text(_status, style: GoogleFonts.lato(fontSize: 16), textAlign: TextAlign.center),
             ],
           ),
         ),
         const SizedBox(height: 20),
         ElevatedButton(
           onPressed: _initGame,
           style: ElevatedButton.styleFrom(
             backgroundColor: Theme.of(context).primaryColor,
             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8),
             ),
           ),
           child: Text('Reiniciar Jogo', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
         ),
      ],
    );
  }
}
