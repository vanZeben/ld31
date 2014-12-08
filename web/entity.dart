part of ld31;

abstract class Entity {
  int index;
  final double moveSpeed = 1.0;
  Vector2 pos;
  Vector2 vel = new Vector2(0.0, 0.0);
  Vector2 accel = new Vector2(2.4, 4.8);
  Vector4 bounds;
  int width, height;
  int entityType = 0;
  int stepCount = 0;
  int spriteIndex = 0;
  bool isMoving = false;
  bool isMovingLeft = false;
  bool isOnGround = false;
  int jumpHeight = 6;
  int jumpTime = 2;
  Sprite sprite;
  double lastSpriteUpdateTime = 0.0;
  ParticleAnimation activeMoveAnim;

  int maxHealth = 1;
  int health;
  Sprite healthBar;
  bool destroy = false;

  Entity(this.index, this.entityType, this.pos, this.width, this.height, this.sprite, this.bounds, this.maxHealth) {
    health = maxHealth;
//    healthBar = new Sprite(pos.x, pos.y, 5.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0);
//    Game.instance.addSprite(healthBar);
  }

  double getAnimX();
  double getAnimY();
  double getAnimLength();
  bool jump();
  bool moveLeft();
  bool moveRight();
  void collidedX(Int32List location);
  void collidedY(Int32List location);
  void collidedBoth(Int32List xLocation, Int32List yLocation);
  void tenMillisInterval(){}
  void hitLeftEdge() { vel.x = 0.0; }
  void hitRightEdge() { vel.x = 0.0; }
  void onHit() {
    health-=1;
    if (health <= 0) { die(); }
  }
  void die() {
    destroy = true;
    sprite.a = 0.0;
    sprite = null;
  }

  void updateAI(double delta, time) {
    if (isOnGround && jump()) {
      vel.y = 0.0-jumpHeight;
      isOnGround = false;
    }
    if (moveLeft() && !moveRight()) {
      isMovingLeft = true;
      isMoving = true;
      vel.add(new Vector2(-1.0, 0.0));
      stepCount++;
    } else if (moveRight() && !moveLeft()) {
      isMovingLeft = false;
      isMoving = true;
      vel.add(new Vector2(1.0, 0.0));
      stepCount++;
    } else {
      isMoving = false;
      vel.x = 0.0;
    }

    if (vel.y < 9.8) {
      vel.add(new Vector2(0.0, accel.y*delta));
    }
  }

  void render(double delta, double time) {
    if (destroy) {
      if (sprite != null) {
        sprite.a = 0.0;
        sprite = null;
        healthBar = null;
      }
      return;
    }
    updateAI(delta, time);

    Vector2 newPos = pos.clone().add(vel);
    Int32List collideY = hasCollidedY(pos.clone().add(new Vector2(0.0, vel.y)));
    Int32List collideX = hasCollidedX(pos.clone().add(new Vector2(vel.x, 0.0)));

    if (collideY.elementAt(0) > -1) {
      vel.y = 0.0;
      if (collideX.elementAt(0) > -1) {
        vel.x = 0.0;
        collidedBoth(collideX, collideY);
      } else {
        collidedY(collideY);
      }
      if (!isOnGround) isOnGround = true;
    } else if (collideX.elementAt(0) > -1) {
      vel.x = 0.0;
      collidedX(collideX);
    } else if (newPos.y >= GAME_HEIGHT~/GAME_SIZE_SCALE - height) {
      vel.y = 0.0;
    }

    if (newPos.x <= 0) {
      hitLeftEdge();
    } else if (newPos.x > (allScreens.length*(GAME_WIDTH~/GAME_SIZE_SCALE)) - bounds.z) {
      hitRightEdge();
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
    if (time - lastSpriteUpdateTime > 100) {
      lastSpriteUpdateTime = time;
      spriteIndex += 1;
      tenMillisInterval();
    }
    pos.add(vel);
    sprite.x = pos.x;
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
        activeMoveAnim.pos = pos.clone().add(new Vector2(activeMoveAnim.sprite.flip ? 0.0-width+bounds.x : bounds.z, height-width+0.0));
      }
    }
    if (healthBar != null) {
      healthBar.w = (health/maxHealth)* maxHealth;
      healthBar.x = (healthBar.w)/2 + pos.x;
      healthBar.y = pos.y+8;
    }
  }

  Sprite getSprite() {
    return sprite;
  }

  Int32List hasCollidedX(Vector2 newPos) {
    for (int x = 0; x < 2;x++) {
      int xx = (newPos.x + (x == 0 ? bounds.x+(!isMovingLeft ? 1 : -1) : bounds.z+(!isMovingLeft ? 1 : -1))).floor();
      for (int y = bounds.y.toInt(); y < bounds.w-1;y++) {
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
      int yy = (newPos.y + (y == 0 ? bounds.y+1 : bounds.w-1)).floor();
      for (int x = bounds.x.toInt()+2; x < bounds.z;x++) {
        int xx = (newPos.x + x.toDouble()).floor();
        int tileId = Game.instance.getTileAt(xx~/16, yy~/16);
        if (tileId != 0 && !(tileId >= 3 && tileId <= 5)) {
          return new Int32List.fromList([xx, yy]);
        }
      }
    }
    return new Int32List.fromList([-1, -1]);
  }
}

abstract class ArmedEntity extends Entity {
  int maxAmmo = 20;
  int ammo = 0;
  double reloadRate = 1.0;

  double shotCooldown = 0.0;
  double shotTime = 0.0;
  bool reloading = false;
  double reloadTime = 0.0;

  ArmedEntity(int index, int entityType, Vector2 pos, int width, int height, Sprite sprite, Vector4 bounds, int maxHealth, this.maxAmmo, this.shotCooldown) : super(index, entityType, pos, width, height, sprite, bounds, maxHealth) {
    ammo = maxAmmo;
  }

  bool shoot();
  bool reload();

  void updateAI(double delta, double time) {
    if (isOnGround && reload()) {
      isMoving = false;
      if (time - reloadTime > 1000) {
        ammo += reloadRate.toInt();
        if (ammo > maxAmmo) ammo = maxAmmo;
        reloadTime = time;
        reloading = true;
      }
    } else if (shoot() && ammo > 0 && (time - shotTime > shotCooldown)) {
      double x = pos.x + (isMovingLeft ? 0.0-bounds.x : bounds.x);
      double y = pos.y + bounds.y;
      Projectile proj = new Projectile(
          Game.instance.projectileList.length,
          this,
          isMovingLeft,
          new Vector4(7.0, 7.0, 9.0, 9.0),
          new Vector2(x, y),
          new Sprite(x, y, 16.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0)
      );
      Game.instance.addProjectile(proj);
      shotTime = time;
      ammo--;
    } else {
      reloading = false;
    }
    super.updateAI(delta, time);
  }
}