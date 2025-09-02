import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class SrsService {
  static Cartao calcular(Cartao cartao, int qualidade) {
    if (qualidade < 3) {
      cartao.repeticoes = 0;
      cartao.intervalo = 1; 
    } else {
      cartao.repeticoes++;
      
      double novoEaseFactor = cartao.easeFactor + (0.1 - (5 - qualidade) * (0.08 + (5 - qualidade) * 0.02));
      if (novoEaseFactor < 1.3) {
        cartao.easeFactor = 1.3;
      } else {
        cartao.easeFactor = novoEaseFactor;
      }

      if (cartao.repeticoes == 1) {
        cartao.intervalo = 1;
      } else if (cartao.repeticoes == 2) {
        cartao.intervalo = 6;
      } else {
        cartao.intervalo = (cartao.intervalo * cartao.easeFactor).round();
      }
    }

    cartao.proximaRevisao = DateTime.now().add(Duration(days: cartao.intervalo));
    return cartao;
  }
}
