struct PixelBuffer {
    pixels: array<vec4<f32>>,
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

