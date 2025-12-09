struct Uniforms {
  resolution: vec2<f32>,
  camDist: f32,
  pitch: f32,
  yaw: f32,
  _padding0: u32,
  camTarget: vec3<f32>,
  _padding1: u32,
  _padding2: u32,
  _padding3: u32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct Object {
  objType: f32,
  _padding4: f32,
  _padding5: f32,
  _padding6: f32,
  position: vec3<f32>,
  _padding7: f32,
  scale: vec3<f32>,
  _padding8: f32,
  rotation: vec3<f32>,
  _padding9: f32,
  material: vec3<f32>,
  _padding10: f32,      
};

struct Scene {
  objects: array<Object, 20>,
};

@group(0) @binding(1)
var<storage, read> myScene: Scene;

@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {

  let uv = (fragCoord.xy - uniforms.resolution * 0.5) / min(uniforms.resolution.x, uniforms.resolution.y);

  // Orbital Controll
  //let pitch = clamp((uniforms.mouse.y / uniforms.resolution.y), 0.05, 1.5);
  //let yaw = -clamp((uniforms.mouse.x / uniforms.resolution.x), 0.05, 1.5)+uniforms.time * 0.1; 

  // Camera Coords
  //let cam_dist = 5.0; // Distance from the target
  //let cam_target = vec3<f32>(0.0, 0.0, 0.0);
  let pitch = uniforms.pitch;
  let yaw = uniforms.yaw;
  let cam_dist = uniforms.camDist;
  let cam_target = uniforms.camTarget;
  let cam_pos = vec3<f32>(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * cam_dist;

  // Camera Matrix
  let cam_forward = normalize(cam_target - cam_pos);
  let cam_right = normalize(cross(cam_forward, vec3<f32>(0.0, 1.0, 0.0)));
  let cam_up = cross(cam_right, cam_forward); // Re-orthogonalized up

  // Ray Direction
  // 1.5 is the "focal length" or distance to the projection plane
  let focal_length = 1.5;
  let rd = normalize(cam_right * uv.x - cam_up * uv.y + cam_forward * focal_length);

  // Ray march
  let result = ray_march(cam_pos, rd);

  if result.x < MAX_DIST {
      let hit_pos = cam_pos + rd * result.x;
      let normal = get_normal(hit_pos);

      // Lighting
      let light_pos = vec3<f32>(2.0, 5.0, -1.0);
      let light_dir = normalize(light_pos - hit_pos);
      let diffuse = max(dot(normal, light_dir), 0.0);

      let shadow_origin = hit_pos + normal * 0.01;
      let shadow_result = ray_march(shadow_origin, light_dir);
      let shadow = select(0.3, 1.0, shadow_result.x > length(light_pos - shadow_origin));

      let ambient = 0.2;
      let phong = result.yzw * (ambient + diffuse * shadow * 0.8);

      let fog = exp(-result.x * 0.02);
      let color = mix(MAT_SKY_COLOR, phong, fog);

      return vec4<f32>(gamma_correct(color), 1.0);
  }


  // Sky gradient
  let sky = mix(MAT_SKY_COLOR, MAT_SKY_COLOR * 0.9, uv.y * 0.5 + 0.5);
  return vec4<f32>(gamma_correct(sky), 1.0);
}

// Gamma Correction
fn gamma_correct(color: vec3<f32>) -> vec3<f32> {
  return pow(color, vec3<f32>(1.0 / 2.2));
}

// Constants
const MAX_DIST: f32 = 100.0;
const SURF_DIST: f32 = 0.001;
const MAX_STEPS: i32 = 256;

// Material Types
const MAT_Ground: f32 = 0;
const MAT_1: f32 = 1;

// Material Colors
const MAT_SKY_COLOR: vec3<f32> = vec3<f32>(0.7, 0.8, 0.9);

fn hash33(p: vec3<f32>) -> f32 {
    let dot_val = dot(p, vec3<f32>(127.1, 311.7, 74.7));
    return fract(sin(dot_val) * 43758.5453123);
}

fn MAT_GND_COLOR(p: vec3<f32>) -> vec3<f32> {
    let n = hash33(floor(p));
    return vec3<f32>(n, n, n);
}

// SDF Primitives
fn sd_sphere(p: vec3<f32>, r: f32) -> f32 {
  return length(p) - r;
}

fn sd_box(p: vec3<f32>, b: vec3<f32>) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

fn sd_torus(p: vec3<f32>, t: vec2<f32>) -> f32 {
  let q = vec2<f32>(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

fn sd_plane(p: vec3<f32>, n: vec3<f32>, h: f32) -> f32 {
  return dot(p, n) + h;
}

fn sd_cylinder(p: vec3<f32>, h: f32, r: f32) -> f32 {
    let d = vec2<f32>(length(p.xz) - r, abs(p.y) - h);
    return length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0);
}

fn sd_pyramid(p: vec3f, h: f32) -> f32 {
  let m2 = h * h + 0.25;
  var xz: vec2f = abs(p.xz);
  xz = select(xz, xz.yx, xz[1] > xz[0]);
  xz = xz - vec2f(0.5);

  let q = vec3f(xz[1], h * p.y - 0.5 * xz[0], h * xz[0] + 0.5 * p.y);
  let s = max(-q.x, 0.);
  let t = clamp((q.y - 0.5 * xz[1]) / (m2 + 0.25), 0., 1.);

  let a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
  let b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);

  let d2 = min(a, b) * step(min(q.y, -q.x * m2 - q.y * 0.5), 0.);
  return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -p.y));
}

fn sd_cone(p: vec3f, h: f32, sincos: vec2f) -> f32 {
  let q = h * vec2f(sincos.x / sincos.y, -1.);
  let w = vec2f(length(p.xz), p.y);
  let a = w - q * clamp(dot(w,q) / dot(q,q), 0., 1.);
  let b = w - q * vec2f(clamp(w.x / q.x, 0., 1.), 1.);
  let k = sign(q.y);
  let d = min(dot(a, a), dot(b, b));
  let s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
  return sqrt(d) * sign(s);
}

// Select SDF based on object type
fn sd_select(p: vec3<f32>, obj: Object) -> f32 {
    if obj.objType == 1 { return sd_box(p, obj.scale); }
    else if obj.objType == 2 { 
      let radius = (obj.scale.x + obj.scale.y + obj.scale.z) / 3.0;
      return sd_sphere(p, radius); }
    else if obj.objType == 3 { return sd_torus(p, vec2<f32>(obj.scale.x, obj.scale.y)); }
    else if obj.objType == 4 { return sd_cylinder(p, obj.scale.y, obj.scale.x); }
    else if obj.objType == 5 { return sd_pyramid(p, obj.scale.y); }
    else if obj.objType == 6 
    {
      let h = obj.scale.y;
      let r = obj.scale.x;
      let sincos = vec2f(r / sqrt(h*h + r*r), h / sqrt(h*h + r*r));
      return sd_cone(p, h, sincos); 
    }
    return MAX_DIST;
}

// SDF Operations
fn op_union(d1: f32, d2: f32) -> f32 {
  return min(d1, d2);
}

fn op_subtract(d1: f32, d2: f32) -> f32 {
  return max(d1, -d2);
}

fn op_intersect(d1: f32, d2: f32) -> f32 {
  return max(d1, d2);
}

fn op_smooth_union(d1: f32, d2: f32) -> f32 {
  let smooth_blend = 0.4;
  let h = clamp(0.5 + 0.5 * (d2 - d1) / smooth_blend, 0.0, 1.0);
  return mix(d2, d1, h) - smooth_blend * h * (1.0 - h);
}

fn op_smooth_union_v3(a: vec4<f32>, b: vec4<f32>, k: f32) -> vec4<f32> {
    let h = clamp(0.5 + 0.5 * (b.x - a.x) / k, 0.0, 1.0);
    let d = mix(b.x, a.x, h) - k * h * (1.0 - h);
    let col = mix(b.yzw, a.yzw, h);
    return vec4<f32>(d, col);
}

//rotation fonctions
fn rotX(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

fn rotY(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

fn rotZ(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

// Scene description - returns (distance, material color)
fn get_dist(p: vec3<f32>) -> vec4<f32> {
  var res = vec4<f32>(MAX_DIST, MAT_SKY_COLOR);

  let plane_dist = sd_plane(p, vec3<f32>(0.0, 1.0, 0.0), 0.5);
  let ground_color = MAT_GND_COLOR(p);
  res = op_smooth_union_v3(res, vec4<f32>(plane_dist, ground_color), 0.4);

  for (var i = 0u; i < 20u; i = i + 1u) {
      let obj = myScene.objects[i];
      let rotation = rotZ(obj.rotation.z) * rotY(obj.rotation.y) * rotX(obj.rotation.x);
      let localP = rotation * (p - obj.position);
      let d = sd_select(localP, obj);
      res = op_smooth_union_v3(res, vec4<f32>(d, obj.material), 0.4);
  }

  return res;
}


// Ray marching function - returns (distance, materrial
fn ray_march(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var d = 0.0;
    var color = MAT_SKY_COLOR;

    for (var i = 0; i < MAX_STEPS; i = i + 1) {
        let p = ro + rd * d;
        let dist_col = get_dist(p);
        d += dist_col.x;
        color = dist_col.yzw;

        if dist_col.x < SURF_DIST || d > MAX_DIST {
            break;
        }
    }

    return vec4<f32>(d, color);
}

// Calculate normal using gradient
fn get_normal(p: vec3<f32>) -> vec3<f32> {
  let e = vec2<f32>(0.001, 0.0);
  let n = vec3<f32>(
    get_dist(p + e.xyy).x - get_dist(p - e.xyy).x,
    get_dist(p + e.yxy).x - get_dist(p - e.yxy).x,
    get_dist(p + e.yyx).x - get_dist(p - e.yyx).x
  );
  return normalize(n);
}