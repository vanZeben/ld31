part of ld31;

class Player {
  final double moveSpeed = 1.0;
  Vector2 pos;
  Vector2 vel = new Vector2(0.0, 0.0);
  Vector2 accel = new Vector2(2.4, 0.68);

  int stepCount = 0;
  bool isMoving = false;
  bool isMovingLeft = false;
  bool isOnGround = false;
  int slideSpeed = 20;
  int jumpHeight = 8;
  int jumpTime = 2;
  Sprite sprite;
  Player(this.pos) {
    sprite = new Sprite(0.0, 0.0, 16.0, 32.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0);
  }

  Sprite getSprite() {
    return sprite;
  }

  void render(double time) {
    if (upPressed() && isOnGround) {
      vel.y = 0.0-jumpHeight;
      isOnGround = false;
    }
    if (leftPressed() && !rightPressed()) {
      isMovingLeft = true;
      isMoving = true;
      vel.add(new Vector2(-1.0, 0.0));
      stepCount++;
    } else if (rightPressed() && !leftPressed()) {
      isMovingLeft = false;
      isMoving = true;
      vel.add(new Vector2(1.0, 0.0));
      stepCount++;
    } else {
      isMoving = false;
      vel.x = 0.0;
    }

    vel.add(new Vector2(0.0, accel.y));
    if (pos.clone().add(vel).y >= 150-getBoundY()) {
      vel.y = 0.0;
      isOnGround = true;
    } else {
      isOnGround = false;
    }
    if (pos.clone().add(vel).x < -8) {
      vel.x = 0.0;
    } else if (pos.clone().add(vel).x > GAME_WIDTH-8) {
      vel.x = 0.0;
    }

    if (isMoving) {
      if (vel.x >= 1.0) {
        vel.x = accel.x;
      } else if (vel.x <= -1.0) {
        vel.x = 0.0 - accel.x;
      }
    }
    pos.add(vel);
    sprite.x = pos.x;
    sprite.y = pos.y;
    sprite.flip = isMovingLeft;
    vel.x = 0.0;
  }
  int getBoundY() {
    return 26;
  }
}