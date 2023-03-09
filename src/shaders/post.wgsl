// Vertex shader

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec2<f32>,
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
};

@binding(0) @group(0) var postSampler: sampler;
@binding(1) @group(0) var postTexture: texture_2d<f32>;
@binding(2) @group(0) var<uniform> input_data: InputData;

@stage(vertex)
fn vs_main(
    @builtin(vertex_index) in_vertex_index: u32,
) -> VertexOutput {
    var out: VertexOutput;

    var positions = array<vec2<f32>, 4>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(-1.0, 1.0),
        vec2<f32>(1.0, 1.0),
    );

    out.clip_position = vec4<f32>(positions[in_vertex_index], 0.0, 1.0);

    out.position = positions[in_vertex_index];
    out.position.y = -out.position.y;

    return out;
}

fn to_uv_coords(pos: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(
        (pos.x + 1.0) * 0.5,
        (pos.y + 1.0) * 0.5,
    );
}

fn distort(pos: vec2<f32>, amount: f32) -> vec2<f32> {
    return pos * (1.0 - length(pos) * amount);
}

fn sample(pos: vec2<f32>) -> vec4<f32> {
    let uv = to_uv_coords(pos);
    let image = textureSample(postTexture, postSampler, uv);
    return image;
}

fn chromatic_aberration(pos: vec2<f32>, amount: f32, over_distort: f32) -> vec4<f32> {
    let r = distort(pos, (amount - over_distort) * 1.50917);
    let g = distort(pos, (amount) * 1.51124);
    let b = distort(pos, (amount + over_distort) * 1.51690);

    return vec4<f32>(
        sample(r).r,
        sample(g).g,
        sample(b).b,
        1.0
    );
}

fn rand(co: vec2<f32>) -> f32{
  return fract(sin(dot(co.xy ,vec2<f32>(12.9898,78.233))) * 43758.5453);
}

fn noise(pos: vec2<f32>, amount: f32) -> f32 {
    let r = (rand(pos + input_data.time / 10.0) * 2.0 - 1.0);
    return amount * r;
}

// Fragment shader
@stage(fragment)
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var image = chromatic_aberration(in.position,  input_data.chromatic_aberration * 0.1, input_data.chromatic_aberration * .03);
    image = image + noise(in.position, input_data.noise);
    return image;
}