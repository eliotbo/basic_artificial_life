
// struct PixelBuffer {
//     pixels: array<vec4<f32>>,
// };

struct GridSlot {
    pos: vec2<f32>,
    id: u32,
    mass: u32,
    kind: u32,
}

struct GridSlotEncoded {
    id: u32,
    mass_kind_pos_encoded: u32,
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


fn get_index( location: vec2<i32> ) -> i32 {
    // return i32(uni.iResolution.y) * i32(location.x )  + i32(location.y ) ;
    return i32(uni.grid_size.y) * i32(location.x )  + i32(location.y ) ;
}



@group(0) @binding(5)
var texture: texture_storage_2d<rgba32float, read_write>;

@group(0) @binding(6)
var font_texture: texture_2d<f32>;

@group(0) @binding(7)
var font_texture_sampler: sampler;

@group(0) @binding(8)
var rgba_noise_256_texture: texture_2d<f32>;

@group(0) @binding(9)
var rgba_noise_256_texture_sampler: sampler;

@group(0) @binding(10)
var blue_noise_texture: texture_2d<f32>;

@group(0) @binding(11)
var blue_noise_texture_sampler: sampler;





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



// sdf of a circle
fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
  let d = length(p - c);
  return d - r;
}

let red = vec4<f32>(1.0, 0.0, 0.0, 1.0);
let green = vec4<f32>(0.0, 1.0, 0.0, 1.0);
let blue = vec4<f32>(0.0, 0.0, 1.0, 1.0);
let yellow = vec4<f32>(1.0, 1.0, 0.0, 1.0);
let cyan = vec4<f32>(0.0, 1.0, 1.0, 1.0);

fn ball_sdf(
    color: vec4<f32>, 
    location: vec2<i32>, 
    grid_loc: vec2<i32>, 
    slot: GridSlot,
    coef: f32
) -> f32 {

    let relative_ball_position = slot.pos;

    let absolute_ball_position = 
        (vec2<f32>(grid_loc) ) * coef 
        + relative_ball_position * coef;

    let ball_radius = coef/4.2;
    let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius);

    return s;

   
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

     

    let expansion_coefficient = uni.iResolution.x / f32(uni.grid_size.x);
    let grid_loc = vec2<i32>(vec2<f32>(location) / expansion_coefficient);



    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    var color = vec4<f32>(0.1, 0.2, 0.3, 1.0);

    let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
    let slot: GridSlot = decode(slot_encoded);



    for (var i = -1; i < 2; i=i+1) {
        for (var j = -1; j < 2; j=j+1) {
            

            let neighbor_loc = grid_loc + vec2<i32>(i, j);
            let neighbor_slot_encoded: GridSlotEncoded = buffer_a.pixels[get_index(neighbor_loc)];
            let neighbor_slot: GridSlot = decode(neighbor_slot_encoded);

            // let neighbor_loc2 = grid_loc - vec2<i32>(i, j);


            if (neighbor_slot.mass > 0u) {
                // let s = ball_sdf(red, location, grid_loc, slot, expansion_coefficient);
                let relative_ball_position = neighbor_slot.pos;

                let absolute_ball_position = 
                    (vec2<f32>(neighbor_loc) ) * expansion_coefficient 
                    + relative_ball_position * expansion_coefficient;

                let ball_radius = expansion_coefficient/4.2;
                let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius);

                var ball_color = red;
                
                switch (neighbor_slot.kind) {
                    case 0u { ball_color = red; }
                    case 1u { ball_color = green; }
                    case 2u { ball_color = blue; }
                    case 3u { ball_color = yellow; }
                    default { ball_color = cyan; }

                }

                color = mix(color, ball_color, 1.0 - smoothstep(-0.0, 1.0, s));
            }
        }
    }

    textureStore(texture, location, color);
}