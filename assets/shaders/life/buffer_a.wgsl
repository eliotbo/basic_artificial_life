// struct CommonUniform {
//     iTime: f32;
//     iTimeDelta: f32;
//     iFrame: f32;
//     iSampleRate: f32;

    
//     iMouse: vec4<f32>;
//     iResolution: vec2<f32>;

//     forces: mat4x4<f32>;
    

//     // iChannelTime: vec4<f32>;
//     // iChannelResolution: vec4<f32>;
//     // iDate: vec4<i32>;
// };

struct PixelBuffer {
    pixels: array<vec4<f32>>,
};


// [[group(0), binding(0)]]
// var<uniform> uni: CommonUniform;

// [[group(0), binding(10)]] var<storage, read_write> quad_tree: PixelBuffer;

// [[group(0), binding(1)]] var<storage, read_write> buffer_a: PixelBuffer;
// [[group(0), binding(2)]] var<storage, read_write> buffer_b: PixelBuffer;
// [[group(0), binding(3)]] var<storage, read_write> buffer_c: PixelBuffer;
// [[group(0), binding(4)]] var<storage, read_write> buffer_d: PixelBuffer;


struct CommonUniform {
    iResolution: vec2<f32>,
    changed_window_size: f32,
    padding0: f32,
    
    iTime: f32,
    iTimeDelta: f32,
    iFrame: f32,
    iSampleRate: f32,
    
    iMouse: vec4<f32>,
    

    forces: mat4x4<f32>,
};


@group(0) @binding(0)
var<uniform> uni: CommonUniform;

@group(0) @binding(1)
 var<storage, read_write> buffer_a: PixelBuffer;

@group(0) @binding(2)
 var<storage, read_write> buffer_b: PixelBuffer;

@group(0) @binding(3)
 var<storage, read_write> buffer_c: PixelBuffer;

@group(0) @binding(4)
 var<storage, read_write> buffer_d: PixelBuffer;




fn get_index( location: vec2<i32> ) -> i32 {
    return i32(uni.iResolution.y) * i32(location.x )  + i32(location.y ) ;
}





@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

    // let color = vec4<f32>(0.5);
    let color = vec4<f32>(0.1, 0.2, 0.3, 1.0);
    // textureStore(buffer_a, location, color);
    // buffer_a.pixels[get_index(location)] = color;

    let quoi = &buffer_a.pixels[get_index(location)] ;
    *quoi = color;
}