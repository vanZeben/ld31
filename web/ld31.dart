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
part 'enemy.dart';
part 'entity.dart';

GL.RenderingContext gl;
Random random = new Random();

int GAME_WIDTH = 650;
int GAME_HEIGHT = 488;
int GAME_SIZE_SCALE = 2;
List<bool> keys = new List<bool>(256);
Texture bgSheet;

List<Screen> allScreens = new List<Screen>();
Audio audio;
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
  bool paused = false;
  static Game instance;
  Matrix4 bgViewMatrix;
  Matrix4 viewMatrix, sunViewMatrix;
  CanvasElement canvas;
  Sprites entitySprites, overlaySprites, sprites, tiles, clouds, snowSprites, particleSprites, guiSprite, groundSprites, skyBox, gui, blankGui, projectiles, guiSprites;

  List<Sprite> spriteList = new List<Sprite>();
  List<BlankObject> blankObjectList = new List<BlankObject>();
  List<ParticleAnimation> particles = new List<ParticleAnimation>();
  List<Projectile> projectileList = new List<Projectile>();
  Sprite bg;
  Player player;
  List<Entity> entities = new List<Entity>();
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
    canvas.onMouseDown.listen((e) {
      if (paused) {
        paused = !paused;
        pauseSprite.a = 0.0;
        window.requestAnimationFrame(render);
      }
      if (died) {
        died = false;
        diedSprite.a = 0.0;
        init();
      }
    });
    window.onBlur.listen((e) {
      for (int i=0; i <256;i++) keys[i] = false;
      paused = true;
      pauseSprite.a = 1.0;
    });
    window.onFocus.listen((e) {
      paused = false;
      window.requestAnimationFrame(render);
      pauseSprite.a = 0.0;
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
    if (activeSceneId < 0) activeSceneId = 0;
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

  Sprite tree;
  int wave = 1;
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
      clouds = new Sprites(testShader, blankSheet.texture);
      groundSprites = new Sprites(testShader, blankSheet.texture);
      snowSprites = new Sprites(testShader, blankSheet.texture);
      skyBox = new Sprites(testShader, skyboxSheet.texture);
      sun = new Sprites(testShader, spriteSheet.texture);
      gui = new Sprites(testShader, guiSheet.texture);
      blankGui = new Sprites(testShader, blankSheet.texture);
      sprites = new Sprites(testShader, spriteSheet.texture);
      entitySprites = new Sprites(testShader, spriteSheet.texture);
      guiSprite = new Sprites(testShader, blankSheet.texture);
      guiSprites = new Sprites(testShader, spriteSheet.texture);
      particleSprites = new Sprites(testShader, spriteSheet.texture);
      projectiles = new Sprites(testShader, projectileSheet.texture);
      overlaySprites = new Sprites(testShader, guiSheet.texture);
      for (int y = tileHeight-1; y > -1;y--) {
        for (int x = 0; x < (totalTiles.length~/tileHeight); x++) {
          int tileId = getTileAt(x, y);
          tiles.addSprite(new Sprite(x*16.0, y*16.0 +(tileId >= 3 && tileId <= 5 ? 2 : 0), 16.0, 16.0, tileId+0.0, 4.0, 1.0, 1.0, 1.0, 1.0));
        }
      }
      init();
    });
  }
  int numEnemiesThisWave = 6;
  Sprite pauseSprite;
  Sprite nextWave;
  Sprite diedSprite;
  Sprite tree2;
  void init() {
      clouds.clear();
      blankObjectList.clear();
      groundSprites.clear();
      skyBox.clear();
      sun.clear();
      player = null;
      sprites.clear();
      tree = null;
      guiSprites.clear();
      snowSprites.clear();

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

      groundSprites.addSprite(new Sprite(0.0, tileHeight*16.0, GAME_WIDTH+0.0,(GAME_HEIGHT - (tileHeight*16.0~/GAME_SIZE_SCALE)).toDouble(), 0.0, 0.0, 53/255, 96/255, 36/255, 1.0));

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

      skyBox.addSprite(new Sprite(0.0, 0.0, GAME_WIDTH+0.0, GAME_HEIGHT+0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0));

      sun.addSprite(new Sprite(-16.0, -16.0, 32.0, 32.0, 1.0, 3.0, 1.0, 1.0, 1.0, 1.0));

      player = new Player(entitySprites.getSize(),new Vector2(10.0, 10.0), 16, 32);

      sprites.addSprite(new Sprite(18*16.0, 7*16.0+2.0, 16.0, 32.0, 6.0, 0.0, 1.0, 1.0, 1.0, 1.0));
      sprites.addSprite(new Sprite(59*16.0, 7*16.0+2.0, 16.0, 32.0, 6.0, 0.0, 1.0, 1.0, 1.0, 1.0));
      tree2 = new Sprite(50*16.0, 2*16.0+2, 48.0, 96.0, 4.0, 1.0, 1.0, 1.0, 1.0, 1.0);
      tree = new Sprite(13*16.0, 3*16.0+2, 48.0, 96.0, 4.0, 1.0, 1.0, 1.0, 1.0, 1.0);
      sprites.addSprite(tree);
      sprites.addSprite(tree2);
      guiSprites.addSprite(new Sprite(1*16.0, 12*16.0, 32.0, 32.0, 0.0, 7.0, 1.0, 1.0, 1.0, 1.0));
      guiSprites.addSprite(new Sprite(5*16.0, 12*16.0, 32.0, 32.0, 1.0, 7.0, 1.0, 1.0, 1.0, 1.0));
      guiSprites.addSprite(new Sprite(9*16.0, 12*16.0, 32.0, 32.0, 2.0, 7.0, 1.0, 1.0, 1.0, 1.0));
      guiSprites.addSprite(new Sprite(8*16.0-8.0, 10*16.0-4.0, 144.0, 16.0, 0.0, 11.0, 1.0, 1.0, 1.0, 1.0));
      guiSprites.addSprite(new Sprite(4*16.0-8.0, 9*16.0-4.0, 144.0, 16.0, 0.0, 12.0, 1.0, 1.0, 1.0, 1.0));
      guiSprites.addSprite(new Sprite(2*16.0-0.8, 14*16.0, 144.0, 16.0, 0.0, 13.0, 1.0, 1.0, 1.0, 1.0));
      pauseSprite = new Sprite(125.0, 100.0, 64.0, 32.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0);
      overlaySprites.addSprite(pauseSprite);
      nextWave = new Sprite(125.0, 100.0, 48.0, 32.0, 3.0, 0.0, 1.0, 1.0, 1.0, 0.0);
      overlaySprites.addSprite(nextWave);
      diedSprite = new Sprite(125.0, 100.0, 48.0, 48.0, 4.0, 0.0, 1.0, 1.0, 1.0, 0.0);
      overlaySprites.addSprite(diedSprite);
      spawnEnemies();
      window.requestAnimationFrame(render);
  }

  void clear() {
    entities.clear();
    entitySprites.clear();
    particles.clear();
    particleSprites.clear();
    projectileList.clear();
    projectiles.clear();
  }
  void spawnEnemies() {
    clear();
    int offs = (allScreens.length*(GAME_WIDTH~/GAME_SIZE_SCALE))~/3;
    for (int i = 0; i < wave*2;i++) {
      Enemy p = new Enemy(entitySprites.getSize(), new Vector2(random.nextInt(offs*2).toDouble()+offs, 0.0), 16, 32);
      entities.add(p);
    }
    numEnemiesThisWave = wave*2;
    entities.add(player);
    entities.forEach((e) {
        entitySprites.addSprite(e.getSprite());
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

  void addSprite(Sprite sprite) {
    guiSprite.addSprite(sprite);
  }

  double lastTime = -1.0;
  double xOffs = 0.0, yOffs = 0.0;
  double scale = 0.0;
  double scaleSpeed = 0.01;
  bool moveUp = true;
  bool scaling = false;
  double offs = 0.0;
  double movingCooldown = 0.0;
  double introDelay = 2000.0;
  double lastTreeUpdateTime = 0.0;
  int waveDelay = 0;
  double lastWaveTime = 0.0;
  void clearedAll() {
    AudioController.play("nextLevel");
    numTotalKilled += numKilled;
    numKilled = 0;
    wave++;
    resetView();
    player.pos = new Vector2(0.0, 20.0);
  }
  int numTotalKilled = 0;
  int numKilled = 0;
  bool resettingView = false;
  void resetView() {
    moveToCoord = 0.0;
    activeSceneId = 0;
    resettingView = true;
  }

  bool died = false;
  void failed() {
    AudioController.play("death");
    died = true;
    numTotalKilled = 0;
    numKilled = 0;
    wave = 1;
    resetView();
    player = null;
    diedSprite.a = 1.0;
  }

  void render(double time) {
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(1.0, 1.0, 1.0, 1.0);

    gl.enable(GL.BLEND);
    gl.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
    gl.clear(GL.DEPTH_BUFFER_BIT | GL.COLOR_BUFFER_BIT);

    if (!paused && !died) {
      if (introDelay != -1 && time > introDelay) {
         AudioController.play("amb");
         introDelay = time+(14.6 * 1000.0)+0.0;
      }
      if (time - lastTreeUpdateTime > 500) {
        double priorPos = tree.u;
        if (priorPos == 4.0) {
          tree.u = 3.0;
        } else {
          tree.u = 4.0;
        }
        priorPos = tree2.u;
        if (priorPos == 4.0) {
          tree2.u = 3.0;
        } else {
          tree2.u = 4.0;
        }
        lastTreeUpdateTime = time;
      }

      if (lastTime==-1.0) lastTime = time;
      double passedTime = time-lastTime;
      if (passedTime>0.1) passedTime = 0.1;
      if (passedTime<0.0) passedTime = 0.0;
      offs += passedTime;

      if (resettingView) {
        if (activeCoord > moveToCoord){
           viewMatrix.translate(2.0, 0.0, 0.0);
           activeCoord -= 2.0;
           isMoving = true;
           if (nextWave.a < 1.0 && !died) nextWave.a = 1.0;
        } else {
          isMoving = false;
          resettingView = false;
          if (nextWave.a > 0.0 && !died) nextWave.a = 0.0;
          spawnEnemies();
        }
      } else {
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
      }

      if (isMoving && time - movingCooldown >= 1000) {
        isMoving = false;
      }
      sunViewMatrix.translate(sin(time*0.0008),0.0- (cos(time*0.0008)), 0.0);
      sunViewMatrix.rotateZ((sin(time*0.0008) * cos(time*0.0008))/200);

      skyBox.render(bgViewMatrix);
      blankObjectList.forEach((obj) { obj.render(time); });

      if (!resettingView) {
        if (particles.length > 0) {
          List<ParticleAnimation> tmpProjectiles = new List<ParticleAnimation>();
          for (int i =0 ; i < particles.length;i++) {
            tmpProjectiles.add(particles.elementAt(i));
          }
          tmpProjectiles.forEach((part) {
            part.render(time);
            int index = part.index;
            if (part.isComplete()) {
              particleSprites.removeSprite(part.sprite.index);
              if (part.index >= 0  && part.index < particles.length) {
                particles.removeAt(part.index);
              }
              for (int i = 0; i < particles.length;i++) {
                particles.elementAt(i).index = i;
              }
              for (int i = 0; i < particleSprites.sprites.length;i++) {
                particles.elementAt(i).sprite.index = i;
              }
            }
          });
          tmpProjectiles.clear();
        }

        if (projectileList.length > 0) {
          List<Projectile> tmpProjectiles = new List<Projectile>();
          for (int i =0 ; i < projectileList.length;i++) {
            tmpProjectiles.add(projectileList.elementAt(i));
          }
          tmpProjectiles.forEach((part) {
            part.render(time);
            if (part.destroy) {
              Sprite aSprite = new Sprite(0.0, 0.0, 16.0, 16.0, 0.0, 9.0, 1.0, 1.0, 1.0, 1.0);
              aSprite.flip = !part.movingLeft;
              ParticleAnimation anim = new ParticleAnimation(particles.length, part.pos, aSprite, new Int16List.fromList([0, 9, 1, 9, 2, 9]), 50);
              addParticleAnim(anim);
              projectiles.removeSprite(part.sprite.index);
              if (part.index >= 0  && part.index < projectileList.length) {
                projectileList.removeAt(part.index);
              }

              for (int i =0; i < projectileList.length;i++) {
                projectileList.elementAt(i).index = i;
              }
              for (int i = 0; i < projectiles.sprites.length;i++) {
                projectileList.elementAt(i).sprite.index = i;
              }
            }
          });
          tmpProjectiles.clear();
        }
      }

      sun.render(sunViewMatrix);
      clouds.render(viewMatrix);

      tiles.render(viewMatrix);
      groundSprites.render(bgViewMatrix);
      particleSprites.render(viewMatrix);
      sprites.render(viewMatrix);
      if (!resettingView) {
        entities.forEach((e){e.render(passedTime, time);});
        entitySprites.render(viewMatrix);
      }

      guiSprite.render(viewMatrix);
      projectiles.render(viewMatrix);

      guiSprites.render(viewMatrix);
      blankGui.render(bgViewMatrix);
      gui.render(bgViewMatrix);
      snowSprites.render(bgViewMatrix);

      overlaySprites.render(bgViewMatrix);

      window.requestAnimationFrame(render);
    } else {
      overlaySprites.render(bgViewMatrix);
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
  Entity shooter;
  bool destroy = false;
  bool movingLeft = false;
  double speed = 2.0;
  Vector2 drag = new Vector2(0.0000022, 0.094);
  Vector2 vel = new Vector2(0.0, 0.0);
  Vector4 bounds;
  bool soundPlayed = false;
  Projectile(this.index, this.shooter, this.movingLeft, this.bounds, Vector2 pos, Sprite sprite) : super(pos, sprite);
  double lastTime = 0.0;
  double horizontalForce = 4.0;
  double heightForce = 2.0;
  void render(double time) {
    if (lastTime == 0) {
      vel.x = (movingLeft ? 0.0-horizontalForce : horizontalForce);
      vel.y = (0.0-heightForce);
      lastTime = time;
      if (shooter.entityType == 0) AudioController.play("throw");
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
    Entity e = hasCollideEntity(newPos);
    if (e != null) {
      destroy = true;
      e.onHit();
    } else {
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
    }
    if (vel.y == 0 && vel.x == 0) { destroy = true; }
    if (destroy) {
//      if (sound && !soundPlayed) { AudioController.play("hit"); soundPlayed = true; }
      return;
    }
    pos = newPos;
    sprite.x = pos.x;
    sprite.y = pos.y;
  }

  Entity hasCollideEntity(Vector2 newPos) {
    Entity ent = null;
    Game.instance.entities.forEach((e) {
      if (e.entityType == shooter.entityType || e.sprite == null) { return; }
      for (int x = bounds.x.toInt(); x < bounds.z;x++) {
        for (int y = bounds.y.toInt()-1; y < bounds.w-1;y++) {
          int xx = (newPos.x + (x == 0 ? bounds.x+(!movingLeft ? 1 : -1) : bounds.z+(!movingLeft ? 1 : -1))).floor();
          int yy = (newPos.y + y.toDouble()).floor();
          if (e.sprite.x+e.bounds.x <= xx && xx <= e.sprite.x + e.bounds.z) {
            if (e.sprite.y+e.bounds.y <= yy && yy <= e.sprite.y +e.bounds.w) {
              ent = e;
            }
          }
        }
      }
    });
    return ent;
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
  String toString() {
    return index.toString();
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

  String toString() {
    return index.toString();
  }
}


void main() {
  new Game();
}
