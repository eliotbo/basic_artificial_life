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
    let R: vec2<f32> = uni.iResolution.xy;
    let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    
	var fragColor: vec4<f32>;
	var fragCoord = vec2<f32>(f32(location.x), f32(location.y) );

	var p: vec4<f32> = buffer_d.pixels[get_index(vec2<i32>(fragCoord))];
	// textureLoad(buffer_d, vec2<i32>(fragCoord));
	if (uni.iMouse.z > 0.) {
		if (p.z > 0.) {		
            fragColor = vec4<f32>(uni.iMouse.xy, p.xy);
		} else { 		
            fragColor = vec4<f32>(uni.iMouse.xy, uni.iMouse.xy);
		}
	} else { 	
        fragColor = vec4<f32>(-uni.iResolution.xy, -uni.iResolution.xy);
	}

    // textureStore(buffer_d, location, fragColor);
	buffer_d.pixels[get_index(location)] = fragColor;
} 


