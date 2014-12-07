part of ld31;

class Shader {
  GL.Program program;

  Shader(String vertexShaderSource, String fragmentShaderSource) {
   var vertexShader = compile(vertexShaderSource, GL.VERTEX_SHADER);
   var fragmentShader = compile(fragmentShaderSource, GL.FRAGMENT_SHADER);
   program = link(vertexShader, fragmentShader);
 }
 GL.Program link(GL.Shader vertexShader, GL.Shader fragmentShader) {
   GL.Program program = gl.createProgram();
   gl.attachShader(program, vertexShader);
   gl.attachShader(program, fragmentShader);
   gl.linkProgram(program);
   if (!gl.getProgramParameter(program, GL.LINK_STATUS)) throw gl.getProgramInfoLog(program);
   return program;
 }

 GL.Shader compile(String source, int type) {
   GL.Shader shader = gl.createShader(type);
   gl.shaderSource(shader, source);
   gl.compileShader(shader);
   if (!gl.getShaderParameter(shader, GL.COMPILE_STATUS)) throw gl.getShaderInfoLog(shader);
   return shader;
 }

 void use() {
  gl.useProgram(testShader.program);
 }
}
Shader testShader = new Shader(
    /* Vertex Shader */ """
  precision highp float;
  
  attribute vec2 a_pos;
  attribute vec2 a_uv;
  attribute vec4 a_col;

  uniform mat4 u_viewMatrix;

  varying vec4 v_col;
  varying vec2 v_uv;

  void main() {
    v_col = a_col;
    v_uv = a_uv/256.0;
    gl_Position = u_viewMatrix*vec4(floor(a_pos), 0.5, 1.0); 
  } 
""",/* Fragment Shader */ """
  precision highp float;
      
  varying vec4 v_col;
  varying vec2 v_uv;

  uniform sampler2D u_tex;

  void main() { 
    vec4 col = texture2D(u_tex, v_uv);
    if (col.a<0.5) discard;
    gl_FragColor = col*v_col;
  }
""");

