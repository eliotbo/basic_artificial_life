struct CommonUniform {
    iTime: f32;
    iTimeDelta: f32;
    iFrame: f32;
    iSampleRate: f32;

    
    iMouse: vec4<f32>;
    iResolution: vec2<f32>;

    

    iChannelTime: vec4<f32>;
    iChannelResolution: vec4<f32>;
    iDate: vec4<i32>;
};

struct PixelBuffer {
    pixels: array<vec4<f32>>;
};


[[group(0), binding(0)]]
var<uniform> uni: CommonUniform;

[[group(0), binding(1)]] var<storage, read_write> buffer_a: PixelBuffer;
[[group(0), binding(2)]] var<storage, read_write> buffer_b: PixelBuffer;
[[group(0), binding(3)]] var<storage, read_write> buffer_c: PixelBuffer;
[[group(0), binding(4)]] var<storage, read_write> buffer_d: PixelBuffer;



fn get_index( location: vec2<i32> ) -> i32 {
    return i32(uni.iResolution.y) * i32(location.x )  + i32(location.y ) ;
}





[[stage(compute), workgroup_size(8, 8, 1)]]
fn update([[builtin(global_invocation_id)]] invocation_id: vec3<u32>) {
    let index = get_index(vec2<i32>(invocation_id.xy));
}
