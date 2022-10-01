
// struct GridBuffer {
//     pixels: array<vec4<f32>>,
// };

struct GridSlot {
    pos: vec2<f32>,
    vel: vec2<f32>,
    id: u32,
    mass: u32,
    kind: u32,
}

struct Trails {
    intensities: vec4<f32>,
}


struct GridSlotEncoded {
    id: u32,
    mass_kind_pos_encoded: u32,
    encoded_vel: u32,
    dummy: u32,
}

struct TrailBuffer {
    pixels: array<Trails>,
};

struct GridBuffer {
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
 var<storage, read_write> buffer_a: GridBuffer;

@group(0) @binding(2)
 var<storage, read_write> buffer_b: GridBuffer;

@group(0) @binding(3)
 var<storage, read_write> buffer_c: TrailBuffer;

@group(0) @binding(4)
 var<storage, read_write> buffer_d: GridBuffer;


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
let yellow = vec4<f32>(0.792, 1.0, 0.541, 1.0);
let brown = vec4<f32>(0.498, 0.41, 0.356, 1.0);
let beige = vec4<f32>(0.839, 0.792, 0.596, 1.0);
let dark_purple = vec4<f32>(0.447, 0.098, 0.353, 1.0);

// 12, 202, 74
// let dark_green = vec4<f32>(12.0 / 255.0, 202.0 / 255.0, 74.0 / 255.0, 1.0);
let dark_green = vec4<f32>(0.047, 0.792, 0.290, 1.0);


// let soft_gray =  vec4<f32>(68.0 / 255.0, 64.0 / 255.0, 84.0 / 255.0, 1.0);
let soft_gray =  vec4<f32>(0.267, 0.251, 0.329, 1.0);

let black = vec4<f32>(0.0, 0.0, 0.0, 1.0);
let gray = vec4<f32>(0.051, 0.051, 0.051, 1.0);

// let blue = vec4<f32>(21, 244, 238);
let blue = vec4<f32>(0.082, 0.957, 0.933, 1.0);


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
let u8max = 255.0;
let u16max = 65535.0;
let u32max = 4294967295.0;

let max_vel = 0.2;


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



//
//
//
//
let vel_damping = 1.0;
// let gravity = 0.02;
let gravity = 0.0;
let max_trail_intensity = 2.0;
let trail_decay = 0.95;
let ball_radius = 0.51;


fn update_pos( slot_in: ptr<function, GridSlot>, grid_loc: vec2<i32> ) {

    var slot = *slot_in;

    var mouse_force = vec2<f32>(0., 0.);

    let particle_pos = slot.pos + vec2<f32>(grid_loc);

    

    if (uni.iMouse.z > 0.0 ) {
        let eco = uni.iResolution.x / f32(uni.grid_size.x);
        let mouse_pos = vec2<f32>(uni.iMouse.x, uni.iResolution.y-uni.iMouse.y) / eco ;
        let mouse_force_dir = normalize(mouse_pos - particle_pos);
        mouse_force = mouse_force_dir * 0.7;
    }

    let total_force = vec2<f32>(0., gravity) + mouse_force;

    slot.vel  = slot.vel * vel_damping + total_force * uni.iTimeDelta;

    //
    //
    //
    // clamping velocity is important to avoid encoding/decoding errors
    slot.vel = clamp(slot.vel, vec2<f32>(-max_vel), vec2<f32>(max_vel));
    slot.pos = slot.pos + slot.vel ;

    *slot_in = slot;
}

// checks whether a point has moved out of a grid cell or has hit a wall
fn correct_grid_slot(
    slot_in: ptr<function, GridSlot>, 
    grid_location: vec2<i32>
) -> vec2<i32> {

    var slot: GridSlot  = *slot_in;
    var new_grid_loc = grid_location;


    // find the new grid location if the pos is outside of the 0 to 1 range
    if (slot.pos.x > 1.0) {
        // wall collision
        if (new_grid_loc.x == i32(uni.grid_size.x) - 1) {
            slot.pos.x = 0.99;
            slot.vel.x = -slot.vel.x;
        } else {
            let num_grid_cells = floor(slot.pos.x);
            new_grid_loc.x = new_grid_loc.x + i32(num_grid_cells);
            slot.pos.x = slot.pos.x - num_grid_cells;
        }
    } 

    if (slot.pos.y > 1.0) {
        // wall collision
        if (new_grid_loc.y == i32(uni.grid_size.y) - 1) {
            slot.pos.y = 0.99;
            slot.vel.y = -slot.vel.y;

        } else {
            let num_grid_cells = floor(slot.pos.y);
            new_grid_loc.y = new_grid_loc.y + i32(num_grid_cells);
            slot.pos.y = slot.pos.y - num_grid_cells;
        }

    }


    if (slot.pos.x < 0.0) {
        if (new_grid_loc.x == 0) {
            slot.pos.x = 0.01;
            slot.vel.x = -slot.vel.x;
        } else {

            let num_grid_cells = 1.0 + floor(-slot.pos.x);
            new_grid_loc.x = new_grid_loc.x - i32(num_grid_cells);
            slot.pos.x = slot.pos.x + num_grid_cells;
        }
    } 

    if (slot.pos.y < 0.0) {
        if (new_grid_loc.y == 0) {
            slot.pos.y = 0.01;
            slot.vel.y = -slot.vel.y;
        } else {

            let num_grid_cells = 1.0 + floor(-slot.pos.y);
            new_grid_loc.y = new_grid_loc.y - i32(num_grid_cells);
            slot.pos.y = slot.pos.y + num_grid_cells;
        }
    } 

    *slot_in = slot; 

    return new_grid_loc;


}

// // compute elastic collisions between two balls
// fn collide(
//     slot_a: ptr<function, GridSlot>, 
//     // grid_pos_a: vec2<i32>,
//     slot_b: ptr<function, GridSlot>,
//     // grid_pos_b: vec2<i32>,
//     delta: vec2<f32>
// ) {

//     var a: GridSlot = *slot_a;
//     var b: GridSlot = *slot_b;

//     // let delta = b.pos - a.pos;

//     let dist = length(delta);
//     let overlap = ball_radius * 2.0 - dist;

//     if (overlap > 0.0) {



//         let dir = normalize(delta);
//         let a_vel = a.vel;
//         let b_vel = b.vel;

//         a.pos = a.pos + dir * overlap * 0.5;
//         b.pos = b.pos - dir * overlap * 0.5;

//         let a_vel_n = dot(a_vel, dir);
//         let b_vel_n = dot(b_vel, dir);

//         let a_vel_t = a_vel - dir * a_vel_n;
//         let b_vel_t = b_vel - dir * b_vel_n;

//         let a_vel_n_new =   b_vel_n;
//         let b_vel_n_new =   a_vel_n;

//         a.vel = a_vel_t + dir * a_vel_n_new;
//         b.vel = b_vel_t + dir * b_vel_n_new;

//         *slot_a = a;
//         *slot_b = b;
//     }
// }

// compute elastic collisions between two balls
fn collide(
    slot_a: ptr<function, GridSlot>, 
    a_loc: vec2<i32>,
    slot_b: ptr<function, GridSlot>,
    b_loc: vec2<i32>,

) {

    var a: GridSlot = *slot_a;
    var b: GridSlot = *slot_b;

    // let delta = b.pos - a.pos;

    var a_pos = a.pos + vec2<f32>(a_loc);
    var b_pos = b.pos + vec2<f32>(b_loc);



    let delta = a_pos - b_pos;

    let dist = length(delta);
    let overlap = ball_radius * 2.0 - dist;

    if (dist < ball_radius * 2.0) {

        // let m1 = f32(a.mass);
        // let m2 = f32(b.mass);

        // let dir = normalize(delta);
        // let a_vel = a.vel;
        // let b_vel = b.vel;

        // a_pos = a_pos + dir * overlap * 1.0;
        // b_pos = b_pos - dir * overlap * 1.0;

        // let a_vel_n = dot(a_vel, dir);
        // let b_vel_n = dot(b_vel, dir);

        // let a_vel_t = a_vel - dir * a_vel_n;
        // let b_vel_t = b_vel - dir * b_vel_n;

        // let a_vel_n_new = (a_vel_n * (m1 - m2) + 2.0 * m2 * b_vel_n) / (m1 + m2);
        // let b_vel_n_new = (b_vel_n * (m2 - m1) + 2.0 * m1 * a_vel_n) / (m1 + m2);

        // a.vel = a_vel_t + dir * a_vel_n_new;
        // b.vel = b_vel_t + dir * b_vel_n_new;

        // a.vel = clamp(a.vel, -vec2<f32>(max_vel), vec2<f32>(max_vel));
        // b.vel = clamp(b.vel, -vec2<f32>(max_vel), vec2<f32>(max_vel));

        a.vel = a.vel - dot(delta, a.vel - b.vel) * delta / dot(delta, delta);
        a_pos = a_pos + normalize(delta) * overlap * 0.99;




        a.pos = a_pos - vec2<f32>(a_loc);
         
        // b.pos = b_pos - vec2<f32>(b_loc);

        *slot_a = a;
        // *slot_b = b;
    }
}


// sdf of a circle
fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
  let d = length(p - c);
  return d - r;
}






fn sdXSegment(p: f32, x: f32) -> f32 {
    return length( p - x );
}

fn sdBox(p: vec2<f32>, b: vec2<f32>) -> f32 {
	let d: vec2<f32> = abs(p) - b;
	return length(max(d, vec2<f32>(0.))) + min(max(d.x, d.y), 0.);
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

     
    // expansion coefficient
    let eco = uni.iResolution.x / f32(uni.grid_size.x);
    let grid_loc = vec2<i32>(vec2<f32>(location) / eco);

    let ball_radius_co = eco * ball_radius;

    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    let background_color = vec4<f32>(0.1, 0.1, 0.1, 1.0) / 3.;
    // let background_color = soft_gray;
    // var color = dark_purple / 4.0;
    var color = background_color;
    color.a = 1.0;



    let co = eco;
    let co2 = co / 1.;

    var grid_color = background_color * 1.3;
    grid_color.a = 1.0;
    let sx = sdXSegment(float_loc.x % co, co2);
    let sy = sdXSegment(float_loc.y % co, co2);
    color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sx));
    color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sy));


    // //////////////////// trails ///////////////////////////////////////
    let non_normalized_trail = buffer_c.pixels[get_index(grid_loc)].intensities;
    var trail = non_normalized_trail / max_trail_intensity;
    // let trail_sdf = sdCircle(vec2<f32>(location) , (vec2<f32>(grid_loc ) + 0.5) * eco, ball_radius_co);
    let trail_sdf = sdBox(vec2<f32>(location) , (vec2<f32>(grid_loc ) + 1.) * eco);

    var bright_blue = blue * 1.4;

    bright_blue.a = (trail.x + trail.y + trail.z + trail.w) / 4.0; 
    var transparent_green = bright_blue;
    transparent_green.a = 0.0;

    let trail_green = mix(transparent_green, bright_blue, 1.0 - smoothstep(-2.0, 0.0, trail_sdf));


    color = mix(color, trail_green, trail_green.a / 10.0);


    // //////////////////// trails ///////////////////////////////////////






    // let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
    // let slot: GridSlot = decode(slot_encoded);

    // todo:

    // 2) add gravity to forces step
    // 3) add collision detection
    // 

    let ball_brightness = 1.2;

    //  let ball_radius = 20.;

    for (var i = -1; i < 2; i=i+1) {
        for (var j = -1; j < 2; j=j+1) {

            
            

            var neighbor_loc = grid_loc + vec2<i32>(i, j);

            // torus (pacman type boundaries)
            neighbor_loc = neighbor_loc % vec2<i32>(uni.grid_size.xy);

            let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
            var neighbor_slot = decode(neighbor_slot_encoded);


            if (neighbor_slot.mass > 0u) {

                // let ball_position = neighbor_slot.pos *   eco;
                
                let ball_position = (vec2<f32>(neighbor_loc) + neighbor_slot.pos ) *   eco;

                let s = sdCircle(vec2<f32>(location) , ball_position, ball_radius_co);

                var ball_color = pink;

                
                switch (neighbor_slot.kind) {
                    case 0u { ball_color = pink * ball_brightness; }
                    case 1u { ball_color = salmon * ball_brightness; }
                    case 2u { ball_color = aqua * ball_brightness; }
                    case 3u { ball_color =  vec4<f32>(0.082, 0.3, 0.933, 1.0); }
                    default { ball_color = dark_green * ball_brightness; }

                }

                color = mix(color, ball_color, 1.0 - smoothstep(-2.0, 0.0, s));
                color = mix(color, gray, 1.0 - smoothstep(-2.0, 2.0, abs(s)));
            }
        }
    }

    textureStore(texture, location, color);
}