library ld31;

import 'dart:html';
import 'dart:web_gl' as GL;
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'dart:math';
import 'dart:async';
import 'dart:web_audio';

part 'audio.dart';
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

List<Screen> allScreens = new List<Screen>();
Audio audio ;
class Screens {
  static Future loadAndInit() {
    List<Future> allFutures = new List<Future>();
    allScreens.forEach((e) { allFutures.add(e.loadData()); });
    return Future.wait(allFutures);
  }
}
class Screen {
  Int16List tileData;
  String url;
  int screenWidth;
  int screenHeight;
  Screen(this.url) {
    allScreens.add(this);
  }

  Future<String> loadString(String url) {
    Completer<String> completer = new Completer<String>();
    ByteData result;
    var request = new HttpRequest();
    request.open("get", url);

    Future future = request.onLoadEnd.first.then((e) {
      if (request.status~/100==2) {
       completer.complete(request.response as String);
      } else {
        completer.completeError("Cant load ${url}. Response type ${request.status}");
      }
    });
    request.send("");
    return completer.future;
  }
  Future<Int16List> loadData() {
    Completer completer = new Completer();
    loadString(url).then((e) {
      var lineData = e.split("\n");
      screenHeight = lineData.length;
      screenWidth = lineData.first.split(",").length;
      tileData = new Int16List(screenHeight*screenWidth);
      int elementIndex = 0;
      lineData.forEach((nl) {
        nl.split(",").forEach((ee) {
          if (!ee.isEmpty) {
            tileData.setAll(elementIndex, [int.parse(ee)]);
            elementIndex++;
          }
        });
      });
      completer.complete();
    });
    return completer.future;
  }
}
class Game {
  static Game instance;
  Matrix4 bgViewMatrix;
  Matrix4 viewMatrix, sunViewMatrix;
  CanvasElement canvas;
  Sprites sprites, tiles, clouds, snowSprites, particleSprites, skyBox, gui, blankGui, projectiles;

  List<Sprite> spriteList = new List<Sprite>();
  List<BlankObject> blankObjectList = new List<BlankObject>();
  List<ParticleAnimation> particles = new List<ParticleAnimation>();
  List<Projectile> projectileList = new List<Projectile>();
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
  int tileHeight = 10;

  Int16List totalTiles;

  int getTileAt(int x, int y) {
    if (x < 0) { return 1; }
    int tileId = totalTiles.elementAt((y.abs() * (totalTiles.length~/tileHeight)) + x.abs());
    return tileId;
  }

  Sprites sun;

  double activeCoord = 0.0;
  double moveToCoord = 0.0;
  bool isMoving = false;
  int activeSceneId = 0;
  void switchScene(bool forward) {
    if (forward) activeSceneId+=1;
    else activeSceneId-=1;
    moveToCoord = (activeSceneId*(GAME_WIDTH/GAME_SIZE_SCALE)).toDouble();
  }

  Int16List mergeScene(Int16List screen, Int16List secondScreen) {
    Int16List output = new Int16List(screen.length+secondScreen.length);
    int screen1Width = (screen.length~/tileHeight);
    int screen2Width = (secondScreen.length~/tileHeight);
    int totalWidth = (output.length~/tileHeight);
    for (int y = 0; y < tileHeight; y++) {
      output.setAll((y*totalWidth)+0, screen.getRange(y*screen1Width, (y*screen1Width) + screen1Width));
      output.setAll((y*totalWidth)+screen1Width, secondScreen.getRange(y*screen2Width, (y*screen2Width) + screen2Width));
    }
    return output;
  }

  void start() {
    viewMatrix =  makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0).scale(GAME_SIZE_SCALE+0.0, GAME_SIZE_SCALE+0.0, 1.0);
    bgViewMatrix = makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0).scale(GAME_SIZE_SCALE+0.0, GAME_SIZE_SCALE+0.0, 1.0);
    sunViewMatrix = makeOrthographicMatrix(0.0, GAME_WIDTH, GAME_HEIGHT, 0.0, -10.0, 10.0).scale(GAME_SIZE_SCALE*2.0, GAME_SIZE_SCALE*2.0, 1.0).translate((GAME_WIDTH/(GAME_SIZE_SCALE*2))/4-15, 45.0, 0.0);
    Texture spriteSheet = new Texture("tex/sprites.png");
    Texture blankSheet = new Texture("tex/blank.png");
    Texture skyboxSheet = new Texture("tex/skybox.png");
    Texture guiSheet = new Texture("tex/gui.png");
    Texture projectileSheet = new Texture("tex/projectiles.png");
    bgSheet = new Texture("tex/bg.png");
    Texture.loadAll();

    new Screen("screens/1.screen");
    new Screen("screens/2.screen");
    new Screen("screens/3.screen");
    Screens.loadAndInit().catchError((e) {
      print("Error: ${e}");
    }).then((e) {
      audio = new Audio();
      totalTiles = allScreens.elementAt(0).tileData;
      for (int i = 1; i < allScreens.length;i++) {
        totalTiles = mergeScene(totalTiles, allScreens.elementAt(i).tileData);
      }

      tiles = new Sprites(testShader, spriteSheet.texture);
      for (int y = tileHeight-1; y > -1;y--) {
        for (int x = 0; x < (totalTiles.length~/tileHeight); x++) {
          int tileId = getTileAt(x, y);
          tiles.addSprite(new Sprite(x*16.0, y*16.0 +(tileId >= 3 && tileId <= 5 ? 2 : 0), 16.0, 16.0, tileId+0.0, 4.0, 1.0, 1.0, 1.0, 1.0));
        }
      }

      clouds = new Sprites(testShader, blankSheet.texture);
      for (int i = 0; i < 15; i++) {
        double x = random.nextInt((totalTiles.length~/tileHeight * 16.0).toInt()+200)-200+0.0;
        double y = random.nextInt(((tileHeight-4)*16.0).toInt())-16.0;
        double width = random.nextInt((GAME_WIDTH~/GAME_SIZE_SCALE) - 30)+30.0;
        double height = random.nextInt(4)*10.0;
        if (width <= height) width *= 2;
        Cloud cloud = new Cloud(new Vector2(x, y), new Sprite(x, y, width, height, 0.0, 0.0, 1.0, 1.0, 1.0, 0.25));
        clouds.addSprite(cloud.sprite);
        blankObjectList.add(cloud);
      }
      snowSprites = new Sprites(testShader, blankSheet.texture);
      snowSprites.addSprite(new Sprite(0.0, tileHeight*16.0, GAME_WIDTH+0.0,(GAME_HEIGHT - (tileHeight*16.0~/GAME_SIZE_SCALE)).toDouble(), 0.0, 0.0, 37/255, 132/255, 0.0, 1.0));

      for (int i = 0; i < 500;i++) {
        double x = random.nextInt(GAME_WIDTH~/GAME_SIZE_SCALE).toDouble();
        double y = random.nextInt(GAME_HEIGHT~/GAME_SIZE_SCALE).toDouble();
        double w = random.nextInt(4) + 1.0;
        if (w >= 3 && random.nextInt(100) > 30) w--;
        double h = w;
        Snow snow = new Snow(i, new Vector2(x, y), new Sprite(x, y, w, h, 0.0, 0.0, 191/255, 236/255, 241/255, 0.9));
        snowSprites.addSprite(snow.sprite);
        blankObjectList.add(snow);
      }

      skyBox = new Sprites(testShader, skyboxSheet.texture);
      skyBox.addSprite(new Sprite(0.0, 0.0, GAME_WIDTH+0.0, GAME_HEIGHT+0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0));

      sun = new Sprites(testShader, spriteSheet.texture);
      sun.addSprite(new Sprite(-16.0, -16.0, 32.0, 32.0, 1.0, 3.0, 1.0, 1.0, 1.0, 1.0));

      gui = new Sprites(testShader, guiSheet.texture);
      blankGui = new Sprites(testShader, blankSheet.texture);
      sprites = new Sprites(testShader, spriteSheet.texture);
      player = new Player(new Vector2(10.0, 10.0), 16, 32);
      sprites.addSprite(player.getSprite());
      sprites.addSprite(new Sprite(18*16.0, 7*16.0+2.0, 16.0, 32.0, 6.0, 0.0, 1.0, 1.0, 1.0, 1.0));
      particleSprites = new Sprites(testShader, spriteSheet.texture);
      projectiles = new Sprites(testShader, projectileSheet.texture);

      window.requestAnimationFrame(render);
    });
  }

  void addParticleAnim(ParticleAnimation anim) {
    particles.add(anim);
    particleSprites.addSprite(anim.sprite);
  }

  void addProjectile(Projectile proj) {
    projectileList.add(proj);
    projectiles.addSprite(proj.sprite);
  }

  void addGuiElement(Sprite sprite) {
    gui.addSprite(sprite);
  }

  void addBlankGuiElement(Sprite sprite) {
    blankGui.addSprite(sprite);
  }

  double lastTime = -1.0;
  double xOffs = 0.0, yOffs = 0.0;
  double scale = 0.0;
  double scaleSpeed = 0.01;
  bool moveUp = true;
  bool scaling = false;
  double offs = 0.0;
  double movingCooldown = 0.0;
  void render(double time) {

    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(GL.DEPTH_BUFFER_BIT | GL.COLOR_BUFFER_BIT);

    gl.enable(GL.BLEND);
    gl.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);

    if (lastTime==-1.0) lastTime = time;
    double passedTime = time-lastTime;
    if (passedTime>0.1) passedTime = 0.1;
    if (passedTime<0.0) passedTime = 0.0;
    offs += passedTime;

    if (moveToCoord < activeCoord) {
      viewMatrix.translate(1.0, 0.0, 0.0);
      activeCoord -= 1.0;
      isMoving = true;
    } else if (activeCoord < moveToCoord){
      viewMatrix.translate(-1.0, 0.0, 0.0);
      activeCoord += 1.0;
      isMoving = true;
    } else {
      isMoving = false;
    }

    if (isMoving && time - movingCooldown >= 1000) {
      isMoving = false;
    }
    sunViewMatrix.translate(sin(time*0.0008),0.0- (cos(time*0.0008)), 0.0);
    sunViewMatrix.rotateZ((sin(time*0.0008) * cos(time*0.0008))/200);

    skyBox.render(bgViewMatrix);
    blankObjectList.forEach((obj) { obj.render(time); });

    List<int> toRemove = new List<int>();
    for (int i =0; i < toRemove.length;i++) toRemove.setAll(0, [-1]);

    int numRemoved = 0;
    if (particles.length > 0) {
      particles.forEach((part) {
        part.render(time);
        part.index -= numRemoved;
        if (part.isComplete()) {
          int index = part.index;
          toRemove.add(index);
          particleSprites.removeSprite(index);
          numRemoved += 1;
        }
      });
      toRemove.forEach((i) { if (i>-1) particles.removeAt(i); });
    }
    if (projectileList.length > 0) {
      for (int i =0; i < toRemove.length;i++) toRemove.setAll(0, [-1]);
      numRemoved = 0;
      projectileList.forEach((part) {
        part.render(time);
        part.index -= numRemoved;
        if (part.destroy) {
          Sprite aSprite = new Sprite(0.0, 0.0, 16.0, 16.0, 0.0, 9.0, 1.0, 1.0, 1.0, 1.0);
          aSprite.flip = !part.movingLeft;
          ParticleAnimation anim = new ParticleAnimation(particles.length, part.pos, aSprite, new Int16List.fromList([0, 9, 1, 9, 2, 9]), 50);
          addParticleAnim(anim);
          AudioController.play("hit");
          int index = part.index;
          toRemove.add(index);
          projectiles.removeSprite(index);
          numRemoved += 1;
        }
      });
      toRemove.forEach((i) { if (i>-1 && i<projectileList.length) projectileList.removeAt(i); });
    }
    sun.render(sunViewMatrix);
    clouds.render(viewMatrix);

    tiles.render(viewMatrix);

    particleSprites.render(viewMatrix);
    sprites.render(viewMatrix);
    player.render(passedTime, time);
    projectiles.render(viewMatrix);

    snowSprites.render(bgViewMatrix);

    blankGui.render(bgViewMatrix);
    gui.render(bgViewMatrix);
    window.requestAnimationFrame(render);

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
  return keys[38] || keys[87] ;
}
bool shootPressed() {
  return keys[32];
}
bool reloadingPressed() {
  return keys[16];
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

    if (pos.x > (Game.instance.totalTiles.length~/Game.instance.tileHeight)*16.0) pos.x = 0.0-sprite.w - random.nextInt(100);
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
    if (pos.x > GAME_WIDTH~/GAME_SIZE_SCALE) pos.x = 0.0-sprite.w - random.nextInt(100);
    if (pos.y > GAME_HEIGHT~/GAME_SIZE_SCALE) pos.y = 0.0-sprite.h;
    sprite.x = pos.x;
    sprite.y = pos.y;
  }
}

class Projectile extends BlankObject {
  int index;
  bool destroy = false;
  bool movingLeft = false;
  double speed = 4.0;
  Vector2 drag = new Vector2(0.0000022, 0.094);
  Vector2 vel = new Vector2(0.0, 0.0);
  Vector4 bounds;
  Projectile(this.index, this.movingLeft, this.bounds, Vector2 pos, Sprite sprite) : super(pos, sprite);
  double lastTime = 0.0;
  double horizontalForce = 4.0;
  double heightForce = 2.0;
  void render(double time) {
    if (lastTime == 0) {
      vel.x = (movingLeft ? 0.0-horizontalForce : horizontalForce);
      vel.y = (0.0-heightForce);
      lastTime = time;
    }
    if (vel.y < 9.8) {
      vel.add(new Vector2(0.0, drag.y));
    }
    if (vel.x >= 1.0) {
        vel.x -= drag.x;
    } else if (vel.x <= -1.0) {
       vel.x += drag.x;
    }

    Vector2 newPos = pos.clone().add(vel);
    Int32List collideY = hasCollidedY(newPos);
    Int32List collideX = hasCollidedX(newPos);
    if (collideY.elementAt(0) > -1) {
      vel.y = 0.0;
      destroy = true;
      if (collideX.elementAt(0) > -1) {
        vel.x = 0.0;
        destroy = true;
      }
    } else if (collideX.elementAt(0) > -1) {
      vel.x = 0.0;
      destroy = true;
    } else if (newPos.y >= (Game.instance.totalTiles.length~/Game.instance.tileHeight)*16.0) {
      vel.y = 0.0;
      destroy = true;
    }
    if (vel.y == 0 && vel.x == 0) { destroy = true; }
    if (destroy ) return;
    pos = newPos;
    sprite.x = pos.x;
    sprite.y = pos.y;
  }

  Int32List hasCollidedX(Vector2 newPos) {
    for (int x = 0; x < 2;x++) {
      for (int y = bounds.y.toInt()-1; y < bounds.w-1;y++) {
        int xx = (newPos.x + (x == 0 ? bounds.x+(!movingLeft ? 1 : -1) : bounds.z+(!movingLeft ? 1 : -1))).floor();
        int yy = (newPos.y + y.toDouble()).floor();
        int tileId = Game.instance.getTileAt(xx~/16, yy~/16);
        if (tileId != 0 && !(tileId >= 3 && tileId <= 5)) {
           return new Int32List.fromList([xx, yy]);
        }
      }
    }
    return new Int32List.fromList([-1, -1]);
  }

  Int32List hasCollidedY(Vector2 newPos) {
    for (int y = 0; y < 2;y++) {
      for (int x = bounds.x.toInt(); x < bounds.z;x++) {
        int xx = (newPos.x + x.toDouble()).floor();
        int yy = (newPos.y + (y == 0 ? bounds.y+1 : bounds.w-1)).floor();
        int tileId = Game.instance.getTileAt(xx~/16, yy~/16);
        if (tileId != 0 && !(tileId >= 3 && tileId <= 5)) {
          return new Int32List.fromList([xx, yy]);
        }
      }
    }
    return new Int32List.fromList([-1, -1]);
  }
}
class ParticleAnimation extends BlankObject {
  int index = 0;
  Int16List spriteFrames;
  int spriteIndex = 0;
  bool isFinished = false;
  int delay = 100;
  bool infinite = false;
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
    if (isFinished || (!infinite && spriteIndex > spriteFrames.length/2)) { isFinished = true; return; }
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
