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
  ImageElement img;
  Uint8List pixelData;
//  GL.Framebuffer frameBuffer;
  load() {
    img = new ImageElement();
    texture = gl.createTexture();
//    frameBuffer = gl.createFramebuffer();
    img.onLoad.listen((e) {
      gl.bindTexture(GL.TEXTURE_2D, texture);
      gl.texImage2DImage(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, img);
      gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
      gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);

//      gl.bindFramebuffer(GL.FRAMEBUFFER, frameBuffer);
//      gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture, 0);
//      pixelData = new Uint8List(img.width * img.height * 4);
//      gl.readPixels(0, 0, img.width, img.height, GL.RGBA, GL.UNSIGNED_BYTE, pixelData);
//      gl.bindFramebuffer(GL.FRAMEBUFFER, null);
    });
    img.src = url;
  }
  Int16List getPixelsAtCoords(int x, int y) {
    Int16List ret = new Int16List.fromList([255, 255, 255, 255]);
    if (pixelData != null) {
      ret.setAll(0, pixelData.getRange((x + (y*img.width))*4, ((x + (y*img.width))*4)+4));
    }
    return ret;
  }
  Int16List getPixelsInSquare(int x, int y, int w, int h) {
    int scaleBase = (x + (y*img.width))*4;
    int scaleMax = (((x+w) + ((y+h)*img.width))*4)+4;
    Int16List ret = new Int16List(scaleMax-scaleBase);
    for (int i = 0; i < ret.length;i++) ret.setAll(i, [255]);
    if (pixelData != null) {
      ret.setAll(0, pixelData.getRange(scaleBase, scaleMax));
    }
    return ret;
  }
}