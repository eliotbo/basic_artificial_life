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

// buffer_b 

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let grid_location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));


    let particle_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(grid_location)];
    var particle_slot = decode(particle_slot_encoded);

    // at the beginning of the simulation, delete all neighboring particles
    if uni.iFrame == 60.0 {
        for (var i = -1; i < 2; i=i+1) {
            for (var j = -1; j < 2; j=j+1) {
                
                if (i == 0 && j == 0) {
                    continue;
                }

                let neighbor_loc = grid_location + vec2<i32>(i, j);
                let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
                var neighbor_slot = decode(neighbor_slot_encoded);

                if (neighbor_slot.mass > 0u) {

                    let neighbor_rel_pos = neighbor_slot.pos
                        + vec2<f32>(f32(i), f32(j));
                    // let particle_pos = particle_slot.position;

                    

                    // slot.alive_neighbors = slot.alive_neighbors + 1;
                    if (length(neighbor_rel_pos - particle_slot.pos ) < 2. * ball_radius ) {
                        buffer_a.pixels[get_index(grid_location)] = empty_encoded_slot;
                        buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot;

                        // do_not_delete = false;

                        return;
                    }
                }
            }
        }
    }
        


    let slot_encoded = buffer_a.pixels[get_index(grid_location)];
    var slot = decode(slot_encoded);

    // estimate the updated position if there is a particle in the current grid_location
    if (slot.mass > 0u) {

        // let dummy_delta = vec2<f32>(-0.1, -0.05);


        // slot.pos = slot.pos + slot.vel ;

        var new_grid_loc = grid_location;

        if (slot.pos.x > 1.0) || (slot.pos.x < 0.0) || (slot.pos.y > 1.0) || (slot.pos.y < 0.0) {
            buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot;
        }

        // find the new grid location if the pos is outside of the 0 to 1 range
        if (slot.pos.x > 1.0) {
            new_grid_loc.x = (new_grid_loc.x + 1)  ;
            slot.pos.x = slot.pos.x - 1.0;

            // torus (pacman type boundaries)
            new_grid_loc.x = new_grid_loc.x % (i32(uni.grid_size.x) );
        } 

        if (slot.pos.y > 1.0) {
            new_grid_loc.y = (new_grid_loc.y + 1);
            slot.pos.y = slot.pos.y - 1.0;

            new_grid_loc = new_grid_loc % vec2<i32>(uni.grid_size.xy);
        }


        if (slot.pos.x < 0.0) {
            new_grid_loc.x = (new_grid_loc.x - 1);
            if (new_grid_loc.x < 0) {
                new_grid_loc.x = i32(uni.grid_size.x) - 1;
            } 

            slot.pos.x = 1.0 + slot.pos.x;
        } 

        if (slot.pos.y < 0.0) {
            new_grid_loc.y = (new_grid_loc.y - 1) ;

            if (new_grid_loc.y < 0) {
                new_grid_loc.y = i32(uni.grid_size.y) - 1;
            } 
            slot.pos.y = 1.0 + slot.pos.y;
        } 


        buffer_b.pixels[get_index(new_grid_loc)] = encode(slot);  
    }


    // let boom = &buffer_b.pixels[get_index(new_grid_loc)];
    // *boom = encode(slot);

    // buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot; 
    // buffer_b.pixels[get_index(new_grid_loc)] = encode(slot);  
    

    // buffer_b.pixels[get_index(grid_location)] = encode(slot);

    // if 

    // var new_grid_location = update_pos(&slot, dummy_delta, grid_location);
    // let new_grid_location = new_loc_did_change.xy;

    // let slot_abs_position = slot.pos + vec2<f32>(f32(new_grid_location.x), f32(new_grid_location.y));

    // let ball_radius = 0.25;

    // // collision detection

    // var nx: i32 = -2; // first index will be -1
    // loop {
    //     nx ++;
    //     if (nx > 1) {  break;  }
        

    //     var ny: i32 = -2;

    //     loop {
    //         ny++;
    //         if (ny > 1) { break; }
        

    //         let neighbor_loc = grid_location + vec2<i32>(nx, ny);
    //         let neighbor_slot_encoded: GridSlotEncoded = buffer_a.pixels[get_index(neighbor_loc)];
    //         var neighbor_slot = decode(neighbor_slot_encoded);

    //         // // skip with the neighboors's id is the same as the current slot
    //         if (slot.id == neighbor_slot.id) { 
    //             continue;  
    //         } 

    //         // let neigh_new_grid_location = update_pos(&neighbor_slot, dummy_delta, neighbor_loc);
            
    //         let neighbor_abs_position = neighbor_slot.pos 
    //             + vec2<f32>(neighbor_loc);

    //         let delta_pos = slot_abs_position - neighbor_abs_position;


    //         if (length(delta_pos) < 2.0 * ball_radius) {
    //             let delta_vec = delta_pos * (2.0 * ball_radius - length(delta_pos)) / 2.0;
    //             new_grid_location = update_pos(&slot, delta_vec, new_grid_location);
    //             break;


    //             // neighbor_slot.pos = neighbor_slot.pos - delta_pos / 2.;

    //         }

            
    //     }
        
    // }

        // buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot;
        // buffer_b.pixels[get_index(new_grid_location)] = encode(slot);        

        
           



        

}