
fn hash32(p: vec2<f32>) -> vec3<f32> {
    var p3: vec3<f32> = fract(vec3<f32>(p.xyx) * vec3<f32>(0.1031, 0.103, 0.0973));
    p3 = p3 + (dot(p3, p3.yxz + 33.33));
    return fract((p3.xxy + p3.yzz) * p3.zyx);
} 


// white noise
fn noise2d(co: vec2<f32>) -> f32 {
	return fract(sin(dot(co.xy, vec2<f32>(1., 73.))) * 43758.547);
} 

fn hash2(p: vec2<f32>) -> vec2<f32> {
	return fract(sin(vec2<f32>(dot(p, vec2<f32>(127.1, 311.7)), dot(p, vec2<f32>(269.5, 183.3)))) * 43758.547);
} 






let u8max = 255.0;

fn decode(grid_slot_encoded: GridSlotEncoded) -> GridSlot {

    let id = grid_slot_encoded.id;

    let encoded = grid_slot_encoded.mass_kind_pos_encoded;

    let mass: u32 = (encoded >> 0u) & 0xFFu;
    let kind: u32 = (encoded >> 8u) & 0xFFu;

    let posx = (encoded >> 16u) & 0xFFu ;
    let posy = (encoded >> 24u) & 0xFFu ;

    let pos = vec2<f32>(f32(posx) / u8max, f32(posy) / u8max);


    let p = GridSlot( pos, id, mass,  kind);

    return p;
}

fn encode(slot: GridSlot) -> GridSlotEncoded {

    if (slot.mass == 0u) {
        return GridSlotEncoded(0u, 0u);
    }

    var encoded: u32 = 0u;

    encoded |= (slot.mass & 0xFFu) << 0u;
    encoded |= (slot.kind & 0xFFu) << 8u;

    let x = u32(slot.pos.x * u8max);
    let y = u32(slot.pos.y * u8max);

    encoded |= (x & 0xFFu) << 16u;
    encoded |= (y & 0xFFu) << 24u;

    return GridSlotEncoded( slot.id, encoded);
}
