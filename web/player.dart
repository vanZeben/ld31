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
  Int16List spriteReloadingAnims = new Int16List.fromList([2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 5, 1, 6, 1, 4, 1]);
  bool npcControlled = false;
  int stamina = 20;
  int maxStamina = 20;
  Sprite ammoGUI;
  Sprite ammoInner;
  double ammoSpriteWidth = 58.0;
  int ammo = 20;
  int maxAmmo = 20;

  Player(this.pos, this.width, this.height) {
    bounds = new Vector4(3.0, height-16.0, width-4.0, height+0.0);
    sprite = new Sprite(0.0, 0.0, width+0.0, height+0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
    ammoGUI = new Sprite(0.0, 0.0, 64.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
    ammoInner = new Sprite(4.0, 5.0, ammoSpriteWidth, 9.0, 0.0, 0.0, 74/255, 167/255, 210/255, 1.0);
    Game.instance.addGuiElement(ammoGUI);
    Game.instance.addBlankGuiElement(ammoInner);
  }

  Sprite getSprite() {
    return sprite;
  }
  double getAnimX() {
    if (pickingUpSnow) {
      return spriteReloadingAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    } else if (isMoving) {
      return spriteRunningAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    } else {
      return spriteIdleAnims.elementAt(((spriteIndex%getAnimLength())*2.0).toInt())+0.0;
    }
  }

  double getAnimY() {
    if (pickingUpSnow) {
      return spriteReloadingAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    } else if (isMoving) {
      return spriteRunningAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    } else {
      return spriteIdleAnims.elementAt((((spriteIndex%getAnimLength())*2.0)+1).toInt())+0.0;
    }
  }

  double getAnimLength() {
    if (pickingUpSnow) {
      return spriteReloadingAnims.length/2.0;
    } else if (isMoving) {
      return spriteRunningAnims.length/2.0;
    } else {
      return spriteIdleAnims.length/2.0;
    }
  }
  double lastSpriteUpdateTime = 0.0;
  bool jump = false;
  bool movingDir = false;
  ParticleAnimation activeMoveAnim;
  double shotDelay = 0.0;
  bool pickingUpSnow = false;
  double reloadTime = 0.0;
  void render(double delta, double time) {
    if (reloadingPressed()) {
      pickingUpSnow = true;
      isMoving = false;
      if (time - reloadTime > 1000) {
        ammo += 2;
        if (ammo > maxAmmo) ammo = maxAmmo;
        reloadTime = time;
      }
    } else {
      pickingUpSnow = false;
      if ((shootPressed()) && time - shotDelay > 250 && ammo > 0) {
        double x = pos.x + (isMovingLeft ? 0.0-bounds.x : bounds.x);
        double y = pos.y + bounds.y;
        Projectile proj = new Projectile(Game.instance.projectileList.length, isMovingLeft, new Vector4(7.0, 7.0, 9.0, 9.0), new Vector2(x, y), new Sprite(x, y, 16.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0));
        Game.instance.addProjectile(proj);
        shotDelay = time;
        ammo--;
      }
      if ((upPressed() || jump) && isOnGround /*&& stamina >= 10*/) {
        vel.y = 0.0-jumpHeight;
        isOnGround = false;
        jump = false;
      }
      if ((leftPressed() && !rightPressed()) || (npcControlled &&(pos.x > 0 && movingDir && !Game.instance.isMoving))) {
        isMovingLeft = true;
        isMoving = true;
        vel.add(new Vector2(-1.0, 0.0));
        stepCount++;
      } else if ((rightPressed() && !leftPressed()) || (npcControlled && (pos.x < (((Game.instance.totalTiles.length~/Game.instance.tileHeight)-1) * 16)  - bounds.z && !movingDir && !Game.instance.isMoving))) {
        isMovingLeft = false;
        isMoving = true;
        vel.add(new Vector2(1.0, 0.0));
        stepCount++;
      } else {
        isMoving = false;
        vel.x = 0.0;
      }
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
        if (isOnGround && npcControlled) {
          jump = true;
        }
      }
      if (!isOnGround) isOnGround = true;
    } else if (collideX.elementAt(0) > -1) {
      vel.x = 0.0;
    } else if (newPos.y >= GAME_HEIGHT~/GAME_SIZE_SCALE - height) {
      vel.y = 0.0;
    }

    if (newPos.x <= 0) {
      vel.x = 0.0;
    } else if (newPos.x > (allScreens.length*(GAME_WIDTH~/GAME_SIZE_SCALE)) - bounds.z) {
      vel.x = 0.0;
    } else {
      if (newPos.x < Game.instance.activeCoord) {
        Game.instance.switchScene(false);
        if (npcControlled) movingDir = false;
      } else if (newPos.x > (Game.instance.moveToCoord+(GAME_WIDTH~/GAME_SIZE_SCALE))) {
        Game.instance.switchScene(true);
        if (npcControlled) movingDir = true;
      }
    }

    if (isMoving) {
      if (vel.x >= 1.0) {
        vel.x = accel.x;
        if (isOnGround) {
          if (activeMoveAnim != null ) {
            if (!activeMoveAnim.sprite.flip) {
              activeMoveAnim.isFinished = true;
            }
          } else {
            Sprite moveSprite =  new Sprite(0.0, 0.0, 16.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
            moveSprite.flip = true;
            activeMoveAnim = new ParticleAnimation(Game.instance.particles.length, pos.clone(), moveSprite, new Int16List.fromList([0, 8, 1, 8, 2, 8, 1, 8]), 50);
            activeMoveAnim.infinite = true;
            Game.instance.addParticleAnim(activeMoveAnim);
          }
        }
      } else if (vel.x <= -1.0) {
        vel.x = 0.0 - accel.x;
        if (isOnGround) {
          if (activeMoveAnim != null) {
            if (activeMoveAnim.sprite.flip) {
              activeMoveAnim.isFinished = true;
            }
          } else {
            Sprite moveSprite =  new Sprite(0.0, 0.0, 16.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
            moveSprite.flip = false;
            activeMoveAnim = new ParticleAnimation(Game.instance.particles.length, pos.clone(), moveSprite, new Int16List.fromList([0, 8, 1, 8, 2, 8, 1, 8]), 50);
            activeMoveAnim.infinite = true;
            Game.instance.addParticleAnim(activeMoveAnim);
          }
        }
      }
    }
    if (pickingUpSnow) {
      sprite.w = 32.0;
    } else {
      sprite.w = 16.0;
    }
    if (time - lastSpriteUpdateTime > 100) {
      lastSpriteUpdateTime = time;
      spriteIndex += 1;
      if (spriteIndex % 3 == 0 && isMoving) {
        AudioController.play("walk");
      }
      if (ammoInner != null && ammo <= maxAmmo) {
        ammoInner.w = (ammo/maxAmmo)*ammoSpriteWidth;
        if (pickingUpSnow && random.nextInt(100)>40 && (getAnimX() >= 5 && getAnimX() <= 8)) {
          AudioController.play("walk");
        }
      }
    }
    pos.add(vel);
    sprite.x = pos.x;
    if (pickingUpSnow && isMovingLeft) {
      sprite.x -= 16.0;
    }
    sprite.y = pos.y;
    sprite.flip = isMovingLeft;
    sprite.u = getAnimX();
    sprite.v = getAnimY();
    vel.x = 0.0;
    if (activeMoveAnim != null) {
      if (!isMoving) {
        activeMoveAnim.isFinished = true;
        activeMoveAnim.infinite = false;
        activeMoveAnim = null;
      } else {
        activeMoveAnim.pos = pos.clone().add(new Vector2(activeMoveAnim.sprite.flip ? -16.0+bounds.x : bounds.z, height-16.0));
      }
    }
  }

  Int32List hasCollidedX(Vector2 newPos) {
    for (int x = 0; x < 2;x++) {
      for (int y = bounds.y.toInt()-1; y < bounds.w-1;y++) {
        int xx = (newPos.x + (x == 0 ? bounds.x+(!isMovingLeft ? 1 : -1) : bounds.z+(!isMovingLeft ? 1 : -1))).floor();
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