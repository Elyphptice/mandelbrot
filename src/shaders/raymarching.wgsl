// Vertex shader

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>;
    @location(0) position: vec3<f32>;
    @location(1) ray: vec3<f32>;
};

struct InputData {
    projection: mat4x4<f32>;
    time: f32;
    inverse_view: mat4x4<f32>;
};

@group(0) @binding(0)
var<uniform> input_data: InputData;

fn signed_distance_to_sphere(point: vec3<f32>, radius: f32) -> f32 {
    return length(point) - radius;
}

fn map(point: vec3<f32>) -> f32 {
    return signed_distance_to_sphere(point, 0.2);
}

fn raymarch(position: vec3<f32>, ray: vec3<f32>) -> vec4<f32> {
    var ret = vec4<f32>(0.0, 0.0, 0.0, 0.0);

    let max_steps: u32 = 64u;
    let threshold: f32 = 0.001;

    var t = 0.0;
    for (var i = 0u; i < max_steps; i = i + 1u) {
        let p = position + ray * t;
        let d = map(p);

        if(d < threshold) {
            // ret = vec4<f32>(p.x, p.y, p.z, 1.0);
            ret = vec4<f32>(.5, .5, .5, 1.0);
            break;
        }

        t = t + d;
    }

    return ret;
}

// fn signed_distance_to_cube(point: vec3<f32>, extent: f32) -> f32 {
    
// }

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

    var randomPoints = array<vec3<f32>, 4>(
        vec3<f32>(-1.0, -1.0, 0.0),
        vec3<f32>(1.0, -1.0, 0.0),
        vec3<f32>(-1.0, 1.0, 0.0),
        vec3<f32>(1.0, 1.0, 0.0),
    );


    let PI = 3.1415926535897932384626433832795;
    let angle = input_data.time *  90.0 * PI / 180.0;

    var dir = vec3<f32>(0.0, 0.0, 1.0);
    dir = normalize(dir);
    
    let cx = cos(angle * dir.x);
    let sx = sin(angle * dir.x);
    let cy = cos(angle * dir.y);
    let sy = sin(angle * dir.y);
    let cz = cos(angle * dir.z);
    let sz = sin(angle * dir.z);
    
    var rotation = mat4x4<f32>(
        cy * cz, cy * sz, -sy, 0.0,
        sx * sy * cz - cx * sz, sx * sy * sz + cx * cz, sx * cy, 0.0,
        cx * sy * cz + sx * sz, cx * sy * sz - sx * cz, cx * cy, 0.0,
        0.0, 0.0, 0.0, 1.0,
    );

    var translation = mat4x4<f32>(
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 10.0, 1.0,
    );

    

    var out: VertexOutput;
    var pos = vec3<f32>(positions[in_vertex_index].xy, 0.0);
    
    out.clip_position = input_data.projection * translation * rotation * vec4<f32>(randomPoints[in_vertex_index], 1.0);

    out.position = pos;
    out.ray = (input_data.projection * out.clip_position).xyz;
    
    return out;
}

// Fragment shader
    
@stage(fragment)
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, in.position.xy, 1.0);
}
 