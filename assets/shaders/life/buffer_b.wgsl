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


fn get_index( location: vec2<i32> ) -> i32 {
    // return i32(uni.iResolution.y) * i32(location.x )  + i32(location.y ) ;
    return i32(uni.grid_size.y) * i32(location.x )  + i32(location.y ) ;
}



let grid_size = vec2<f32>(800.0, 500.0);

fn hash32(p: vec2<f32>) -> vec3<f32> {
    var p3: vec3<f32> = fract(vec3<f32>(p.xyx) * vec3<f32>(0.1031, 0.103, 0.0973));
    p3 = p3 + (dot(p3, p3.yxz + 33.33));
    return fract((p3.xxy + p3.yzz) * p3.zyx);
} 

fn hash41(p: f32) -> vec4<f32> {
	var p4: vec4<f32> = fract(vec4<f32>(p) * vec4<f32>(0.1031, 0.103, 0.0973, 0.1099));
	p4 = p4 + (dot(p4, p4.wzxy + 33.33));
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
} 

struct ParticleSlot {
    occupied: bool,
    mass: u32,
    kind: u32,
}

fn decode(particle_u32: u32) -> ParticleSlot {
    // let particle: ParticleSlot;
    let occupied = (particle_u32 & 0x01u) == 1u;
    let mass: u32 = u32((particle_u32 >> 1u) & 0xFFu);
    let kind: u32 = ((particle_u32 >> 9u) & 0xFFu);


    let p = ParticleSlot( occupied,  mass,  kind);

    return p;
}

fn encode(particle: ParticleSlot) -> u32 {
    var encoded: u32 = 0u;

    if (particle.occupied) {
        encoded |= 1u;
    }
    encoded |= (particle.mass & 0xFFu) << 1u;
    encoded |= (particle.kind & 0xFFu) << 9u;
    return encoded;
}


@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

}