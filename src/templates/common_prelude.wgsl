// struct PixelBuffer {
//     pixels: array<vec4<f32>>,
// };

struct GridSlot {
    pos: vec2<f32>,
    vel: vec2<f32>,
    id: u32,
    mass: u32,
    kind: u32,
}

struct GridSlotEncoded {
    id: u32,
    mass_kind_pos_encoded: u32,
    encoded_vel: u32,
    dummy: u32,
}

struct PixelBuffer {
    pixels: array<GridSlotEncoded>,
};

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

    grid_size: vec4<u32>,
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


// TODO: is the -1 necessary?
fn get_index( location: vec2<i32>) -> i32 {
    return (i32(uni.grid_size.y) - 0) * (i32(location.x ) + 0)  + i32(location.y )  ;
}


// fn get_image_index( location: vec2<i32>) -> i32 {
//     return i32(uni.iResolution.y) * i32(location.x )  + i32(location.y ) ;
//     // return i32(uni.grid_size.y) * i32(location.x )  + i32(location.y ) ;
// }
