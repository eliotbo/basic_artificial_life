// buffer_b 

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let grid_location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    // // at the beginning of the simulation, delete all neighboring particles
    // if uni.iFrame == 2.0 {
    //     for (var i = -1; i < 2; i=i+1) {
    //         for (var j = -1; j < 2; j=j+1) {
                
    //             if (i == 0 && j == 0) {
    //                 continue;
    //             }

    //             let neighbor_loc = grid_location + vec2<i32>(i, j);
    //             let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
    //             var neighbor_slot = decode(neighbor_slot_encoded);

    //             if (neighbor_slot.mass > 0u) {
    //                 // slot.alive_neighbors = slot.alive_neighbors + 1;
    //                 buffer_a.pixels[get_index(grid_location)] = empty_encoded_slot;
    //                 buffer_b.pixels[get_index(grid_location)] = empty_encoded_slot;

    //                 // do_not_delete = false;

    //                 return;
    //             }
    //         }
    //     }
    // }
        


    let slot_encoded = buffer_a.pixels[get_index(grid_location)];
    var slot = decode(slot_encoded);

    if (slot.mass > 0u) {

        let dummy_delta = vec2<f32>(-0.1, -0.05);

        // slot.pos = slot.pos + dummy_delta ;
        slot.pos = slot.pos + slot.vel ;

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


        

        // 

        // clamp 
        // new_grid_loc = clamp(vec2<i32>(0, 0), vec2<i32>(uni.grid_size.xy), new_grid_loc); 


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