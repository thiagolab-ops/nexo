import 'package:flutter/foundation.dart';
import '../models/models.dart';

class SrsService {
  static Cartao calcular(Cartao cartao, int qualidade) {
    // Adicionamos um print de depuração para o Teste de Sanidade.
    if (kDebugMode) {
      print("--- SRS DEBUG --- Qualidade: $qualidade, Repetições ANTES: ${cartao.repeticoes}, Intervalo ANTES: ${cartao.intervalo} dias");
    }

    // Qualidade é um score de 1 a 5, onde < 3 é uma resposta errada.
    
    // Se a resposta foi correta
    if (qualidade >= 3) {
      // Atualiza o Fator de Facilidade (Ease Factor).
      double novoEaseFactor = cartao.easeFactor + (0.1 - (5 - qualidade) * (0.08 + (5 - qualidade) * 0.02));
      cartao.easeFactor = novoEaseFactor < 1.3 ? 1.3 : novoEaseFactor;

      // Incrementa o contador de repetições SUCESSIVAS corretas.
      cartao.repeticoes++;

      // Calcula o novo intervalo.
      if (cartao.repeticoes <= 1) { // <= 1 para segurança
        cartao.intervalo = 1; // Primeira vez correta, revisa amanhã.
      } else if (cartao.repeticoes == 2) {
        cartao.intervalo = 6; // Segunda vez correta, revisa em 6 dias.
      } else {
        // A partir da terceira vez, o intervalo cresce exponencialmente.
        cartao.intervalo = (cartao.intervalo * cartao.easeFactor).round();
      }
    }
    // Se a resposta foi errada, não fazemos nada aqui. A TelaEstudo vai tratar o "lapso".

    // Define a data da próxima revisão. A unidade é DIAS.
    cartao.proximaRevisao = DateTime.now().add(Duration(days: cartao.intervalo));

    if (kDebugMode) {
      print("--- SRS RESULTADO --- Repetições DEPOIS: ${cartao.repeticoes}, Novo Intervalo: ${cartao.intervalo} dias, Próxima Revisão: ${cartao.proximaRevisao}");
    }
    
    return cartao;
  }
}
