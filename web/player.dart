part of ld31;

class Player extends ArmedEntity {
  Int16List spriteRunningAnims = new Int16List.fromList([0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0]);
  Int16List spriteIdleAnims = new Int16List.fromList([0, 1, 1, 1, 2, 1, 3, 1]);
  Int16List spriteReloadingAnims = new Int16List.fromList([2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 5, 1, 6, 1, 4, 1]);

  Sprite ammoGUI;
  Sprite ammoInner;
  double ammoSpriteWidth = 58.0;
  Sprite healthGUI;
  Sprite healthInner;
  double healthSpriteWidth = 58.0;

  Sprite waveProgressGUI;
  Sprite waveProgressInner;
  double waveProgressSpriteWidth = 186.0;


  Player(int index, Vector2 pos, int width, int height) : super(index, 0, pos, width, height, new Sprite(pos.x, pos.y, width+0.0, height+0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0), new Vector4(3.0, height-16.0, width-4.0, height-2.0), 20, 20, 500.0) {
    ammoGUI = new Sprite(0.0, 0.0, 64.0, 16.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
    ammoInner = new Sprite(4.0, 5.0, ammoSpriteWidth, 9.0, 0.0, 0.0, 74/255, 167/255, 210/255, 1.0);
    Game.instance.addGuiElement(ammoGUI);
    Game.instance.addBlankGuiElement(ammoInner);

    healthGUI = new Sprite(17*16.0 - 12.0, 0.0, 64.0, 16.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0);
    healthInner = new Sprite((17*16.0 - 12.0)+4.0, 4.0, healthSpriteWidth, 9.0, 0.0, 0.0, 210/255, 74/255, 167/255, 1.0);
    Game.instance.addGuiElement(healthGUI);
    Game.instance.addBlankGuiElement(healthInner);

    waveProgressGUI = new Sprite((4.0*16.0) + 3.0, 8.0, 192.0, 16.0, 0.0, 2.0, 1.0, 1.0, 1.0, 1.0);
    waveProgressInner = new Sprite(((4.0*16.0) + 3.0)+4.0, 12.0, waveProgressSpriteWidth, 9.0, 0.0, 0.0, 74/255, 210/255, 167/255, 1.0);
    Game.instance.addGuiElement(waveProgressGUI);
    Game.instance.addBlankGuiElement(waveProgressInner);
    sprite.index = -11;
  }

  void die() {
    super.die();
    Game.instance.failed();
  }
  void onHit() {
    super.onHit();
    AudioController.play("hit");
  }
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

  void collidedX(Int32List location) { }
  void collidedY(Int32List location) { }
  void collidedBoth(Int32List xLocation, Int32List yLocation) { }

  bool moveLeft() {
    return leftPressed() && !reload();
  }
  bool moveRight() {
    return rightPressed() && !reload();
  }

  bool jump() {
    return upPressed() && !reload();
  }

  bool shoot() {
    return shootPressed();
  }

  bool reload() {
    return reloadingPressed();
  }

  void tenMillisInterval() {
    if (spriteIndex % 3 == 0 && isMoving) {
      AudioController.play("walk");
    }
    if (ammoInner != null && ammo <= maxAmmo) {
      ammoInner.w = (ammo/maxAmmo)*ammoSpriteWidth;
      if (reloading && random.nextInt(100)>40 && (getAnimX() >= 5 && getAnimX() <= 8)) {
        AudioController.play("reload");
      }
    }

    if (healthInner != null && health <= maxHealth) {
      healthInner.w = (health/maxHealth)*healthSpriteWidth;
    }

    if (waveProgressInner != null) {
      waveProgressInner.w = ((Game.instance.numKilled/Game.instance.numEnemiesThisWave) * waveProgressSpriteWidth);
    }
  }
  void render(double delta, double time) {
    super.render(delta, time);
    if (reloading) {
      sprite.w = 32.0;
      if (isMovingLeft) sprite.x -= 16.0;
    } else {
      sprite.w = 16.0;
    }
    if (pos.x < Game.instance.activeCoord) {
      Game.instance.switchScene(false);
    } else if (pos.x > (Game.instance.moveToCoord+(GAME_WIDTH~/GAME_SIZE_SCALE))) {
      Game.instance.switchScene(true);
    }
  }
}