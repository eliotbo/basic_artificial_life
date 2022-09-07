
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

let max_vel = 0.1;


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
let vel_damping = 0.999;
// let gravity = 0.02;
let gravity = 0.0;
let max_trail_intensity = 2.0;
let trail_decay = 0.95;
let ball_radius = 0.5;


// checks whether a point has moved out of a grid cell or has hit a wall
fn update_pos(
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

        let va = a.vel - dot(delta, a.vel - b.vel) * delta / dot(delta, delta);
        a_pos = a_pos + normalize(delta) * overlap * 0.5;




        a.pos = a_pos - vec2<f32>(a_loc);
        a.vel = va;
        // b.pos = b_pos - vec2<f32>(b_loc);

        *slot_a = a;
        // *slot_b = b;
    }
}