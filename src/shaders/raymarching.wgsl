// Vertex shader

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) ray: vec3<f32>,
    @location(2) screen_coordinates: vec2<f32>,
};

struct InputData {
    projection: mat4x4<f32>,
    inverse_projection: mat4x4<f32>,
    inverse_view: mat4x4<f32>,
    camera_position: vec3<f32>,
    time: f32,
};

@group(0) @binding(0)
var<uniform> input_data: InputData;

fn signed_distance_to_sphere(point: vec3<f32>, radius: f32) -> f32 {
    return length(point) - radius;
}

fn signed_distance_to_cube(point: vec3<f32>, size: f32) -> f32 {
    let q = abs(point) - size;
    return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

struct PolarSphere {
    q: f32,
    f: f32,
    t: f32,
}

fn to_polar_sphere(point: vec3<f32>) -> PolarSphere {
    var sphere = PolarSphere();
    sphere.q = length(point);
    sphere.f = atan2(point.y, point.x);
    sphere.t = acos(point.z / sphere.q);
    return sphere;
}

fn pow_polar_sphere(sphere: PolarSphere, p: f32) -> PolarSphere {
    var new_sphere = PolarSphere();
    new_sphere.q = pow(sphere.q, p);
    new_sphere.f = p * sphere.f;
    new_sphere.t = p * sphere.t;
    return new_sphere;
}

fn from_polar_sphere(sphere: PolarSphere) -> vec3<f32> {
    return vec3(
        sphere.q * sin(sphere.t) * cos(sphere.f),
        sphere.q * sin(sphere.t) * sin(sphere.f),
        sphere.q * cos(sphere.t)
    );
}

fn signed_distance_to_mandelbulb(point: vec3<f32>, iterations: u32, power: f32) -> f32 {
    var z = point;
    var q = 0.0;
    var dr = 1.0;

    for (var i = 0u; i < iterations; i = i + 1u) {
        let polar = to_polar_sphere(z);
        q = polar.q;

        if q > 2.0 {
            break;
        }

        dr = pow(q, power - 1.0) * power * dr + 1.0;

        let polar_pow = pow_polar_sphere(polar, power);

        let pow_cartesian = from_polar_sphere(polar_pow);

        z = pow_cartesian + point;
    }
    return 0.5 * log(q) * q / dr;
}

fn map(point: vec3<f32>) -> f32 {
    let otherPoint = point + vec3<f32>(.5 * sin(input_data.time), 0.0, 0.0);
    let d1 = signed_distance_to_sphere(point, 0.2);
    let d2 = signed_distance_to_cube(otherPoint, 0.1);

    return smooth_min(
        d1,
        d2,
        .2
    );
}

fn colored_map(point: vec3<f32>) -> vec2<f32> {
    let otherPoint = point + vec3<f32>(.5 * sin(input_data.time), 0.0, 0.0);
    let d1 = signed_distance_to_sphere(point, 0.2);
    let d2 = signed_distance_to_cube(otherPoint, 0.1);

    let m = smooth_min(
        d1,
        d2,
        .2
    );

    return vec2<f32>(m, clamp((d1 - d2) / .2, 0.0, 1.0));
}

fn smooth_min(a: f32, b: f32, smoothing: f32) -> f32 {
    let h = max(smoothing - abs(a - b), 0.0) / smoothing;
    return min(a, b) - h * h * h * smoothing / 6.0;
}

fn normal(point: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;

    let normal = vec3<f32>(
        map(point + vec3<f32>(eps, 0.0, 0.0)) - map(point + vec3<f32>(-eps, 0.0, 0.0)),
        map(point + vec3<f32>(0.0, eps, 0.0)) - map(point + vec3<f32>(0.0, -eps, 0.0)),
        map(point + vec3<f32>(0.0, 0.0, eps)) - map(point + vec3<f32>(0.0, 0.0, -eps))
    );
    return normalize(normal);
}

fn raymarch(position: vec3<f32>, ray: vec3<f32>) -> vec4<f32> {
    var ret = vec4<f32>(1.0, 1.0, 1.0, 1.0);

    let max_steps: u32 = 128u;
    let threshold: f32 = 0.001;

    var t = 0.0;
    for (var i = 0u; i < max_steps; i = i + 1u) {
        let p = position + ray * t;
        // let d = map(p);

        let m = colored_map(p);
        let d = m.x;
        let c = m.y;

        if d < threshold {
            let lightDir = normalize(vec3<f32>(0.0, 1.0, -1.0));

            var color = vec3<f32>(
                1.0 - c,
                0.0,
                c
            );

            let l = dot(normal(p), lightDir);
            // ret = vec4<f32>(vec3<f32>(c) - .2, 1.0);
            ret = vec4<f32>(l * color, 1.0);
            break;
        }

        t = t + d;
    }

    return ret;
}

// fn signed_distance_to_cube(point: vec3<f32>, extent: f32) -> f32 {
    
// }

@vertex
fn vs_main(
    @builtin(vertex_index) in_vertex_index: u32,
) -> VertexOutput {
    var positions = array<vec2<f32>, 4>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(-1.0, 1.0),
        vec2<f32>(1.0, 1.0),
    );


    var out: VertexOutput;
    var pos = vec3<f32>(positions[in_vertex_index].xy, 0.0);

    out.clip_position = vec4<f32>(pos, 1.0);

    out.position = pos;

    out.screen_coordinates = pos.xy;

    pos.z = 1.0;
    out.ray = (input_data.projection * input_data.inverse_projection * vec4<f32>(pos, 1.0)).xyz;

    return out;
}

// Fragment shader
    
@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let sphere_pos = vec3<f32>(0.0, 0.0, 2.0);

    var color = raymarch(-input_data.camera_position + vec3<f32>(0.0, 0.0, -1.0), normalize(in.ray));

    let v = length(in.screen_coordinates / 5.0) / 1.0;

    color.x = color.x - v;
    color.y = color.y - v;
    color.z = color.z - v;
    return vec4<f32>(color);
}
 