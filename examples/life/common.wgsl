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
    pos: vec2<f32>,
    id: u32,
    mass: u32,
    kind: u32,
}

fn decode(grid_slot: Vec4) -> ParticleSlot {

    let pos = grid_slot.xy;
    let id = grid_slot.z;

    let encoded_mass_kind = grid_slot.w;

    let mass: u32 = (encoded_mass_kind >> 0u) & 0xFFu;
    let kind: u32 = (encoded_mass_kind >> 8u) & 0xFFu;

    let p = ParticleSlot( pos, id, mass,  kind);

    return p;
}

fn encode(particle: ParticleSlot) -> u32 {
    var encoded: u32 = 0u;

    if (particle.occupied) {
        encoded |= 1u;
    }
    encoded |= (particle.mass & 0xFFu) << 0u;
    encoded |= (particle.kind & 0xFFu) << 8u;
    return encoded;
}
