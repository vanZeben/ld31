part of ld31;

class Player {
  final double moveSpeed = 1.0;
  Vector2 pos;
  Vector2 vel = new Vector2(0.0, 0.0);
  Vector2 accel = new Vector2(2.4, 4.8);
  Vector4 bounds;
  int width, height;

  int stepCount = 0;
  int spriteIndex = 0;
  bool isMoving = false;
  bool isMovingLeft = false;
  bool isOnGround = false;
  int slideSpeed = 20;
  int jumpHeight = 6;
  int jumpTime = 2;
  Sprite sprite;
  Int16List spriteRunningAnims = new Int16List.fromList([0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0]);
  Int16List spriteIdleAnims = new Int16List.fromList([0, 1, 1, 1, 2, 1, 3, 1]);
  Player(this.pos, this.width, this.height) {
    bounds = new Vector4(3.0, height-16.0, width-4.0, height+0.0);
//    bounds = new Vector4(0.0, 0.0, width+0.0, height+0.0);
    sprite = new Sprite(0.0, 0.0, width+0.0, height+0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
  }

  Sprite getSprite() {
    return sprite;
  }
  double getAnimX() {
    if (isMoving) {
      return spriteRunningAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    } else {
      return spriteIdleAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    }
  }

  double getAnimY() {
    if (isMoving) {
      return spriteRunningAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    } else {
      return spriteIdleAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    }
  }

  double getAnimLength() {
    if (isMoving) {
      return spriteRunningAnims.length/2.0;
    } else {
      return spriteIdleAnims.length/2.0;
    }
  }
  double lastSpriteUpdateTime = 0.0;
  bool jump = false;
//  bool movingDir = false;
  ParticleAnimation activeMoveAnim;
  void render(double delta, double time) {
    if ((upPressed() || jump) && isOnGround) {
      vel.y = 0.0-jumpHeight;
      isOnGround = false;
      jump = false;
    }
    if ((leftPressed() && !rightPressed()) /*|| (pos.x > 0 && movingDir)*/) {
      isMovingLeft = true;
      isMoving = true;
      vel.add(new Vector2(-1.0, 0.0));
      stepCount++;

    } else if ((rightPressed() && !leftPressed()) /* || (pos.x < GAME_WIDTH~/GAME_SIZE_SCALE-width&& !movingDir)*/) {
      isMovingLeft = false;
      isMoving = true;
      vel.add(new Vector2(1.0, 0.0));
      stepCount++;
    } else {
      isMoving = false;
      vel.x = 0.0;
      activeMoveAnim = null;
    }
    if (vel.y < 9.8) {
      vel.add(new Vector2(0.0, accel.y*delta));
    }

    Vector2 newPos = pos.clone().add(vel);

    Int32List collideY = hasCollidedY(newPos);
    Int32List collideX = hasCollidedX(newPos);
    if (collideY.elementAt(0) > -1) {
      vel.y = 0.0;
      if (collideX.elementAt(0) > -1) {
        vel.x = 0.0;
        if (isOnGround) {
          jump = true;
        }
      }
      if (!isOnGround) isOnGround = true;
    } else if (collideX.elementAt(0) > -1) {
      vel.x = 0.0;
    }

    if (newPos.x < 0.0) {
      vel.x = 0.0;
    } else if (newPos.x > (GAME_WIDTH~/GAME_SIZE_SCALE) - width) {
      vel.x = 0.0;
    }

    if (isMoving) {
      if (vel.x >= 1.0) {
        vel.x = accel.x;
        if (activeMoveAnim == null) {
          Sprite moveSprite =  new Sprite(0.0, 0.0, 16.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
          moveSprite.flip = true;
          activeMoveAnim = new ParticleAnimation(0, pos.clone(), moveSprite, new Int16List.fromList([0, 8, 1, 8, 2, 8, 1, 8]), 50);
          activeMoveAnim.index = Game.instance.addParticleAnim(activeMoveAnim);
        }
      } else if (vel.x <= -1.0) {
        vel.x = 0.0 - accel.x;
        if (activeMoveAnim == null) {
          Sprite moveSprite =  new Sprite(0.0, 0.0, 16.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
          moveSprite.flip = false;
          activeMoveAnim = new ParticleAnimation(0, pos.clone(), moveSprite, new Int16List.fromList([0, 8, 1, 8, 2, 8, 1, 8]), 50);
          activeMoveAnim.index = Game.instance.addParticleAnim(activeMoveAnim);
        }
      }
    }
    if (time - lastSpriteUpdateTime > 100) {
      lastSpriteUpdateTime = time;
      spriteIndex += 1;
    }
    pos.add(vel);
    sprite.x = pos.x;
    sprite.y = pos.y;
    sprite.flip = isMovingLeft;
    sprite.u = getAnimX();
    sprite.v = getAnimY();
    vel.x = 0.0;
    if (activeMoveAnim != null) {
      activeMoveAnim.pos = pos.clone().add(new Vector2(activeMoveAnim.sprite.flip ? -16.0+bounds.x : bounds.z, height-16.0));
    }
  }

  Int32List hasCollidedX(Vector2 newPos) {
    for (int x = 0; x < 2;x++) {
      for (int y = bounds.y.toInt()-1; y < bounds.w-1;y++) {
        int xx = (newPos.x + (x == 0 ? bounds.x+(!isMovingLeft ? 1 : -1) : bounds.z+(!isMovingLeft ? 1 : -1))).floor();
        int yy = (newPos.y + y.toDouble()).floor();
        if (Game.instance.getTileAt(xx~/16, yy~/16) != 0) {
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
        if (Game.instance.getTileAt(xx~/16, yy~/16) != 0) {
          return new Int32List.fromList([xx, yy]);
        }
      }
    }
    return new Int32List.fromList([-1, -1]);
  }
}