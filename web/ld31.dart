library ld31;

import 'dart:html';
import 'dart:web_gl' as GL;
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'dart:math';
part 'shader.dart';
part 'sprites.dart';
part 'texture.dart';
part 'player.dart';

GL.RenderingContext gl;
Random random = new Random();

int GAME_WIDTH = 650;
int GAME_HEIGHT = 487;
int GAME_SIZE_SCALE = 2;
List<bool> keys = new List<bool>(256);
class Game {
  Matrix4 bgViewMatrix;
  Matrix4 viewMatrix;
  var canvas;
  Sprites sprites, bgs, scaledBG;

  List<Sprite> spriteList = new List<Sprite>();
  Sprite bg;
  Player player;
  Game() {
    canvas = querySelector("#game");
    canvas.setAttribute("width", "${GAME_WIDTH}px");
    canvas.setAttribute("height", "${GAME_HEIGHT}px");
    resize();
    gl = canvas.getContext("webgl");
    window.onResize.listen((event) => resize());
    if (gl == null) gl = canvas.getContext("experimental-webgl");
    if (gl == null) { noWebGL(); }
    else { start(); }
    for (int i=0; i <256;i++) keys[i] = false;
    window.onKeyDown.listen((e) {
      if (e.keyCode<256) keys[e.keyCode] = true;
    });
    window.onKeyUp.listen((e) {
      if (e.keyCode<256) keys[e.keyCode] = false;
    });
    window.onBlur.listen((e) {
      for (int i=0; i <256;i++) keys[i] = false;
    });
    window.onMouseWheel.listen((e) {
      scaling = true;
    });
  }

  void resize() {
    int w = window.innerWidth;
    int h = window.innerHeight;
    double xScale = w/GAME_WIDTH;
    double yScale = h/GAME_HEIGHT;
    if (xScale < yScale) {
      int newHeight = (GAME_HEIGHT*xScale).floor();
      canvas.setAttribute("style", "width: ${w}px; height: ${GAME_HEIGHT * xScale}px; left: 0px; top:${(h-newHeight)/2}px");
    } else {
      int newWidth = (GAME_WIDTH*yScale).floor();
      canvas.setAttribute("style", "width: ${GAME_WIDTH * yScale}px; height: ${h}px; left: ${(w-newWidth)/2}px; top:0px");
    }
  }
  double rot = 0.0;
  void start() {
    viewMatrix =  makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0);
  bgViewMatrix = makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0);
    Texture spriteSheet = new Texture("tex/sprites.png");
    Texture blankSheet = new Texture("tex/blank.png");
    Texture bgSheet = new Texture("tex/bg.png");
    Texture.loadAll();
    scaledBG = new Sprites(testShader, bgSheet.texture);
    bgs = new Sprites(testShader, blankSheet.texture);
    bgs.addSprite(new Sprite(0.0, 0.0, GAME_WIDTH+0.0, 150.0, 0.0, 0.0, 0.45, 0.94, 0.88, 1.0));
    bgs.addSprite(new Sprite(0.0, 150.0, GAME_WIDTH+0.0, 5.0, 0.0, 0.0, 0.36, 0.75, 0.36, 1.0));
    bgs.addSprite(new Sprite(0.0, 155.0, GAME_WIDTH+0.0, GAME_HEIGHT-155.0, 0.0, 0.0, 0.5, 0.36, 0.24, 1.0));
    scaledBG.addSprite(new Sprite(0.0, 0.0, 256.0, 256.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0));

    sprites = new Sprites(testShader, spriteSheet.texture);
    player = new Player(new Vector2(0.0, 0.0));
    sprites.addSprite(player.getSprite());
    window.requestAnimationFrame(render);
  }

  double lastTime = -1.0;
  double xOffs = 0.0, yOffs = 0.0;
  double scale = 0.0;
  double scaleSpeed = 0.01;
  bool moveUp = true;
  bool scaling = false;
  void render(double time) {
    if (lastTime==-1.0) lastTime = time;
    double passedTime = time-lastTime;
    if (passedTime>0.1) passedTime = 0.1;
    if (passedTime<0.0) passedTime = 0.0;
    if (moveUp) {
      if (scale <= 2.75 && (scaleUp() || scaling)) {
        bgViewMatrix.scale(1.0+scaleSpeed, 1.0+scaleSpeed, 1.0);
        scale += scaleSpeed;
        scaling = true;
      } else if (scale >= 0) {
        scaling = false;
        moveUp = false;
      }
    } else {
      if (scale >= 0 && (scaleDown() || scaling)) {
        bgViewMatrix.scale(1.0-scaleSpeed, 1.0-scaleSpeed, 1.0);
        scale -= scaleSpeed;
        scaling = true;
      } else if (scale <= 2.75) {
        scaling = false;
        moveUp = true;
      }
    }

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(GL.DEPTH_BUFFER_BIT | GL.COLOR_BUFFER_BIT);
    scaledBG.render(bgViewMatrix);
//    bgs.render();
    player.render(time);
    sprites.render(viewMatrix);

    window.requestAnimationFrame(render);

    int error = gl.getError();
    if (error!=0) {
      print("Error: ${error}");
    }
  }

  void noWebGL() {
    canvas.setAttribute("style", "display: none;");
    querySelector("#webGlWarning").setAttribute("style", "display: all");
  }
}


bool leftPressed() {
  return keys[37] || keys[65];
}
bool rightPressed() {
  return keys[39] || keys[68];
}
bool upPressed() {
  return keys[32] || keys[38] || keys[87];
}

bool scaleUp() {
  return false;
}

bool scaleDown() {
  return false;
}
void main() {
  new Game();
}
