part of ld31;

class Enemy extends ArmedEntity {
  Int16List spriteRunningAnims = new Int16List.fromList([0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0]);
  Int16List spriteIdleAnims = new Int16List.fromList([0, 1, 1, 1, 2, 1, 3, 1]);
  Int16List spriteReloadingAnims = new Int16List.fromList([2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 5, 1, 6, 1, 4, 1]);

  int movementDir = 0;
  bool moving = false;
  bool jumping = false;
  bool shooting = false;
  bool reloading = false;
  Vector2 targetPos;
  double targetRange = 10.0;
  Enemy(int index, Vector2 pos, int width, int height) : super(index, 1, pos, width, height, new Sprite(pos.x, pos.y, width+0.0, height+0.0, 0.0, 0.0, 0.4, 1.0, 0.0, 0.8), new Vector4(3.0, height-16.0, width-4.0, height-2.0), 1, 20, 500.0);

  double getAnimX() {
    if (reloading) {
      return spriteReloadingAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    } else if (isMoving) {
      return spriteRunningAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    } else {
      return spriteIdleAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    }
  }

  double getAnimY() {
    if (reloading) {
      return spriteReloadingAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    } else if (isMoving) {
      return spriteRunningAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    } else {
      return spriteIdleAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    }
  }

  double getAnimLength() {
    if (reloading) {
      return spriteReloadingAnims.length/2.0;
    } else if (isMoving) {
      return spriteRunningAnims.length/2.0;
    } else {
      return spriteIdleAnims.length/2.0;
    }
  }

  void collidedX(Int32List location) { jumping = true; }
  void collidedY(Int32List location) { }
  void collidedBoth(Int32List xLocation, Int32List yLocation) { jumping = true; }
  void die() {
    super.die();
    AudioController.play("hit");
    Game.instance.numKilled += 1;
    if (Game.instance.numKilled == Game.instance.numEnemiesThisWave) {
      Game.instance.clearedAll();
    }
  }

  bool moveLeft() {
    return (movementDir == 0 && moving) && !reload();
  }
  bool moveRight() {
    return (movementDir == 1 && moving) && !reload();
  }

  bool jump() {
    return jumping && !reload();
  }

  bool shoot() {
    return shooting;
  }

  bool reload() {
    return reloading;
  }

  void hitLeftEdge() {
    super.hitLeftEdge();
    movementDir = 1;
  }
  void hitRightEdge() {
    super.hitRightEdge();
    movementDir = 0;
  }
  void tenMillisInterval() { }


  double getDistToTarget() {
    return ((pos.x - targetPos.x).abs()).toDouble();
  }

  double lastAITime = 0.0;
  double decisionTime = 1000.0;
  void updateAI(double delta, double time) {
    targetPos = Game.instance.player.pos;

    if (getDistToTarget() <= targetRange && (getDistToTarget() > 2) ) {
      shooting = true;
      if (movementDir == 1 && (pos.x - targetPos.x)>0) {
        movementDir = 0;
        moving = false;
      } else if (movementDir == 0 && pos.x - targetPos.x < 0){
        movementDir = 1;
        moving = false;
      }
    }
    if (ammo/maxAmmo < 0.5) {
      reloading = true;
    } else if (ammo/maxAmmo > 0.5) {
      reloading = false;
    }
    if (time - lastAITime > decisionTime) {
      if (random.nextInt(1000) > 300) {
        moving = true;
        movementDir = random.nextInt(2)-1;
      } else {
        moving = false;
      }
      lastAITime = time;
      decisionTime = (random.nextInt(5000) + 2 * 1000).toDouble();
      if (!moving) decisionTime ~/2;
    }

    super.updateAI(delta, time);
    if (jumping) jumping = !jumping;
  }

  void render(double delta, double time) {
    super.render(delta, time);
    if (sprite == null) { return; }
    if (reloading) {
      sprite.w = 32.0;
      if (isMovingLeft) sprite.x -= 16.0;
    } else {
      sprite.w = 16.0;
    }
  }
}