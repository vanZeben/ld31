part of ld31;

class Texture {
  static List<Texture> _all = new List<Texture>();
  static void loadAll() {
    _all.forEach((texture)=>texture.load());
  }

  String url;
  Texture(this.url) {
    _all.add(this);
  }
  GL.Texture texture;

  load() {
    ImageElement img = new ImageElement();
    texture = gl.createTexture();
    img.onLoad.listen((e) {
      gl.bindTexture(GL.TEXTURE_2D, texture);
      gl.texImage2DImage(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, img);
      gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
      gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
    });
    img.src = url;
  }
}