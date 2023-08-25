// Vertex shader

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) ray: vec3<f32>,
    @location(2) screen_coordinates: vec2<f32>
};

struct InputData {
    projection: mat4x4<f32>,
    inverse_projection: mat4x4<f32>,
    inverse_view: mat4x4<f32>,
    camera_position: vec3<f32>,
    time: f32,
    color: f32,
    noise: f32,
    chromatic_aberration: f32,
    iterations: f32,
    power: f32,
    normals: f32,
    randomness: f32,
    wobble_speed: f32,
    seed: f32,
    color1: vec4<f32>,
    color2: vec4<f32>,
    color3: vec4<f32>,
};

@group(0) @binding(0)
var<uniform> input_data: InputData;


fn signed_distance_to_sphere(pos: vec3<f32>, radius: f32) -> f32 {
    return length(pos) - radius;
}

fn signed_distance_to_cube(pos: vec3<f32>, size: f32) -> f32 {
    let q = abs(pos) - size;
    return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

struct PolarSphere {
    q: f32,
    f: f32,
    t: f32,
}

fn to_polar_sphere(pos: vec3<f32>) -> PolarSphere {
    var sphere = PolarSphere();
    sphere.q = length(pos);
    sphere.f = atan2(pos.y, pos.x);
    sphere.t = acos(pos.z / sphere.q);
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

fn signed_distance_to_sierpinsky(pos: vec3<f32>, iterations: u32, scale: f32) -> f32 {
    var z = pos;

    let a1 = vec3<f32>(1.0, 1.0, 1.0);
    let a2 = vec3<f32>(-1.0, -1.0, 1.0);
    let a3 = vec3<f32>(1.0, -1.0, -1.0);
    let a4 = vec3<f32>(-1.0, 1.0, -1.0);
    var c = vec3<f32>(0.0, 0.0, 0.0);
    let n = 0;
    var dist = 0.0;
    var d = 0.0;
    for (var i = 0u; i < iterations; i = i + 1u) {
        c = a1;
        dist = length(z - a1);
        d = length(z - a2); if d < dist { c = a2; dist = d; }
        d = length(z - a3); if d < dist { c = a3; dist = d; }
        d = length(z - a4); if d < dist { c = a4; dist = d; }
        z = scale * z - c * (scale - 1.0);
    }

    return length(z) * pow(scale, f32(-n));
}

fn signed_distance_to_ocahedron(pos: vec3<f32>, size: f32) -> f32 {
    let p = abs(pos);
    return (p.x + p.y + p.z - size) * 0.57735027;
}

fn signed_distance_to_mandelbulb(pos: vec3<f32>, iterations: u32, power: f32) -> f32 {
    var z = pos;
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

        z = pow_cartesian + pos;
    }
    return 0.5 * log(q) * q / dr;
}

fn rand(co: vec2<f32>) -> f32 {
    return fract(sin(dot(co.xy, vec2<f32>(12.9898, 78.233))) * 43758.5453);
}

fn rand_3d(coord: vec3<f32>) -> f32 {
    var c = abs(coord);
    c = c % (10000.0 * vec3<f32>(1.0));
    return fract(sin(dot(coord, vec3<f32>(12.9898, 78.233, 71.325))) * 43758.5453);
}

fn perlin_noise(coord: vec3<f32>) -> f32 {
    var c = coord;
    c = c * 20.0;
    c = c % (10000.0 * vec3<f32>(1.0));

    var i: vec3<f32> = floor(c);
    var f: vec3<f32> = fract(c);

    var cube = array<array<array<f32, 2>, 2>, 2>();
    cube[0][0][0] = rand_3d(i) * 6.28318;
    cube[1][0][0] = rand_3d(i + vec3<f32>(1.0, 0.0, 0.0)) * 6.28318;
    cube[0][1][0] = rand_3d(i + vec3<f32>(0.0, 1.0, 0.0)) * 6.28318;
    cube[0][0][1] = rand_3d(i + vec3<f32>(0.0, 0.0, 1.0)) * 6.28318;
    cube[1][1][0] = rand_3d(i + vec3<f32>(1.0, 1.0, 0.0)) * 6.28318;
    cube[0][1][1] = rand_3d(i + vec3<f32>(0.0, 1.0, 1.0)) * 6.28318;
    cube[1][0][1] = rand_3d(i + vec3<f32>(1.0, 0.0, 1.0)) * 6.28318;
    cube[1][1][1] = rand_3d(i + vec3<f32>(1.0, 1.0, 1.0)) * 6.28318;

    var vectors = array<array<array<vec3<f32>, 2>, 2>, 2>();
    vectors[0][0][0] = vec3(-sin(cube[0][0][0]), cos(cube[0][0][0]), -cos(cube[0][0][0]));
    vectors[1][0][0] = vec3(-sin(cube[1][0][0]), cos(cube[1][0][0]), -cos(cube[1][0][0]));
    vectors[0][1][0] = vec3(-sin(cube[0][1][0]), cos(cube[0][1][0]), -cos(cube[0][1][0]));
    vectors[0][0][1] = vec3(-sin(cube[0][0][1]), cos(cube[0][0][1]), -cos(cube[0][0][1]));
    vectors[1][1][0] = vec3(-sin(cube[1][1][0]), cos(cube[1][1][0]), -cos(cube[1][1][0]));
    vectors[0][1][1] = vec3(-sin(cube[0][1][1]), cos(cube[0][1][1]), -cos(cube[0][1][1]));
    vectors[1][0][1] = vec3(-sin(cube[1][0][1]), cos(cube[1][0][1]), -cos(cube[1][0][1]));
    vectors[1][1][1] = vec3(-sin(cube[1][1][1]), cos(cube[1][1][1]), -cos(cube[1][1][1]));

    var dots = array<array<array<f32, 2>, 2>, 2>();
    dots[0][0][0] = dot(vectors[0][0][0], f);
    dots[1][0][0] = dot(vectors[1][0][0], f - vec3<f32>(1.0, 0.0, 0.0));
    dots[0][1][0] = dot(vectors[0][1][0], f - vec3<f32>(0.0, 1.0, 0.0));
    dots[0][0][1] = dot(vectors[0][0][1], f - vec3<f32>(0.0, 0.0, 1.0));
    dots[1][1][0] = dot(vectors[1][1][0], f - vec3<f32>(1.0, 1.0, 0.0));
    dots[0][1][1] = dot(vectors[0][1][1], f - vec3<f32>(0.0, 1.0, 1.0));
    dots[1][0][1] = dot(vectors[1][0][1], f - vec3<f32>(1.0, 0.0, 1.0));
    dots[1][1][1] = dot(vectors[1][1][1], f - vec3<f32>(1.0, 1.0, 1.0));

    var cubic: vec3<f32> = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(
            mix(dots[0][0][0], dots[1][0][0], cubic.x),
            mix(dots[0][1][0], dots[1][1][0], cubic.x),
            cubic.y
        ),
        mix(
            mix(dots[0][0][1], dots[1][0][1], cubic.x),
            mix(dots[0][1][1], dots[1][1][1], cubic.x),
            cubic.y
        ),
        cubic.z
    ) + 0.5;
}

// fn noise

fn map(pos: vec3<f32>) -> f32 {
    var repeat = cos(pos);
    if input_data.randomness != 0.0 {
        let r = perlin_noise(pos * input_data.randomness + input_data.seed + input_data.time * input_data.wobble_speed) * 2.0 - 1.0;
        repeat = repeat + r;
    }
    let d3 = signed_distance_to_mandelbulb(repeat, u32(input_data.iterations), input_data.power);

    return d3;

    // return smooth_min(
    //     d1,
    //     d2,
    //     .2
    // );
}

fn colored_map(pos: vec3<f32>) -> vec2<f32> {
    let otherpos = pos + vec3<f32>(.5 * sin(input_data.time), 0.0, 0.0);
    let d1 = signed_distance_to_sphere(pos, 0.2);
    let d2 = signed_distance_to_cube(otherpos, 0.1);

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

fn normal(pos: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;

    let normal = vec3<f32>(
        map(pos + vec3<f32>(eps, 0.0, 0.0)) - map(pos + vec3<f32>(-eps, 0.0, 0.0)),
        map(pos + vec3<f32>(0.0, eps, 0.0)) - map(pos + vec3<f32>(0.0, -eps, 0.0)),
        map(pos + vec3<f32>(0.0, 0.0, eps)) - map(pos + vec3<f32>(0.0, 0.0, -eps))
    );
    return normalize(normal);
}

fn raymarch(position: vec3<f32>, ray: vec3<f32>) -> vec4<f32> {
    var ret = vec4<f32>(1.0, 1.0, 1.0, 1.0);

    let max_steps: u32 = 1024u;
    let threshold: f32 = 0.001;

    var t = 0.0;

    var traveled = 0.0;

    var glow_color = vec4<f32>(0.0, 0.0, 1.0, 1.0);

    for (var i = 0u; i < max_steps; i = i + 1u) {
        let p = position + ray * t;

        let d = map(p);
        traveled = traveled + d;

        if d > 1000.0 {
            break;
        }

        // ret.z = ret.z - .003;

        if d < threshold {
            let lightDir = normalize(vec3<f32>(0.0, 1.0, -1.0));

            let color1 = vec3<f32>(217.0, 3.0, 104.0) / 255.0;
            let color2 = vec3<f32>(241.0, 196.0, 15.0) / 255.0;
            let color3 = vec3<f32>(34.0, 116.0, 165.0) / 255.0;

            let color_difference = 10.0;

            var steps = f32(i) / f32(max_steps);
            steps = steps * 5.0 - 0.8;

            let mix1 = mix(
                input_data.color1.rgb,
                input_data.color2.rgb,
                sin(steps * color_difference)
            );

            let mix2 = mix(
                mix1,
                input_data.color3.rgb,
                sin(steps * color_difference + color_difference / 2.0)
            );

            let color = mix(
                vec3<f32>(1.0) * f32(i) / f32(max_steps) + .2,
                mix2 + abs(steps),
                input_data.color
            );


            var l = 0.0;
            if input_data.normals != 0.0 {
                l = dot(normal(p), lightDir);
            }
            ret = vec4<f32>(vec3<f32>(1.0) * color * mix(1.0, l, input_data.normals), 1.0);
            break;
        }

        t = t + d;
    }

    return ret;
}

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
 