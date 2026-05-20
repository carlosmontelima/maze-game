import ddf.minim.*;

// ── Música ────────────────────────────────────────────────────
Minim minim;
AudioPlayer musica;

// =============================================================
//  MAZE CHASER
//  Inspirado em Atari 2600 / ZX Spectrum / Apple II / CGA PC
//
//  Controles: Setas direcionais ou WASD
//  Sobreviva o máximo que puder — o PERSEGUIDOR acelera!
// =============================================================

// ── Grade do labirinto ────────────────────────────────────────
final int COLS = 15;
final int ROWS = 15;
final int CELL = 38;  // tamanho de cada célula em pixels

// Paredes horizontais: wallH[linha][coluna] = parede acima da célula
// Paredes verticais:   wallV[linha][coluna] = parede à esquerda da célula
boolean[][] wallH;
boolean[][] wallV;

// ── Layout da tela ────────────────────────────────────────────
final int BEZEL = 8;
final int BAR_H = 20;
int MAZE_X, MAZE_Y;
int SCR_W, SCR_H;

// ── Paleta CGA / ZX ───────────────────────────────────────────
color C_BLACK   = #000000;
color C_WHITE   = #FFFFFF;
color C_CYAN    = #55FFFF;
color C_MAGENTA = #FF55FF;
color C_YELLOW  = #FFFF55;
color C_GREEN   = #55FF55;
color C_RED     = #FF5555;
color C_BLUE    = #0000AA;
color C_GREY    = #AAAAAA;

// ── Estados do jogo ───────────────────────────────────────────
final int ST_MENU = 0;
final int ST_PLAY = 1;
final int ST_DEAD = 2;
int state = ST_MENU;

// ── Jogador ───────────────────────────────────────────────────
float px, py;           // posição em pixels (absoluta)
int   pgx, pgy;         // célula atual na grade
final float P_SPEED  = 2.8;
final float P_RADIUS = CELL * 0.24;
boolean moveU, moveD, moveL, moveR;

// ── Perseguidor ───────────────────────────────────────────────
float kx, ky;
int   kgx, kgy;
final float K_RADIUS   = CELL * 0.35;
final float K_BASE_SPD = 3.3;
float killerSpeed;
int[] kPath     = new int[0];
int   kPathStep = 0;
int   bfsTimer  = 0;

// ── Tempo e recordes ─────────────────────────────────────────
long  startMs;
long  elapsedMs;
long  bestMs          = 0;
final float SPD_INTERVAL = 10.0;  // segundos entre cada aceleração
final float SPD_BOOST    = 0.22;  // quanto o perseguidor acelera por nível

// ── Efeito de piscar ─────────────────────────────────────────
boolean blinkOn  = true;
int     blinkTick = 0;

// ── Overlay de scanlines (efeito CRT retrô) ──────────────────
PGraphics scanlines;

// ── Mapa atual (0, 1 ou 2) ───────────────────────────────────
int mapaAtual = 0;

// =============================================================
//  DEFINIÇÃO DOS TRÊS MAPAS FIXOS
//
//  Cada mapa é representado por dois arrays de strings:
//    mH = paredes horizontais (ROWS+1 linhas × COLS colunas)
//    mV = paredes verticais   (ROWS linhas × COLS+1 colunas)
//
//  '1' = há parede   '0' = passagem livre
//
//  Os três mapas têm corredores abertos e múltiplos caminhos,
//  então o jogador nunca fica preso num beco sem saída.
// =============================================================

// ── Mapa 0: Grelha aberta com ilhas centrais ─────────────────
String[] mapa0H = {
  "111111111111111",  // borda topo
  "100010001000100",
  "101010101010101",
  "100000100000100",
  "111010001010111",
  "000010101010000",
  "101110001000101",
  "100000101000100",
  "101010001010101",
  "100010101010100",
  "111000001000111",
  "000010101010000",
  "101010001010101",
  "100000101000100",
  "101010101010101",
  "111111111111111"   // borda base
};
String[] mapa0V = {
  "1000100010001001",  // borda esquerda + direita
  "1010001000100101",
  "1001010101010011",
  "1010100010100101",
  "1000001010000011",
  "1010101010101001",
  "1001010001010011",
  "1010001010100101",
  "1001010101000011",
  "1010100010010101",
  "1000010100001001",
  "1010101010101011",
  "1001010001010001",
  "1010001010100101",
  "1001010101010011"
};

// ── Mapa 1: Espiral com câmaras abertas ──────────────────────
String[] mapa1H = {
  "111111111111111",
  "100000000000001",
  "101111111111101",
  "100000000000101",
  "111110111110101",
  "000000100000101",
  "101110101110101",
  "101000101000001",
  "101011101011101",
  "101000001000101",
  "101111111110101",
  "100000000010101",
  "110111011010001",
  "100100010011101",
  "101010101010101",
  "111111111111111"
};
String[] mapa1V = {
  "1000000000000001",
  "1010000000000101",
  "1010111111111001",
  "1000000000001001",
  "1011111011110001",
  "1000000100000101",
  "1011101011110001",
  "1010001010000101",
  "1010110101110001",
  "1010000001000101",
  "1011111111101001",
  "1000000000101001",
  "1011011011000101",
  "1010010001111001",
  "1010101010101001"
};

// ── Mapa 2: Labirinto de blocos com passagens largas ─────────
String[] mapa2H = {
  "111111111111111",
  "100010001000101",
  "101010101010001",
  "100000001000101",
  "101111101011101",
  "100000001000001",
  "101011101110101",
  "100010000010101",
  "101010111010001",
  "100000100000101",
  "101011101110101",
  "100000001000001",
  "101111001011001",
  "100010101010101",
  "101000001000001",
  "111111111111111"
};
String[] mapa2V = {
  "1000100010001001",
  "1010100010001001",
  "1001010010101001",
  "1010001000100001",
  "1001111010110001",
  "1010000010001001",
  "1001011011100001",
  "1010010000101001",
  "1001010111001001",
  "1010001000001001",
  "1001011011100001",
  "1010001000001001",
  "1001111001010001",
  "1010010101010001",
  "1001000010001001"
};

// =============================================================
//  CARREGA UM DOS TRÊS MAPAS PARA wallH / wallV
// =============================================================
void carregarMapa(int indice) {
  wallH = new boolean[ROWS + 1][COLS];
  wallV = new boolean[ROWS][COLS + 1];

  String[] srcH, srcV;

  // Escolhe qual mapa usar
  if (indice == 1) {
    srcH = mapa1H;
    srcV = mapa1V;
  } else if (indice == 2) {
    srcH = mapa2H;
    srcV = mapa2V;
  } else {
    srcH = mapa0H;
    srcV = mapa0V;
  }

  // Converte as strings em arrays booleanos de paredes
  for (int r = 0; r <= ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      wallH[r][c] = (srcH[r].charAt(c) == '1');
    }
  }
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c <= COLS; c++) {
      wallV[r][c] = (srcV[r].charAt(c) == '1');
    }
  }
}

// =============================================================
//  CONSULTA DE PAREDES  (coordenadas locais da grade)
//  Direções: 0=cima, 1=direita, 2=baixo, 3=esquerda
// =============================================================
// Retorna true se tem parede entre a célula (coluna, linha) e a vizinha na direção dada
boolean temParede(int coluna, int linha, int direcao) {
  if (direcao == 0) return (linha <= 0)       || wallH[linha][coluna];      // cima:    borda ou parede acima
  if (direcao == 2) return (linha >= ROWS-1)  || wallH[linha+1][coluna];   // baixo:   borda ou parede abaixo
  if (direcao == 3) return (coluna <= 0)      || wallV[linha][coluna];      // esquerda: borda ou parede à esquerda
  if (direcao == 1) return (coluna >= COLS-1) || wallV[linha][coluna+1];   // direita:  borda ou parede à direita
  return true;
}
boolean canMove(int coluna, int linha, int direcao) { return !temParede(coluna, linha, direcao); }

// =============================================================
//  COLISÃO  (resolve movimento respeitando paredes)
// =============================================================

// Recebe a posição atual (xAtual, yAtual), a posição nova desejada (xNovo) e o raio do jogador.
// Retorna o xNovo corrigido — se tiver parede no caminho, empurra de volta.
float resolveX(float xAtual, float yAtual, float xNovo, float raio) {
  int linhaAtual  = constrain(floor(yAtual / CELL), 0, ROWS-1);
  int colunaAtual = constrain(floor(xAtual / CELL), 0, COLS-1);

  if (xNovo > xAtual) {  // jogador indo para a direita
    int colunaDestino = constrain(floor((xNovo + raio) / CELL), 0, COLS-1);
    if (colunaDestino > colunaAtual && temParede(colunaAtual, linhaAtual, 1))
      xNovo = (colunaAtual + 1) * CELL - raio - 0.5;  // encosta na parede da direita
  } else if (xNovo < xAtual) {  // jogador indo para a esquerda
    int colunaDestino = constrain(floor((xNovo - raio) / CELL), 0, COLS-1);
    if (colunaDestino < colunaAtual && temParede(colunaAtual, linhaAtual, 3))
      xNovo = colunaAtual * CELL + raio + 0.5;  // encosta na parede da esquerda
  }
  return xNovo;
}

// Mesma coisa que resolveX, mas no eixo vertical (cima e baixo).
float resolveY(float xAtual, float yAtual, float yNovo, float raio) {
  int colunaAtual = constrain(floor(xAtual / CELL), 0, COLS-1);
  int linhaAtual  = constrain(floor(yAtual / CELL), 0, ROWS-1);

  if (yNovo > yAtual) {  // jogador indo para baixo
    int linhaDestino = constrain(floor((yNovo + raio) / CELL), 0, ROWS-1);
    if (linhaDestino > linhaAtual && temParede(colunaAtual, linhaAtual, 2))
      yNovo = (linhaAtual + 1) * CELL - raio - 0.5;  // encosta na parede de baixo
  } else if (yNovo < yAtual) {  // jogador indo para cima
    int linhaDestino = constrain(floor((yNovo - raio) / CELL), 0, ROWS-1);
    if (linhaDestino < linhaAtual && temParede(colunaAtual, linhaAtual, 0))
      yNovo = linhaAtual * CELL + raio + 0.5;  // encosta na parede de cima
  }
  return yNovo;
}

// =============================================================
//  BFS — BUSCA EM LARGURA PARA O PERSEGUIDOR
//  Encontra o caminho mais curto entre duas células da grade.
// =============================================================
int[] bfsPath(int sc, int sr, int ec, int er) {
  int[] prev = new int[ROWS * COLS];
  java.util.Arrays.fill(prev, -1);
  int[] q    = new int[ROWS * COLS];
  int head = 0, tail = 0;
  int start = sr * COLS + sc;
  prev[start] = start;
  q[tail++]   = start;
  int[] ddc = {0, 1, 0, -1};
  int[] ddr = {-1, 0, 1, 0};
  outer:
  while (head < tail) {
    int cur = q[head++];
    int cr  = cur / COLS, cc = cur % COLS;
    if (cr == er && cc == ec) break outer;
    for (int d = 0; d < 4; d++) {
      if (!canMove(cc, cr, d)) continue;
      int nc = cc + ddc[d], nr = cr + ddr[d];
      int id = nr * COLS + nc;
      if (prev[id] == -1) { prev[id] = cur; q[tail++] = id; }
    }
  }
  int goal = er * COLS + ec;
  if (prev[goal] == -1) return new int[0];
  java.util.ArrayList<Integer> path = new java.util.ArrayList<Integer>();
  int cur = goal;
  while (cur != prev[cur]) { path.add(0, cur); cur = prev[cur]; }
  int[] out = new int[path.size() * 2];
  for (int i = 0; i < path.size(); i++) {
    out[i*2]   = path.get(i) % COLS;
    out[i*2+1] = path.get(i) / COLS;
  }
  return out;
}

// =============================================================
//  SETUP — executado uma vez no início
// =============================================================
void setup() {
  MAZE_X = BEZEL;
  MAZE_Y = BEZEL + BAR_H;
  SCR_W  = COLS * CELL + BEZEL * 2;
  SCR_H  = ROWS * CELL + BEZEL * 2 + BAR_H * 2;

  size(586, 626);  // 15*38 + 16 = 586,  + 40 de barras = 626

  // Cria o overlay de scanlines (efeito de TV CRT antiga)
  scanlines = createGraphics(SCR_W, SCR_H);
  scanlines.beginDraw();
  scanlines.clear();
  for (int y = 0; y < SCR_H; y += 2) {
    scanlines.stroke(0, 0, 0, 50);
    scanlines.line(0, y, SCR_W, y);
  }
  scanlines.endDraw();

  noSmooth();
  frameRate(60);
  textFont(createFont("Courier New", 13, false));

  // Carrega a música e toca em loop contínuo
  minim = new Minim(this);
  musica = minim.loadFile("musica-jogo.mp3");
  musica.loop();
}

// =============================================================
//  INICIA UMA PARTIDA
// =============================================================
void startGame() {
  // Sorteia um mapa diferente do atual
  int novoMapa;
  do { novoMapa = (int)random(3); } while (novoMapa == mapaAtual);
  mapaAtual = novoMapa;
  carregarMapa(mapaAtual);

  // Jogador começa no canto superior esquerdo
  pgx = 1; pgy = 1;
  px  = MAZE_X + pgx * CELL + CELL * 0.5;
  py  = MAZE_Y + pgy * CELL + CELL * 0.5;

  // Perseguidor começa no canto inferior direito
  kgx = COLS - 2; kgy = ROWS - 2;
  kx  = MAZE_X + kgx * CELL + CELL * 0.5;
  ky  = MAZE_Y + kgy * CELL + CELL * 0.5;

  killerSpeed = K_BASE_SPD;
  kPath     = new int[0];
  kPathStep = 0;
  bfsTimer  = 0;
  moveU = moveD = moveL = moveR = false;
  startMs   = millis();
  elapsedMs = 0;
  state     = ST_PLAY;
}

// =============================================================
//  LOOP PRINCIPAL DE DESENHO (60 fps)
// =============================================================
void draw() {
  // Controle do efeito de piscar (troca a cada 8 frames)
  blinkTick++;
  if (blinkTick >= 8) { blinkOn = !blinkOn; blinkTick = 0; }

  background(#111111);
  fill(C_BLACK); noStroke();
  rect(0, 0, SCR_W, SCR_H);

  if      (state == ST_MENU) drawMenu();
  else if (state == ST_PLAY) drawGame();
  else                       drawDead();

  image(scanlines, 0, 0);  // aplica efeito CRT por cima
  noFill(); stroke(C_GREY, 100); strokeWeight(1);
  rect(0, 0, SCR_W - 1, SCR_H - 1);
}

// =============================================================
//  TELA DE MENU
// =============================================================
void drawMenu() {
  noStroke(); fill(C_BLUE);
  rect(0, 0, SCR_W, BAR_H + BEZEL);
  fill(C_WHITE); textSize(13); textAlign(LEFT, TOP);
  text(" MAZE CHASER  v4.0", 2, 2);
  textAlign(RIGHT, TOP);
  text("(C) 1984 RETRO SOFT ", SCR_W - 2, 2);

  int tx = 14, ty = 36, lh = 17;
  retro_text(C_CYAN,   tx, ty, "** MAZE CHASER **");            ty += lh*2;
  retro_text(C_WHITE,  tx, ty, "UM LABIRINTO SEM SAIDA.");      ty += lh;
  retro_text(C_WHITE,  tx, ty, "SO O TEMPO IMPORTA.");          ty += lh*2;
  retro_text(C_YELLOW, tx, ty, "CONTROLES:");                   ty += lh;
  retro_text(C_WHITE,  tx, ty, "  SETAS OU WASD = MOVER");      ty += lh*2;
  retro_text(C_GREEN,  tx, ty, "COMO JOGAR:");                  ty += lh;
  retro_text(C_WHITE,  tx, ty, "  FUJA DO PERSEGUIDOR.");       ty += lh;
  retro_text(C_WHITE,  tx, ty, "  USE OS CORREDORES.");         ty += lh;
  retro_text(C_WHITE,  tx, ty, "  A CADA 10 SEG: MAIS RAPIDO!");ty += lh*2;

  if (bestMs > 0) {
    retro_text(C_GREEN, tx, ty, "RECORDE: " + formatTime(bestMs));
    ty += lh*2;
  } else {
    ty += lh;
  }

  if (blinkOn) retro_text(C_YELLOW, tx, ty, "PRESSIONE ESPACO PARA JOGAR");

  // Legenda dos sprites
  int ly = ty + lh*2;
  retro_text(C_GREY, tx, ly, "VOCE:");
  drawRetroPlayer(tx + 58, ly + 7, true);
  retro_text(C_GREY, tx + 100, ly, "PERSEGUIDOR:");
  drawRetroKiller(tx + 210, ly + 7, true);
}

// =============================================================
//  TELA DE JOGO — atualiza lógica e desenha tudo
// =============================================================
void drawGame() {
  elapsedMs   = millis() - startMs;

  // Aumenta a velocidade do perseguidor a cada intervalo
  killerSpeed = K_BASE_SPD + floor((elapsedMs/1000.0) / SPD_INTERVAL) * SPD_BOOST;

  movePlayer();
  updateKiller();
  checkDeath();

  drawTitleBar();
  drawRetroMaze();
  drawRetroPlayer(px, py, false);
  drawRetroKiller(kx, ky, false);
  drawStatusBar();
}

// =============================================================
//  TELA DE GAME OVER
// =============================================================
void drawDead() {
  if (blinkOn) { noStroke(); fill(C_RED, 35); rect(0, 0, SCR_W, SCR_H); }

  int tx = 14, ty = 55, lh = 20;
  textSize(22); textAlign(LEFT, TOP); fill(C_MAGENTA);
  text("** FIM DE JOGO **", tx, ty);             ty += lh + 10;
  textSize(13);
  retro_text(C_WHITE,  tx, ty, "O PERSEGUIDOR TE PEGOU!");      ty += lh*2;
  retro_text(C_YELLOW, tx, ty, "SEU TEMPO : " + formatTime(elapsedMs)); ty += lh;
  if (elapsedMs >= bestMs && blinkOn)
    retro_text(C_GREEN, tx, ty, ">>> NOVO RECORDE! <<<");
  ty += lh;
  retro_text(C_WHITE,  tx, ty, "RECORDE  : " + formatTime(bestMs));    ty += lh*2;
  int lvl = (int)floor((elapsedMs/1000.0) / SPD_INTERVAL);
  retro_text(C_CYAN,   tx, ty, "NIVEL DE VELOCIDADE : " + lvl);         ty += lh*2;
  if (blinkOn) {
    retro_text(C_YELLOW, tx, ty, "ESPACO = JOGAR DE NOVO"); ty += lh;
    retro_text(C_YELLOW, tx, ty, "M      = MENU");
  }
}

// =============================================================
//  BARRAS DE STATUS (topo e base)
// =============================================================
void drawTitleBar() {
  noStroke(); fill(C_BLUE);
  rect(0, 0, SCR_W, MAZE_Y);
  fill(C_WHITE); textSize(13);
  textAlign(LEFT, CENTER);
  text(" MAZE CHASER", 2, MAZE_Y * 0.5);
  int lvl = (int)floor((elapsedMs/1000.0) / SPD_INTERVAL);
  textAlign(RIGHT, CENTER);
  text("NVL:" + lvl + " ", SCR_W - 2, MAZE_Y * 0.5);
}

void drawStatusBar() {
  int barY = MAZE_Y + ROWS * CELL;
  int barH = SCR_H - barY;
  noStroke(); fill(C_BLUE);
  rect(0, barY, SCR_W, barH);
  fill(C_YELLOW); textSize(13);
  textAlign(LEFT, CENTER);
  text(" TEMPO:" + formatTime(elapsedMs), 0, barY + barH * 0.5);
  if (bestMs > 0) {
    fill(C_GREEN); textAlign(RIGHT, CENTER);
    text("RECORDE:" + formatTime(bestMs) + " ", SCR_W, barY + barH * 0.5);
  }
}

// =============================================================
//  DESENHO DO LABIRINTO
//  Paredes = retângulos sólidos de 4px.  Chão = preto puro.
// =============================================================
final int WW = 4;  // espessura da parede em pixels

void drawRetroMaze() {
  noStroke(); fill(C_BLACK);
  rect(MAZE_X, MAZE_Y, COLS * CELL, ROWS * CELL);

  fill(C_WHITE); noStroke();
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      int x = MAZE_X + c * CELL;
      int y = MAZE_Y + r * CELL;
      if (wallH[r][c]) rect(x, y,     CELL + WW, WW);  // parede acima
      if (wallV[r][c]) rect(x, y,     WW, CELL + WW);  // parede à esquerda
    }
  }
  // Borda direita e inferior
  rect(MAZE_X + COLS * CELL, MAZE_Y,            WW, ROWS * CELL + WW);
  rect(MAZE_X,               MAZE_Y + ROWS*CELL, COLS*CELL + WW, WW);
}

// =============================================================
//  SPRITES RETRÔ  (pixel art 7×7 desenhada com rect())
// =============================================================
final int SP  = 4;  // tamanho do pixel do jogador
final int SKP = 5;  // tamanho do pixel do perseguidor (maior = mais assustador)

void drawRetroPlayer(float ox, float oy, boolean icon) {
  // Forma de diamante / seta
  int[][] shape = {
    {0,0,0,1,0,0,0},
    {0,0,1,1,1,0,0},
    {0,1,1,1,1,1,0},
    {1,1,1,0,1,1,1},
    {0,1,1,1,1,1,0},
    {0,0,1,1,1,0,0},
    {0,0,0,1,0,0,0}
  };
  int sp = icon ? 2 : SP;
  int ow = 7 * sp, oh = 7 * sp;
  noStroke();
  for (int r = 0; r < 7; r++)
    for (int c = 0; c < 7; c++)
      if (shape[r][c] == 1) {
        fill(C_CYAN);
        rect(ox - ow*0.5 + c*sp, oy - oh*0.5 + r*sp, sp, sp);
      }
  // "Olho" central
  fill(C_BLACK);
  rect(ox - sp*0.5, oy - sp*0.5, sp, sp);
}

void drawRetroKiller(float ox, float oy, boolean icon) {
  // Caveira / rosto monstruoso
  int[][] skull = {
    {0,1,1,1,1,1,0},
    {1,1,1,1,1,1,1},
    {1,0,1,1,1,0,1},
    {1,1,1,1,1,1,1},
    {0,1,0,1,0,1,0},
    {0,1,1,1,1,1,0},
    {0,0,1,0,1,0,0}
  };
  int sp = icon ? 2 : SKP;
  int ow = 7 * sp, oh = 7 * sp;
  color kc = blinkOn ? C_MAGENTA : C_RED;  // pisca entre magenta e vermelho
  noStroke();
  for (int r = 0; r < 7; r++)
    for (int c = 0; c < 7; c++)
      if (skull[r][c] == 1) {
        fill(kc);
        rect(ox - ow*0.5 + c*sp, oy - oh*0.5 + r*sp, sp, sp);
      }
  // Órbitas oculares
  fill(C_BLACK);
  rect(ox - ow*0.5 + 1*sp, oy - oh*0.5 + 2*sp, sp, sp);
  rect(ox - ow*0.5 + 5*sp, oy - oh*0.5 + 2*sp, sp, sp);
}

// Função auxiliar para texto retrô
void retro_text(color c, int x, int y, String s) {
  fill(c); textSize(13); textAlign(LEFT, TOP); text(s, x, y);
}

// =============================================================
//  MOVIMENTO DO JOGADOR  (colisão em coordenadas locais do mapa)
// =============================================================
void movePlayer() {
  // Converte para coordenadas locais do labirinto
  float lx = px - MAZE_X, ly = py - MAZE_Y;
  float nx = lx, ny = ly;
  if (moveU) ny -= P_SPEED;
  if (moveD) ny += P_SPEED;
  if (moveL) nx -= P_SPEED;
  if (moveR) nx += P_SPEED;

  // Resolve colisões com as paredes
  nx = resolveX(lx, ly, nx, P_RADIUS);
  ny = resolveY(nx, ly, ny, P_RADIUS);

  // Mantém dentro dos limites do labirinto
  lx = constrain(nx, P_RADIUS + 1, COLS * CELL - P_RADIUS - 1);
  ly = constrain(ny, P_RADIUS + 1, ROWS * CELL - P_RADIUS - 1);

  // Converte de volta para coordenadas absolutas de tela
  px = lx + MAZE_X;
  py = ly + MAZE_Y;
  pgx = constrain(floor(lx / CELL), 0, COLS-1);
  pgy = constrain(floor(ly / CELL), 0, ROWS-1);
}

// =============================================================
//  IA DO PERSEGUIDOR  (BFS na grade do labirinto)
//  Recalcula o caminho periodicamente e segue célula a célula.
// =============================================================
void updateKiller() {
  bfsTimer++;
  // Recalcula o caminho a cada 18 frames ou quando chega ao destino
  if (bfsTimer >= 18 || kPathStep * 2 >= kPath.length) {
    kPath     = bfsPath(kgx, kgy, pgx, pgy);
    kPathStep = 0;
    bfsTimer  = 0;
  }
  if (kPath.length == 0 || kPathStep * 2 >= kPath.length) return;

  // Centro em pixels da próxima célula alvo
  float tx = MAZE_X + kPath[kPathStep*2]   * CELL + CELL * 0.5;
  float ty = MAZE_Y + kPath[kPathStep*2+1] * CELL + CELL * 0.5;
  float dx = tx - kx, dy = ty - ky;
  float d  = sqrt(dx*dx + dy*dy);

  if (d < killerSpeed + 0.5) {
    // Chegou na célula — avança para a próxima
    kx  = tx; ky  = ty;
    kgx = kPath[kPathStep*2];
    kgy = kPath[kPathStep*2+1];
    kPathStep++;
  } else {
    // Move em direção à célula alvo
    kx += dx / d * killerSpeed;
    ky += dy / d * killerSpeed;
  }
}

// Verifica se o perseguidor alcançou o jogador
void checkDeath() {
  if (dist(px, py, kx, ky) < P_RADIUS + K_RADIUS - 2) {
    if (elapsedMs > bestMs) bestMs = elapsedMs;
    state = ST_DEAD;
  }
}

// =============================================================
//  ENTRADA DO TECLADO
// =============================================================
void keyPressed() {
  if (state == ST_MENU && key == ' ')           { startGame(); return; }
  if (state == ST_DEAD && key == ' ')           { startGame(); return; }
  if (state == ST_DEAD && (key=='m'||key=='M')) { state = ST_MENU; return; }
  if (keyCode == UP    || key=='w'||key=='W') moveU = true;
  if (keyCode == DOWN  || key=='s'||key=='S') moveD = true;
  if (keyCode == LEFT  || key=='a'||key=='A') moveL = true;
  if (keyCode == RIGHT || key=='d'||key=='D') moveR = true;
}
void keyReleased() {
  if (keyCode == UP    || key=='w'||key=='W') moveU = false;
  if (keyCode == DOWN  || key=='s'||key=='S') moveD = false;
  if (keyCode == LEFT  || key=='a'||key=='A') moveL = false;
  if (keyCode == RIGHT || key=='d'||key=='D') moveR = false;
}

// =============================================================
//  UTILITÁRIO — formata milissegundos como MM:SS.cs
// =============================================================
String formatTime(long ms) {
  int s  = (int)(ms / 1000);
  int m  = s / 60;
  int sc = s % 60;
  int cs = (int)(ms % 1000) / 10;
  return nf(m,2) + ":" + nf(sc,2) + "." + nf(cs,2);
}
