
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



// struct GridSlot {
//     pos: vec2<f32>,
//     vel: vec2<f32>,
//     id: u32,
//     mass: u32,
//     kind: u32,
// }

// struct GridSlotEncoded {
//     id: u32,
//     mass_kind_pos_encoded: u32,
//     encoded_vel: u2,
// }

// let empty_slot = GridSlot (vec2<f32>(0., 0.), vec2<f32>(0., 0.), 0, 0, 0);
let empty_encoded_slot = GridSlotEncoded (0u, 0u, 0u, 0u);

let ball_radius = 0.5;
let max_vel = 0.5;
let u8max = 255.0;
let u16max = 65535.0;
let u32max = 4294967295.0;

fn decode(grid_slot_encoded: GridSlotEncoded) -> GridSlot {

    let id = grid_slot_encoded.id;

    let encoded = grid_slot_encoded.mass_kind_pos_encoded;

    let mass: u32 = (encoded >> 0u) & 0xFFu;
    let kind: u32 = (encoded >> 8u) & 0xFFu;

    let posx = (encoded >> 16u) & 0xFFu ;
    let posy = (encoded >> 24u) & 0xFFu ;

    // let pos = vec2<f32>(
    //         f32(posx) / u8max * f32(uni.grid_size.x), 
    //         f32(posy) / u8max * f32(uni.grid_size.y)
    //     ); 

    let pos = vec2<f32>(
        f32(posx) / u8max , 
        f32(posy) / u8max 
    ); 


    let encoded_vel = grid_slot_encoded.encoded_vel;
    let velx = (encoded_vel >> 0u) & 0xFFFFu;
    let vely = (encoded_vel >> 16u) & 0xFFFFu;

    // let vel = vec2<f32>(f32(velx) / u16max, f32(vely) / u16max) ;

    let vel = vec2<f32>(
        (f32(velx)  / u16max - 0.5) * 2.0,
        (f32(vely)  / u16max - 0.5) * 2.0,
    ) * max_vel;


    let p = GridSlot( pos, vel, id, mass,  kind);

    return p;
}

fn encode(slot: GridSlot) -> GridSlotEncoded {

    if (slot.mass == 0u) {
        return GridSlotEncoded(0u, 0u, 0u, 0u);
    }

    var encoded: u32 = 0u;

    encoded |= (slot.mass & 0xFFu) << 0u;
    encoded |= (slot.kind & 0xFFu) << 8u;

    // let x = u32(slot.pos.x * u8max / f32(uni.grid_size.x));
    // let y = u32(slot.pos.y * u8max / f32(uni.grid_size.y));

    let x = u32(slot.pos.x * u8max );
    let y = u32(slot.pos.y * u8max );

    encoded |= (x & 0xFFu) << 16u;
    encoded |= (y & 0xFFu) << 24u;

    let nvel = (slot.vel / max_vel + 1.0) / 2.0; // normalize to 0..1

    var encoded_vel: u32 = u32(nvel.x * u16max) | ((u32(nvel.y * u16max)) << 16u);

    return GridSlotEncoded( slot.id, encoded, encoded_vel, 0u);
}


// fn update_pos(
//     slot: ptr<function, GridSlot>, 
//     delta: vec2<f32>, 
//     grid_location: vec2<i32>
// ) -> vec2<i32> {

        
//         (*slot).pos = (*slot).pos + delta ;
//         let new_grid_location = floor((*slot).pos)


//         return new_grid_location;

// }


// sdf of a circle
fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
  let d = length(p - c);
  return d - r;
}


let bg = vec4<f32>(0.10210, 0.083, 0.186, 1.0);

// let purple = vec4<f32>(130.0 / 255.0, 106.0 / 255.0, 237.0 / 255.0, 1.0);
let purple = vec4<f32>(0.510, 0.416, 0.929, 1.0);

// let pink = vec4<f32>(200.0 / 255.0, 121.0 / 255.0, 255.0 / 255.0, 1.0);
let pink = vec4<f32>(0.784, 0.475, 1.0, 1.0);

// let c3 = vec4<f32>(255.0 / 255.0, 183.0 / 255.0, 255.0 / 255.0, 1.0);
let salmon = vec4<f32>(1.0, 0.718, 1.0, 1.0);

// let c4 = vec4<f32>(59.0 / 255.0, 244.0 / 255.0, 251.0 / 255.0, 1.0);
let aqua = vec4<f32>(0.231, 0.957, 0.984, 1.0);

// let c5 = vec4<f32>(202.0 / 255.0, 255.0 / 255.0, 138.0 / 255.0, 1.0);
let green = vec4<f32>(0.792, 1.0, 0.541, 1.0);
let brown = vec4<f32>(0.498, 0.41, 0.356, 1.0);
let beige = vec4<f32>(0.839, 0.792, 0.596, 1.0);
let dark_purple = vec4<f32>(0.447, 0.098, 0.353, 1.0);

// let red = vec4<f32>(1.0, 0.0, 0.0, 1.0);
// let green = vec4<f32>(0.0, 1.0, 0.0, 1.0);
// let blue = vec4<f32>(0.0, 0.0, 1.0, 1.0);
// let yellow = vec4<f32>(1.0, 1.0, 0.0, 1.0);
// let cyan = vec4<f32>(0.0, 1.0, 1.0, 1.0);

let black = vec4<f32>(0.0, 0.0, 0.0, 1.0);
let gray = vec4<f32>(0.051, 0.051, 0.051, 1.0);



fn sdXSegment(p: f32, x: f32) -> f32 {
    return length( p - x );
}




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

    let ball_radius_co = coef * ball_radius;
    let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius_co);

    return s;

   
}




@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    let float_loc = vec2<f32>(location);
    // let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

     

    let expansion_coefficient = uni.iResolution.x / f32(uni.grid_size.x);
    let grid_loc = vec2<i32>(vec2<f32>(location) / expansion_coefficient);



    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    var color = dark_purple / 1.3;
    color.a = 1.0;



    let co = expansion_coefficient;
    let co2 = co / 1.;

    // let sx = sdXSegment((float_loc.x + 0.5) % co, co2);
    // let sy = sdXSegment((float_loc.y + 0.5) % co, co2);
    // color = mix(color, beige, 1.0 - smoothstep(0.0, 3.0, sx));
    // color = mix(color, beige, 1.0 - smoothstep(0.0, 3.0, sy));

    var grid_color = dark_purple * 1.3;
    grid_color.a = 1.0;
    let sx = sdXSegment(float_loc.x % co, co2);
    let sy = sdXSegment(float_loc.y % co, co2);
    color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sx));
    color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sy));





    // let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
    // let slot: GridSlot = decode(slot_encoded);

    // todo:
    // 1) add velocity to GridSlot
    // 2) add collision with walls
    // 2) add gravity to forces step
    // 3) add collision detection
    // 

     let ball_radius_co = expansion_coefficient * ball_radius;

    //  let ball_radius = 20.;

    for (var i = -1; i < 2; i=i+1) {
        for (var j = -1; j < 2; j=j+1) {

            
            

            var neighbor_loc = grid_loc + vec2<i32>(i, j);

            // torus (pacman type boundaries)
            neighbor_loc = neighbor_loc % vec2<i32>(uni.grid_size.xy);

            let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
            var neighbor_slot = decode(neighbor_slot_encoded);


            if (neighbor_slot.mass > 0u) {

                // let ball_position = neighbor_slot.pos *   expansion_coefficient;
                
                let ball_position = (vec2<f32>(neighbor_loc) + neighbor_slot.pos ) *   expansion_coefficient;

                let s = sdCircle(vec2<f32>(location) , ball_position, ball_radius_co);

                var ball_color = pink;

                
                switch (neighbor_slot.kind) {
                    case 0u { ball_color = pink; }
                    case 1u { ball_color = salmon; }
                    case 2u { ball_color = aqua; }
                    // case 3u { ball_color = yellow; }
                    default { ball_color = green; }

                }

                color = mix(color, ball_color, 1.0 - smoothstep(-2.0, 0.0, s));
                color = mix(color, gray, 1.0 - smoothstep(-2.0, 3.0, abs(s)));
            }
        }
    }

    textureStore(texture, location, color);
}