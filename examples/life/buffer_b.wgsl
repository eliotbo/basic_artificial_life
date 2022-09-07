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


        // update position and velocity

        slot.vel  = slot.vel * vel_damping + abs(vec2<f32>( 0.0, gravity ) * uni.iTimeDelta);

        //
        //
        //
        // clamping velocity is important to avoid encoding/decoding errors
        slot.vel = clamp(slot.vel, vec2<f32>(-max_vel), vec2<f32>(max_vel));
        slot.pos = slot.pos + slot.vel ;

        var new_grid_loc = update_pos(&slot, grid_location);

        let slot_abs_position = slot.pos + vec2<f32>(new_grid_loc);

        var nx: i32 = -2; // first index will be -1
        loop {
            nx ++;
            if (nx > 1) {  break;  }
            

            var ny: i32 = -2;

            loop {
                ny++;
                if (ny > 1) { break; }
            

                let neighbor_loc = new_grid_loc + vec2<i32>(nx, ny);
                let neighbor_slot_encoded: GridSlotEncoded = buffer_a.pixels[get_index(neighbor_loc)];
                var neighbor_slot = decode(neighbor_slot_encoded);

                if (neighbor_slot.mass == 0u) {
                    continue;
                }

                // // skip with the neighboors's id is the same as the current slot
                // if (slot.id == neighbor_slot.id) { 
                //     continue;  
                // } 

                if ( (nx == 0) && (ny == 0) ) { 
                    continue;  
                } 

                if (neighbor_slot.id == slot.id) { 
                    continue;  
                }

                let neigh_new_grid_location = update_pos(&neighbor_slot, neighbor_loc);
                


                collide(
                    &slot, 
                    new_grid_loc, 
                    &neighbor_slot, 
                    neigh_new_grid_location, 
                );

                new_grid_loc = update_pos(&slot, new_grid_loc);



                // if (length(delta_pos) < 2.0 * ball_radius) {
                //     let delta_vec = delta_pos * (2.0 * ball_radius - length(delta_pos)) / 2.0;
                    

                //     // new_grid_loc = update_pos(&slot, delta_vec, new_grid_loc);
                //     break;


                //     // neighbor_slot.pos = neighbor_slot.pos - delta_pos / 2.;

                // }

                
            }
            
        }

        buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot;
        buffer_b.pixels[get_index(new_grid_loc)] = encode(slot);  
    }

    
    
    
        

}