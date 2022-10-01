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


        // // update position and velocity

        // slot.vel  = slot.vel * vel_damping + abs(vec2<f32>( 0.0, gravity ) * uni.iTimeDelta);

        // //
        // //
        // //
        // // clamping velocity is important to avoid encoding/decoding errors
        // slot.vel = clamp(slot.vel, vec2<f32>(-max_vel), vec2<f32>(max_vel));
        // slot.pos = slot.pos + slot.vel ;

        // here is  THE PROBLEM
        // say a particle does change grid location, then it means that it scans grid locations that
        // are closer to its new position, but the neighboring particles will not necessarily see
        // the particles that just changed grid location

        // solution?
        // maybe we can do a second pass to watch for collisions using the old grid location and the 
        // new grid location

        // xxxxxxxx
        // xxxxxxxx
        // x...,xxx
        // x.az,xxx
        // x...,xxx
        // xxxxxxxx

        // maybe no need for second pass. Just need to scan a wider range of grid locations 

        // naaaah, this is all bull#@$%!! 
        // since I can turn the culprits blue, I know that the problem is actually in the constraint
        // solver. Let's read the contraint paper again

        // possible solution: increase the mass instead of turning blue, try to keep momentum
        // and spontaneously devide particle into two later

        // for debugging: atomic counter that keeps track of the number of particles

        // perhaps a solution is to have a repulsive force among neighbors, that way the collisions
        // are softer?

        update_pos(&slot, grid_location);

        var new_grid_loc = correct_grid_slot(&slot, grid_location);

        let delta_grid = new_grid_loc - grid_location;

        let slot_abs_position = slot.pos + vec2<f32>(new_grid_loc);

        var x_range = vec2<i32>(-1, 1);

        if (delta_grid.x < 0) {
            x_range = vec2<i32>(-2, 1);
        } else if (delta_grid.x > 0) {
            x_range = vec2<i32>(-1, 2);
        }

        var y_range = vec2<i32>(-1, 1);

        if (delta_grid.y < 0) {
            y_range = vec2<i32>(-2, 1);
        } else if (delta_grid.y > 0) {
            y_range = vec2<i32>(-1, 2);
        }

        var nx: i32 = x_range.x - 1; // first index will be -1
        loop {
            nx ++;
            if (nx > x_range.y) {  break;  }
            

            var ny: i32 = y_range.x - 1;

            loop {
                ny++;
                if (ny > y_range.y) { break; }
            

                let neighbor_loc = grid_location + vec2<i32>(nx, ny);
                let neighbor_slot_encoded: GridSlotEncoded = buffer_a.pixels[get_index(neighbor_loc)];
                var neighbor_slot = decode(neighbor_slot_encoded);

                if (neighbor_slot.mass == 0u) {
                    continue;
                }

                // // skip with the neighboors's id is the same as the current slot
                // if (slot.id == neighbor_slot.id) { 
                //     continue;  
                // } 

                // if ( (nx == 0) && (ny == 0) ) { 
                //     continue;  
                // } 

                if (neighbor_slot.id == slot.id) { 
                    continue;  
                }

                

                // neighbor_slot.vel  = neighbor_slot.vel * vel_damping + abs(vec2<f32>( 0.0, gravity ) * uni.iTimeDelta);

                // //
                // //
                // //
                // // clamping velocity is important to avoid encoding/decoding errors
                // neighbor_slot.vel = clamp(neighbor_slot.vel, vec2<f32>(-max_vel), vec2<f32>(max_vel));
                // neighbor_slot.pos = neighbor_slot.pos + neighbor_slot.vel ;

                 update_pos(&neighbor_slot, neighbor_loc);
                
                let neigh_new_grid_location = correct_grid_slot(&neighbor_slot, neighbor_loc);

                collide(
                    &slot, 
                    new_grid_loc, 
                    &neighbor_slot, 
                    neigh_new_grid_location, 
                );

                new_grid_loc = correct_grid_slot(&slot, new_grid_loc);

                if (new_grid_loc.x == neigh_new_grid_location.x) && (new_grid_loc.y == neigh_new_grid_location.y) {
                // if (new_grid_loc == neigh_new_grid_location) {
                    slot.kind = 3u;
                }




                
            }
            
        }

        buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot;
        buffer_b.pixels[get_index(new_grid_loc)] = encode(slot);  
    }

    
    
    
        

}