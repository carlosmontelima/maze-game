// =============================================================
//  MAZE CHASER  v3 — RETRO EDITION
//  Inspired by Atari 2600 / ZX Spectrum / Apple II / CGA PC
//
//  Controls : Arrow Keys or WASD
//  Survive as long as you can — the STALKER speeds up!
// =============================================================

// ── Grid ──────────────────────────────────────────────────────
final int COLS = 15;
final int ROWS = 15;
final int CELL = 38;   // wide corridors — chunky retro tiles

// wallH[r][c] = wall on TOP  of cell (r,c)   [ROWS+1][COLS]
// wallV[r][c] = wall on LEFT of cell (r,c)   [ROWS][COLS+1]
boolean[][] wallH;
boolean[][] wallV;

// ── Screen layout ─────────────────────────────────────────────
final int BEZEL  = 8;
final int BAR_H  = 20;
int MAZE_X, MAZE_Y;
int SCR_W, SCR_H;

// ── CGA / ZX palette ──────────────────────────────────────────
color C_BLACK   = #000000;
color C_WHITE   = #FFFFFF;
color C_CYAN    = #55FFFF;
color C_MAGENTA = #FF55FF;
color C_YELLOW  = #FFFF55;
color C_GREEN   = #55FF55;
color C_RED     = #FF5555;
color C_BLUE    = #0000AA;
color C_GREY    = #AAAAAA;

// ── Game state ────────────────────────────────────────────────
final int ST_MENU = 0;
final int ST_PLAY = 1;
final int ST_DEAD = 2;
int state = ST_MENU;

// ── Player ────────────────────────────────────────────────────
float px, py;          // pixel pos (absolute screen)
int   pgx, pgy;        // grid cell
final float P_SPEED  = 2.8;
final float P_RADIUS = CELL * 0.24;
boolean moveU, moveD, moveL, moveR;

// ── Killer ────────────────────────────────────────────────────
float kx, ky;
int   kgx, kgy;
final float K_RADIUS    = CELL * 0.35;
final float K_BASE_SPD  = 3.3;
float killerSpeed;
int[] kPath     = new int[0];
int   kPathStep = 0;
int   bfsTimer  = 0;

// ── Timing ────────────────────────────────────────────────────
long  startMs;
long  elapsedMs;
long  bestMs          = 0;
final float SPD_INTERVAL = 10.0;
final float SPD_BOOST    = 0.22;

// ── Blink ─────────────────────────────────────────────────────
boolean blinkOn  = true;
int     blinkTick = 0;

// ── Scanlines ─────────────────────────────────────────────────
PGraphics scanlines;

// =============================================================
//  MAZE GENERATION
//  Step 1 — Iterative DFS (perfect maze, every cell reachable)
//  Step 2 — Remove extra random walls to create loops/shortcuts
// =============================================================
void generateMaze() {
  wallH = new boolean[ROWS + 1][COLS];
  wallV = new boolean[ROWS][COLS + 1];
  for (boolean[] row : wallH) java.util.Arrays.fill(row, true);
  for (boolean[] row : wallV) java.util.Arrays.fill(row, true);

  // ── Step 1: DFS carve ──────────────────────────────────────
  boolean[] visited = new boolean[ROWS * COLS];
  int[]     stk     = new int[ROWS * COLS];
  int top = 0;
  visited[0] = true;
  stk[top++] = 0;

  while (top > 0) {
    int cur = stk[top - 1];
    int cr  = cur / COLS, cc = cur % COLS;
    int[] nb  = new int[4];
    int[] dir = new int[4];
    int cnt = 0;
    if (cr > 0      && !visited[(cr-1)*COLS+cc]) { nb[cnt]=cur-COLS; dir[cnt++]=0; }
    if (cc < COLS-1 && !visited[cr*COLS+cc+1])   { nb[cnt]=cur+1;    dir[cnt++]=1; }
    if (cr < ROWS-1 && !visited[(cr+1)*COLS+cc]) { nb[cnt]=cur+COLS; dir[cnt++]=2; }
    if (cc > 0      && !visited[cr*COLS+cc-1])   { nb[cnt]=cur-1;    dir[cnt++]=3; }
    if (cnt == 0) { top--; continue; }
    int pick = (int)random(cnt);
    int nxt  = nb[pick];
    visited[nxt] = true;
    stk[top++]   = nxt;
    carveWall(cur % COLS, cur / COLS, dir[pick]);
  }

  // ── Step 2: punch extra holes for open feel ─────────────────
  // Remove ~35% of remaining interior walls at random.
  // This creates loops so the player is never trapped in dead ends.
  int extra = (int)((ROWS * COLS) * 0.35);
  for (int i = 0; i < extra; i++) {
    int r = (int)random(1, ROWS - 1);
    int c = (int)random(1, COLS - 1);
    int d = (int)random(4);
    // Only remove if it doesn't open the outer border
    if (d == 0 && r > 0)      wallH[r][c]   = false;
    if (d == 2 && r < ROWS-1) wallH[r+1][c] = false;
    if (d == 3 && c > 0)      wallV[r][c]   = false;
    if (d == 1 && c < COLS-1) wallV[r][c+1] = false;
  }
}

void carveWall(int c, int r, int d) {
  if (d == 0) wallH[r][c]   = false;
  if (d == 2) wallH[r+1][c] = false;
  if (d == 1) wallV[r][c+1] = false;
  if (d == 3) wallV[r][c]   = false;
}

// =============================================================
//  WALL QUERIES  (maze-local cell coordinates)
// =============================================================
boolean wallBetween(int c, int r, int d) {
  if (d == 0) return (r <= 0)      || wallH[r][c];
  if (d == 2) return (r >= ROWS-1) || wallH[r+1][c];
  if (d == 3) return (c <= 0)      || wallV[r][c];
  if (d == 1) return (c >= COLS-1) || wallV[r][c+1];
  return true;
}
boolean canMove(int c, int r, int d) { return !wallBetween(c, r, d); }

// =============================================================
//  COLLISION  (works in MAZE-LOCAL pixel space, no MAZE_X/Y)
// =============================================================
float resolveX(float cx, float cy, float nx, float r) {
  int row = constrain(floor(cy / CELL), 0, ROWS-1);
  int col = constrain(floor(cx / CELL), 0, COLS-1);
  if (nx > cx) {
    int ncol = constrain(floor((nx + r) / CELL), 0, COLS-1);
    if (ncol > col && wallBetween(col, row, 1))
      nx = (col + 1) * CELL - r - 0.5;
  } else if (nx < cx) {
    int ncol = constrain(floor((nx - r) / CELL), 0, COLS-1);
    if (ncol < col && wallBetween(col, row, 3))
      nx = col * CELL + r + 0.5;
  }
  return nx;
}
float resolveY(float cx, float cy, float ny, float r) {
  int col = constrain(floor(cx / CELL), 0, COLS-1);
  int row = constrain(floor(cy / CELL), 0, ROWS-1);
  if (ny > cy) {
    int nrow = constrain(floor((ny + r) / CELL), 0, ROWS-1);
    if (nrow > row && wallBetween(col, row, 2))
      ny = (row + 1) * CELL - r - 0.5;
  } else if (ny < cy) {
    int nrow = constrain(floor((ny - r) / CELL), 0, ROWS-1);
    if (nrow < row && wallBetween(col, row, 0))
      ny = row * CELL + r + 0.5;
  }
  return ny;
}

// =============================================================
//  BFS PATHFINDER
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
//  SETUP
// =============================================================
void setup() {
  MAZE_X = BEZEL;
  MAZE_Y = BEZEL + BAR_H;
  SCR_W  = COLS * CELL + BEZEL * 2;
  SCR_H  = ROWS * CELL + BEZEL * 2 + BAR_H * 2;

  size(586, 626);   // 15*38 + 16 = 586,  15*38 + 16 + 40 = 626

  // Scanline overlay
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
}

// =============================================================
//  GAME INIT
// =============================================================
void startGame() {
  generateMaze();

  // Player starts top-left corridor
  pgx = 1; pgy = 1;
  px  = MAZE_X + pgx * CELL + CELL * 0.5;
  py  = MAZE_Y + pgy * CELL + CELL * 0.5;

  // Killer starts bottom-right
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
//  DRAW LOOP
// =============================================================
void draw() {
  blinkTick++;
  if (blinkTick >= 8) { blinkOn = !blinkOn; blinkTick = 0; }

  background(#111111);
  fill(C_BLACK); noStroke();
  rect(0, 0, SCR_W, SCR_H);

  if      (state == ST_MENU) drawMenu();
  else if (state == ST_PLAY) drawGame();
  else                       drawDead();

  image(scanlines, 0, 0);
  noFill(); stroke(C_GREY, 100); strokeWeight(1);
  rect(0, 0, SCR_W - 1, SCR_H - 1);
}

// =============================================================
//  MENU
// =============================================================
void drawMenu() {
  noStroke(); fill(C_BLUE);
  rect(0, 0, SCR_W, BAR_H + BEZEL);
  fill(C_WHITE); textSize(13); textAlign(LEFT, TOP);
  text(" MAZE CHASER  v3.0", 2, 2);
  textAlign(RIGHT, TOP);
  text("(C) 1984 RETRO SOFT ", SCR_W - 2, 2);

  int tx = 14, ty = 36, lh = 17;
  retro_text(C_CYAN,   tx, ty, "** MAZE CHASER **");           ty += lh*2;
  retro_text(C_WHITE,  tx, ty, "A MAZE WITH NO EXIT.");        ty += lh;
  retro_text(C_WHITE,  tx, ty, "ONLY TIME MATTERS.");          ty += lh*2;
  retro_text(C_YELLOW, tx, ty, "CONTROLS:");                   ty += lh;
  retro_text(C_WHITE,  tx, ty, "  ARROWS OR WASD = MOVE");     ty += lh*2;
  retro_text(C_GREEN,  tx, ty, "HOW TO PLAY:");                ty += lh;
  retro_text(C_WHITE,  tx, ty, "  AVOID THE STALKER.");        ty += lh;
  retro_text(C_WHITE,  tx, ty, "  LOOP IT TO SURVIVE.");       ty += lh;
  retro_text(C_WHITE,  tx, ty, "  EVERY 10 SEC: FASTER!!");    ty += lh*2;

  if (bestMs > 0) {
    retro_text(C_GREEN, tx, ty, "BEST TIME: " + formatTime(bestMs));
    ty += lh*2;
  } else {
    ty += lh;
  }

  if (blinkOn) retro_text(C_YELLOW, tx, ty, "PRESS SPACE TO START");

  // Sprite legend
  int ly = ty + lh*2;
  retro_text(C_GREY, tx, ly, "YOU:");
  drawRetroPlayer(tx + 58, ly + 7, true);
  retro_text(C_GREY, tx + 100, ly, "STALKER:");
  drawRetroKiller(tx + 190, ly + 7, true);
}

// =============================================================
//  GAME
// =============================================================
void drawGame() {
  elapsedMs   = millis() - startMs;
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
//  DEATH
// =============================================================
void drawDead() {
  if (blinkOn) { noStroke(); fill(C_RED, 35); rect(0, 0, SCR_W, SCR_H); }

  int tx = 14, ty = 55, lh = 20;
  textSize(22); textAlign(LEFT, TOP); fill(C_MAGENTA);
  text("** GAME  OVER **", tx, ty);              ty += lh + 10;
  textSize(13);
  retro_text(C_WHITE,  tx, ty, "STALKER GOT YOU!");            ty += lh*2;
  retro_text(C_YELLOW, tx, ty, "YOUR TIME : " + formatTime(elapsedMs)); ty += lh;
  if (elapsedMs >= bestMs && blinkOn)
    retro_text(C_GREEN, tx, ty, ">>> NEW RECORD! <<<");
  ty += lh;
  retro_text(C_WHITE,  tx, ty, "BEST TIME : " + formatTime(bestMs));   ty += lh*2;
  int lvl = (int)floor((elapsedMs/1000.0) / SPD_INTERVAL);
  retro_text(C_CYAN,   tx, ty, "SPEED LVL : " + lvl);                  ty += lh*2;
  if (blinkOn) {
    retro_text(C_YELLOW, tx, ty, "SPACE = PLAY AGAIN"); ty += lh;
    retro_text(C_YELLOW, tx, ty, "M     = MENU");
  }
}

// =============================================================
//  HUD BARS
// =============================================================
void drawTitleBar() {
  noStroke(); fill(C_BLUE);
  rect(0, 0, SCR_W, MAZE_Y);
  fill(C_WHITE); textSize(13);
  textAlign(LEFT, CENTER);
  text(" MAZE CHASER", 2, MAZE_Y * 0.5);
  int lvl = (int)floor((elapsedMs/1000.0) / SPD_INTERVAL);
  textAlign(RIGHT, CENTER);
  text("LVL:" + lvl + " ", SCR_W - 2, MAZE_Y * 0.5);
}

void drawStatusBar() {
  int barY = MAZE_Y + ROWS * CELL;
  int barH = SCR_H - barY;
  noStroke(); fill(C_BLUE);
  rect(0, barY, SCR_W, barH);
  fill(C_YELLOW); textSize(13);
  textAlign(LEFT, CENTER);
  text(" TIME:" + formatTime(elapsedMs), 0, barY + barH * 0.5);
  if (bestMs > 0) {
    fill(C_GREEN); textAlign(RIGHT, CENTER);
    text("BEST:" + formatTime(bestMs) + " ", SCR_W, barY + barH * 0.5);
  }
}

// =============================================================
//  RETRO MAZE DRAW
//  Walls = solid filled rectangles, 4px thick.
//  Floor = pure black.
// =============================================================
final int WW = 4;

void drawRetroMaze() {
  noStroke(); fill(C_BLACK);
  rect(MAZE_X, MAZE_Y, COLS * CELL, ROWS * CELL);

  fill(C_WHITE); noStroke();
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      int x = MAZE_X + c * CELL;
      int y = MAZE_Y + r * CELL;
      if (wallH[r][c])   rect(x,     y,     CELL + WW, WW);   // top
      if (wallV[r][c])   rect(x,     y,     WW, CELL + WW);   // left
    }
  }
  // Right + bottom borders
  rect(MAZE_X + COLS * CELL, MAZE_Y,           WW, ROWS * CELL + WW);
  rect(MAZE_X,               MAZE_Y + ROWS*CELL, COLS*CELL + WW, WW);
}

// =============================================================
//  RETRO SPRITES  (7x7 pixel art, drawn with rect())
// =============================================================
final int SP  = 4;    // player sprite pixel size
final int SKP = 5;    // killer sprite pixel size (bigger, scarier)

void drawRetroPlayer(float ox, float oy, boolean icon) {
  // Diamond / arrowhead shape
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
  // Centre "eye"
  fill(C_BLACK);
  rect(ox - sp*0.5, oy - sp*0.5, sp, sp);
}

void drawRetroKiller(float ox, float oy, boolean icon) {
  // Skull / monster face
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
  color kc = blinkOn ? C_MAGENTA : C_RED;
  noStroke();
  for (int r = 0; r < 7; r++)
    for (int c = 0; c < 7; c++)
      if (skull[r][c] == 1) {
        fill(kc);
        rect(ox - ow*0.5 + c*sp, oy - oh*0.5 + r*sp, sp, sp);
      }
  // Eye sockets
  fill(C_BLACK);
  rect(ox - ow*0.5 + 1*sp, oy - oh*0.5 + 2*sp, sp, sp);
  rect(ox - ow*0.5 + 5*sp, oy - oh*0.5 + 2*sp, sp, sp);
}

void retro_text(color c, int x, int y, String s) {
  fill(c); textSize(13); textAlign(LEFT, TOP); text(s, x, y);
}

// =============================================================
//  PLAYER MOVEMENT  (maze-local coords for collision)
// =============================================================
void movePlayer() {
  // Convert to maze-local
  float lx = px - MAZE_X, ly = py - MAZE_Y;
  float nx = lx, ny = ly;
  if (moveU) ny -= P_SPEED;
  if (moveD) ny += P_SPEED;
  if (moveL) nx -= P_SPEED;
  if (moveR) nx += P_SPEED;

  nx = resolveX(lx, ly, nx, P_RADIUS);
  ny = resolveY(nx, ly, ny, P_RADIUS);

  lx = constrain(nx, P_RADIUS + 1, COLS * CELL - P_RADIUS - 1);
  ly = constrain(ny, P_RADIUS + 1, ROWS * CELL - P_RADIUS - 1);

  px = lx + MAZE_X;
  py = ly + MAZE_Y;
  pgx = constrain(floor(lx / CELL), 0, COLS-1);
  pgy = constrain(floor(ly / CELL), 0, ROWS-1);
}

// =============================================================
//  KILLER AI  (BFS in maze-local cell grid)
// =============================================================
void updateKiller() {
  bfsTimer++;
  if (bfsTimer >= 18 || kPathStep * 2 >= kPath.length) {
    kPath     = bfsPath(kgx, kgy, pgx, pgy);
    kPathStep = 0;
    bfsTimer  = 0;
  }
  if (kPath.length == 0 || kPathStep * 2 >= kPath.length) return;

  // Target = centre of next path cell in screen coords
  float tx = MAZE_X + kPath[kPathStep*2]   * CELL + CELL * 0.5;
  float ty = MAZE_Y + kPath[kPathStep*2+1] * CELL + CELL * 0.5;
  float dx = tx - kx, dy = ty - ky;
  float d  = sqrt(dx*dx + dy*dy);

  if (d < killerSpeed + 0.5) {
    kx  = tx; ky  = ty;
    kgx = kPath[kPathStep*2];
    kgy = kPath[kPathStep*2+1];
    kPathStep++;
  } else {
    kx += dx / d * killerSpeed;
    ky += dy / d * killerSpeed;
  }
}

void checkDeath() {
  if (dist(px, py, kx, ky) < P_RADIUS + K_RADIUS - 2) {
    if (elapsedMs > bestMs) bestMs = elapsedMs;
    state = ST_DEAD;
  }
}

// =============================================================
//  INPUT
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
//  HELPERS
// =============================================================
String formatTime(long ms) {
  int s  = (int)(ms / 1000);
  int m  = s / 60;
  int sc = s % 60;
  int cs = (int)(ms % 1000) / 10;
  return nf(m,2) + ":" + nf(sc,2) + "." + nf(cs,2);
}
