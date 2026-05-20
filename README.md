# Maze Chaser

**Maze Chaser** é um jogo de sobrevivência em labirinto desenvolvido em **Processing (Java)**. Inspirado em clássicos da era 8-bits como Pac-Man, Atari 2600 e jogos de ZX Spectrum, o objetivo é simples: sobreviva o máximo de tempo possível fugindo de um perseguidor implacável.

Este projeto foi construído do zero, sem o uso de motores de jogo externos (como Unity ou Godot), servindo como objeto de estudo para arquitetura de Game Engines, algoritmos de busca em grafos (IA) e detecção de colisões

## ⚙️ Funcionalidades e Mecânicas

* **Inteligência Artificial (Pathfinding):** O inimigo utiliza o algoritmo clássico de **Busca em Largura (BFS)** para calcular e recalcular em tempo real a rota mais curta até o jogador.
* **Dificuldade Progressiva:** A velocidade do perseguidor aumenta matematicamente a cada 10 segundos de sobrevivência, criando uma curva de tensão constante.
* **Level Design Fixo:** Conta com 3 mapas predefinidos (carregados a partir de matrizes de strings) desenhados com múltiplos anéis e corredores interligados para evitar becos sem saída isolados.
* **Colisão Híbrida:** Sistema de física contínua que desliza o jogador perfeitamente pelas bordas das paredes utilizando coordenadas matemáticas e projeção vetorial.
* **Estética Retrô (CRT):** Os gráficos são gerados proceduralmente (sem imagens externas) usando primitivas gráficas, sobrepostos por um filtro de "scanlines" que emula a tela de monitores e televisões de tubo antigas.

---

## 🎮 Controles

| Ação | Tecla |
| :--- | :--- |
| **Mover** | `Setas Direcionais` ou `W`, `A`, `S`, `D` |
| **Iniciar / Jogar de Novo** | `Espaço` |
| **Voltar ao Menu** | `M` (Na tela de Game Over) |

---

## 🛠️ Arquitetura do Sistema

O motor do jogo é baseado em uma **Máquina de Estados Finita (FSM)** que divide o ciclo de execução (*Game Loop*) a 60 FPS em três estados principais:

1. `ST_MENU`: Tela de título e instruções.
2. `ST_PLAY`: Atualização de física, recálculo do BFS, movimentação escalar e renderização.
3. `ST_DEAD`: Tela de estatísticas e registro de recordes.

---

## 🚀 Como executar o projeto

### Pré-requisitos
* Ter a [Processing IDE](https://processing.org/download) instalada no seu sistema (compatível com Windows, Linux e macOS).
* Instalar a biblioteca de áudio **Minim** dentro do Processing.

### Passos
1. Clone este repositório:
   ```bash
   git clone https://github.com/carlosmontelima/maze-game
