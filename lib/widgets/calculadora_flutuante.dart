import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculadoraFlutuante extends StatefulWidget {
  final VoidCallback onClose;
  // ## INÍCIO DA MUDANÇA: Adiciona a função de callback ##
  final Function(String textToInsert) onInsert;
  // ## FIM DA MUDANÇA ##

  const CalculadoraFlutuante({
    super.key, 
    required this.onClose,
    required this.onInsert, // <-- Adicionado ao construtor
  });

  @override
  State<CalculadoraFlutuante> createState() => _CalculadoraFlutuanteState();
}

class _CalculadoraFlutuanteState extends State<CalculadoraFlutuante> {
  String _expression = '';
  String _result = '0';
  bool _isScientific = false;
  Offset _position = const Offset(10, 100);

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _expression = '';
        _result = '0';
      } else if (buttonText == '⌫') {
        _expression = _expression.isNotEmpty ? _expression.substring(0, _expression.length - 1) : '';
      } else if (buttonText == '=') {
        try {
          // Garante que a expressão não esteja vazia antes de calcular
          if (_expression.isEmpty) {
            _result = '0';
            return;
          }
          Parser p = Parser();
          Expression exp = p.parse(_expression.replaceAll('×', '*').replaceAll('÷', '/'));
          ContextModel cm = ContextModel();
          _result = exp.evaluate(EvaluationType.REAL, cm).toString();
        } catch (e) {
          _result = 'Erro';
        }
      } else {
        _expression += buttonText;
      }
    });
  }

  Widget _buildButton(String buttonText, {Color? color, Color? textColor, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ElevatedButton(
          onPressed: () => _onButtonPressed(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey[800],
            foregroundColor: textColor ?? Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(18),
          ),
          child: Text(buttonText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: Material(
          elevation: 4.0,
          color: Colors.transparent,
          child: _buildCalculatorBody(),
        ),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          setState(() {
            _position = details.offset;
          });
        },
        child: _buildCalculatorBody(),
      ),
    );
  }
  
  Widget _buildCalculatorBody() {
    return Card(
      color: Colors.black.withOpacity(0.8),
      child: SizedBox(
        width: _isScientific ? 340 : 280,
        child: Column(
          children: [
            // ## INÍCIO DA MUDANÇA: Adiciona os botões de inserção ##
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Inserir cálculo completo no texto',
                    child: IconButton(
                      icon: const Icon(Icons.functions, size: 20),
                      onPressed: () {
                        if (_result != '0' && _result != 'Erro') {
                          widget.onInsert('$_expression = $_result');
                        }
                      },
                    ),
                  ),
                  Tooltip(
                    message: 'Inserir apenas o resultado no texto',
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_return, size: 20),
                      onPressed: () {
                        if (_result != 'Erro') {
                          widget.onInsert(_result);
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, size: 20)),
                ],
              ),
            ),
            // ## FIM DA MUDANÇA ##
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _expression,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 18),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _result,
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isScientific) ...[
                  _buildButton('sin'),
                  _buildButton('cos'),
                  _buildButton('tan'),
                  _buildButton('^'),
                ],
                _buildButton('C', color: Colors.orangeAccent),
                _buildButton('⌫'),
                _buildButton('÷', color: Colors.blueAccent),
                _buildButton('×', color: Colors.blueAccent),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isScientific) ...[_buildButton('log'),_buildButton('sqrt')],
                _buildButton('7'),
                _buildButton('8'),
                _buildButton('9'),
                _buildButton('-', color: Colors.blueAccent),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isScientific) ...[_buildButton('('),_buildButton(')')],
                _buildButton('4'),
                _buildButton('5'),
                _buildButton('6'),
                _buildButton('+', color: Colors.blueAccent),
              ],
            ),
            Row(
              children: [
                Expanded(
                  flex: _isScientific ? 3 : 2,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildButton('1'),
                          _buildButton('2'),
                          _buildButton('3'),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(onPressed: () => setState(()=> _isScientific = !_isScientific), child: const Text("Sci")),
                          _buildButton('0'),
                          _buildButton('.'),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildButton('=', color: Colors.blueAccent),
              ],
            )
          ],
        ),
      ),
    );
  }
}
