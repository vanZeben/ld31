part of ld31;

class Sprites {
  static const int BYTES_PER_FLOAT = 4;

  static const int FLOATS_PER_VERTEX = 8;
  static const int MAX_VERTICES = 65536;
  static const int MAX_SPRITES = 65536~/4;

  List<Sprite> sprites = new List<Sprite>();
  Shader shader;
  GL.Texture texture;
  GL.Buffer vertexBuffer, indexBuffer;
  bool built = false;
  int posLocation, rgbLocation, uvLocation;
  GL.UniformLocation viewMatrixLocation;
  Float32List vertexData = new Float32List(MAX_VERTICES*FLOATS_PER_VERTEX);
  Sprites(this.shader, this.texture) {
    shader.use();
    vertexBuffer = gl.createBuffer();
    gl.bindBuffer(GL.ARRAY_BUFFER, vertexBuffer);
    gl.bufferDataTyped(GL.ARRAY_BUFFER, vertexData, GL.DYNAMIC_DRAW);

    Int16List indexData = new Int16List(MAX_SPRITES*6);
    for (int i = 0; i < MAX_SPRITES;i++) {
      int offs = i*4;
      indexData.setAll(i*6, [offs+0, offs+1, offs+2, offs+0, offs+2, offs+3]);
    }

    indexBuffer = gl.createBuffer();
    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, indexBuffer);
    gl.bufferDataTyped(GL.ELEMENT_ARRAY_BUFFER, indexData, GL.STATIC_DRAW);

    posLocation = gl.getAttribLocation(shader.program, "a_pos");
    uvLocation = gl.getAttribLocation(shader.program, "a_uv");
    rgbLocation = gl.getAttribLocation(shader.program, "a_col");
    viewMatrixLocation = gl.getUniformLocation(shader.program, "u_viewMatrix");
  }

  void removeSprite(int index) {
    sprites.removeAt(index);
  }

  void addSprite(Sprite sprite) {
    sprites.add(sprite);
  }

  void render(Matrix4 viewMatrix) {
    shader.use();
    gl.bindTexture(GL.TEXTURE_2D, texture);
    gl.bindBuffer(GL.ARRAY_BUFFER, vertexBuffer);

    int toReplace = sprites.length;
    if (toReplace>MAX_SPRITES) toReplace = MAX_SPRITES;
    for (int i =0; i<toReplace;i++) {
      sprites[i].set(vertexData,  i*FLOATS_PER_VERTEX*4);
    }

    gl.bufferSubDataTyped(GL.ARRAY_BUFFER, 0, vertexData.sublist(0, toReplace*FLOATS_PER_VERTEX*4) as Float32List);
    gl.uniformMatrix4fv(viewMatrixLocation, false, viewMatrix.storage);
    gl.enableVertexAttribArray(posLocation);
    gl.enableVertexAttribArray(uvLocation);
    gl.enableVertexAttribArray(rgbLocation);
    gl.bindBuffer(GL.ARRAY_BUFFER, vertexBuffer);
    gl.vertexAttribPointer(posLocation, 2, GL.FLOAT, false, FLOATS_PER_VERTEX*BYTES_PER_FLOAT, 0*BYTES_PER_FLOAT);
    gl.vertexAttribPointer(uvLocation, 2, GL.FLOAT, false, FLOATS_PER_VERTEX*BYTES_PER_FLOAT, 2*BYTES_PER_FLOAT);
    gl.vertexAttribPointer(rgbLocation, 4, GL.FLOAT, false, FLOATS_PER_VERTEX*BYTES_PER_FLOAT, 4*BYTES_PER_FLOAT);

    gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, indexBuffer);
    gl.drawElements(GL.TRIANGLES, sprites.length*6, GL.UNSIGNED_SHORT, 0);
  }
  int getSize() {
    return sprites.length;
  }
}

class Sprite {
  double x, y;
  double w, h;
  double u, v;
  bool flip = false;
  double r, g, b, a;
  int index;

  Sprite(this.x, this.y, this.w, this.h, this.u, this.v, this.r, this.g, this.b, this.a);
  void set(Float32List data, int offs) {
    if (!flip) {
      data.setAll(offs, [
        x+0, y+0, (u*w)+0, (v*h)+0, r, g, b, a,
        x+w, y+0, (u*w)+w, (v*h)+0, r, g, b, a,
        x+w, y+h, (u*w)+w, (v*h)+h, r, g, b, a,
        x+0, y+h, (u*w)+0, (v*h)+h, r, g, b, a,
      ]);
    } else {
      data.setAll(offs, [
        x+0, y+0, (u*w)+w, (v*h)+0, r, g, b, a,
        x+w, y+0, (u*w)+0, (v*h)+0, r, g, b, a,
        x+w, y+h, (u*w)+0, (v*h)+h, r, g, b, a,
        x+0, y+h, (u*w)+w, (v*h)+h, r, g, b, a,
      ]);
    }
  }
}