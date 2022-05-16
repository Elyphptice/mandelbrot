// Vertex shader

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>;
    @location(0) position: vec2<f32>;
};

struct InputData {
    zoom: f32;
    x: f32;
    y: f32;
    r_mod: f32;
    g_mod: f32;
    b_mod: f32;
};

@group(0) @binding(0)
var<uniform> input_data: InputData;


@stage(vertex)
fn vs_main(
    @builtin(vertex_index) in_vertex_index: u32,
) -> VertexOutput {
    var positions = array<vec2<f32>, 4>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(-1.0, 1.0),
        vec2<f32>(1.0, 1.0),
    );
    
    let e = 2.7182;
    var out: VertexOutput;
    let x = f32(1 - i32(in_vertex_index)) * 0.05;
    let y = f32(i32(in_vertex_index & 1u) * 2 - 1) * 0.05;
    out.clip_position = vec4<f32>(positions[in_vertex_index].xy, 0.0, 1.0);
    out.position = vec2<f32>(positions[in_vertex_index].x * 2.0 - 0.5, positions[in_vertex_index].y);
    out.position = (out.position) * pow(e, -input_data.zoom)  + vec2<f32>(input_data.x, input_data.y);
    return out;
}

// Fragment shader

fn square_complex(c: vec2<f32>) -> vec2<f32> {
    let x = c.x * c.x - c.y * c.y;
    let y = input_data.r_mod * c.x * c.y;
    return vec2<f32>(x, y);
}

@stage(fragment)
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let iterations = 1000;

    var z = vec2<f32>(0.0);
    let c = in.position;

    for(var i = 0; i < iterations; i = i + 1) {
        z = square_complex(z) + c * input_data.r_mod;
        if(z.x * z.x + z.y * z.y > 4.0) {
            let f = f32(i) / 10.0;
            return vec4<f32>(f % input_data.r_mod, f % input_data.g_mod, f % input_data.b_mod, 1.0);
        }
        
    }

    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}
 