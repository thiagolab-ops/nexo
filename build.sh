#!/bin/bash
# Para o script se algo der errado
set -e

# Configura o projeto para o tipo "Release" (versão final)
cmake -S linux -B build/linux/x64/release -D CMAKE_BUILD_TYPE=Release

# Constrói (compila) o projeto usando apenas 1 núcleo para economizar memória
cmake --build build/linux/x64/release -- -j1
