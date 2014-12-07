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
int GAME_HEIGHT = 488;
int GAME_SIZE_SCALE = 2;
List<bool> keys = new List<bool>(256);
Texture bgSheet;
class Game {
  static Game instance;
  Matrix4 bgViewMatrix;
  Matrix4 viewMatrix, sunViewMatrix;
  CanvasElement canvas;
  Sprites sprites, tiles, clouds, snowSprites, particleSprites;

  List<Sprite> spriteList = new List<Sprite>();
  List<BlankObject> blankObjectList = new List<BlankObject>();
  List<ParticleAnimation> particles = new List<ParticleAnimation>();
  Sprite bg;
  Player player;
  Game() {
    instance = this;
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
  int tileWidth = 21;
  Int16List tilePos = new Int16List.fromList([
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 1, 1, 2, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
     1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  ]);

int getTileAt(int x, int y) {
  x %= tileWidth;
  y %= tilePos.length~/tileWidth;
  return tilePos.elementAt(x.abs() + (y.abs() * tileWidth));
}
  Sprites sun;
  void start() {
    viewMatrix =  makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0).scale(GAME_SIZE_SCALE+0.0, GAME_SIZE_SCALE+0.0, 1.0);
    bgViewMatrix = makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0);
    sunViewMatrix = makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0).scale(GAME_SIZE_SCALE*2.0, GAME_SIZE_SCALE*2.0, 1.0).translate((GAME_WIDTH/(GAME_SIZE_SCALE*2))/4-15, 45.0, 0.0);
    Texture spriteSheet = new Texture("tex/sprites.png");
    Texture blankSheet = new Texture("tex/blank.png");
    bgSheet = new Texture("tex/bg.png");
    Texture.loadAll();

    clouds = new Sprites(testShader, blankSheet.texture);
    for (int i = 0; i < 10; i++) {
      double x = random.nextInt((GAME_WIDTH~/GAME_SIZE_SCALE)+200)-200+0.0;
      double y = random.nextInt(GAME_HEIGHT~/GAME_SIZE_SCALE)+0.0;
      double width = random.nextInt((GAME_WIDTH~/GAME_SIZE_SCALE) - 30)+30.0;
      double height = random.nextInt(4)*10.0;
      if (width <= height) width *= 2;
      Cloud cloud = new Cloud(new Vector2(x, y), new Sprite(x, y, width, height, 0.0, 0.0, 1.0, 1.0, 1.0, 0.25));
      clouds.addSprite(cloud.sprite);
      blankObjectList.add(cloud);
    }
    snowSprites = new Sprites(testShader, blankSheet.texture);
    for (int i = 0; i < 1000;i++) {
      double x = random.nextInt(GAME_WIDTH).toDouble();
      double y = random.nextInt(GAME_HEIGHT).toDouble();
      double w = random.nextInt(4)+1.0;
      double h = w;
      Snow snow = new Snow(i, new Vector2(x, y), new Sprite(x, y, w, h, 0.0, 0.0, 191/255, 236/255, 241/255, 0.9));
      snowSprites.addSprite(snow.sprite);
      blankObjectList.add(snow);
    }
    sun = new Sprites(testShader, spriteSheet.texture);
    sun.addSprite(new Sprite(-16.0, -16.0, 32.0, 32.0, 1.0, 3.0, 1.0, 1.0, 1.0, 1.0));
    tiles = new Sprites(testShader, spriteSheet.texture);
    for (int x = 0; x < tileWidth;x++) {
      for (int y = 0; y < tilePos.length/tileWidth;y++) {
          tiles.addSprite(new Sprite(x*16.0, y*16.0, 16.0, 16.0, getTileAt(x, y)+0.0, 4.0, 1.0, 1.0, 1.0, 1.0));
      }
    }
    sprites = new Sprites(testShader, spriteSheet.texture);
    player = new Player(new Vector2(10.0, 10.0), 16, 32);
    sprites.addSprite(player.getSprite());
    sprites.addSprite(new Sprite(8*16.0, 4*16.0+2.0, 16.0, 32.0, 6.0, 0.0, 1.0, 1.0, 1.0, 1.0));

    particleSprites = new Sprites(testShader, spriteSheet.texture);

    window.requestAnimationFrame(render);
  }

  int addParticleAnim(ParticleAnimation anim) {
    particles.add(anim);
    particleSprites.addSprite(anim.sprite);
    return particles.length-1;
  }

  double lastTime = -1.0;
  double xOffs = 0.0, yOffs = 0.0;
  double scale = 0.0;
  double scaleSpeed = 0.01;
  bool moveUp = true;
  bool scaling = false;
  double offs = 0.0;

  void render(double time) {
    if (lastTime==-1.0) lastTime = time;
    double passedTime = time-lastTime;
    if (passedTime>0.1) passedTime = 0.1;
    if (passedTime<0.0) passedTime = 0.0;
    offs += passedTime;

    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(80/255, 156/255, 159/255, 1.0);
    gl.clear(GL.DEPTH_BUFFER_BIT | GL.COLOR_BUFFER_BIT);

    gl.enable(GL.BLEND);
    gl.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
    sunViewMatrix.translate(sin(time*0.0008),0.0- (cos(time*0.0008)), 0.0);
    sunViewMatrix.rotateZ(sin(time*0.0008) * cos(time*0.0008)/80);

    sun.render(sunViewMatrix);
    blankObjectList.forEach((obj) { obj.render(time); });

    List<int> toRemove = new List<int>();
    for (int i =0; i < toRemove.length;i++) toRemove.setAll(0, [-1]);

    int numRemoved = 0;
    particles.forEach((part) {
      part.render(time);
      part.index = part.index - numRemoved;
      if (part.isComplete()) {
        int index = part.index;
        toRemove.add(index);
        particleSprites.removeSprite(index);
        numRemoved += 1;
      }
    });
    toRemove.forEach((i) { if (i>-1) particles.removeAt(i); });

    particleSprites.render(viewMatrix);

    clouds.render(bgViewMatrix);
    tiles.render(viewMatrix);
    sprites.render(viewMatrix);
    player.render(passedTime, time);
    snowSprites.render(bgViewMatrix);

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
  return keys[32] || keys[38] || keys[87] ;
}

bool scaleUp() {
  return false;
}

bool scaleDown() {
  return false;
}

abstract class BlankObject {
  Vector2 pos;
  Sprite sprite;
  BlankObject(this.pos, this.sprite);

  void render(double time);
  Sprite getSprite() {
    return sprite;
  }
}

class Cloud extends BlankObject {
  Cloud(Vector2 pos, Sprite sprite) : super(pos, sprite);
  double moveSpeed = -1.0;
  void render(double time) {
    if (moveSpeed == -1) {
      moveSpeed = (sprite.h/(sprite.w%20.0))*0.07;
    }
    if (moveSpeed > 4) moveSpeed = 1.0;
    pos += new Vector2(moveSpeed+0.0, 0.0);
    if (pos.x > GAME_WIDTH) pos.x = 0.0-sprite.w - random.nextInt(100);
    sprite.x = pos.x;
    sprite.y = pos.y;
  }
}
class Snow extends BlankObject {
  int index = 0;
  Snow(this.index, Vector2 pos, Sprite sprite) : super(pos, sprite);
  double moveSpeed = -1.0;
  void render(double time) {
    if (moveSpeed == -1) {
      moveSpeed = (sprite.h*random.nextInt((index+1)))*0.0034;
    }
    pos += new Vector2((moveSpeed+sin(time*0.006)).abs(), (moveSpeed+sin(time*0.000542)).abs());
    if (pos.x > GAME_WIDTH) pos.x = 0.0-sprite.w - random.nextInt(100);
    if (pos.y > GAME_HEIGHT) pos.y = 0.0-sprite.h;
    sprite.x = pos.x;
    sprite.y = pos.y;
  }
}

class ParticleAnimation extends BlankObject {
  int index = 0;
  Int16List spriteFrames;
  int spriteIndex = 0;
  bool isFinished = false;
  int delay = 100;
  ParticleAnimation(this.index, Vector2 pos, Sprite sprite, this.spriteFrames, this.delay) : super(pos, sprite);

  double getAnimFrameU() {
      return spriteFrames.elementAt(((spriteIndex % spriteFrames.length~/2)*2.0).toInt()).toDouble();
  }
  double getAnimFrameV() {
      return spriteFrames.elementAt(((spriteIndex % spriteFrames.length~/2)*2.0+1).toInt()).toDouble();
  }

  double lastSpriteUpdateTime = 0.0;
  void render(double time) {
    if (time - lastSpriteUpdateTime > delay) {
      lastSpriteUpdateTime = time;
      spriteIndex += 1;
    }
    if (spriteIndex > spriteFrames.length/2) { isFinished = true; return; }
    sprite.u = getAnimFrameU();
    sprite.v = getAnimFrameV();
    sprite.x = pos.x;
    sprite.y = pos.y;
  }
  bool isComplete() {
    return isFinished;
  }
}
void main() {
  new Game();
}
