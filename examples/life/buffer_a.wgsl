// grid size = 



@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let grid_location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    // let buffer_grid_location_index = get_index(vec2<i32>(invocation_id.xy));


    var i_dont_get_it = true;

    # ifdef INIT
        let rand = hash32(vec2<f32>(grid_location + 1000) );
        // let rand = noise2d(vec2<f32>(grid_location + 1000));

        var color = vec4<f32>(0.1, 0.2, 0.3, 1.0);
        let quoi = &buffer_a.pixels[get_index(grid_location)] ;

        let expansion_coefficient = uni.iResolution.x / f32(uni.grid_size.x);

        if (rand.x > 0.9) {
            let quoi = &buffer_a.pixels[get_index(grid_location)] ;

            // let rand_pos = hash32(vec2<f32>(grid_location)).xy 
            //     * vec2<f32>(f32(uni.grid_size.x), f32(uni.grid_size.y));

            // let grid = vec2<f32>(f32(uni.grid_size.x), f32(uni.grid_size.y));

            // let rand_pos = vec2<f32>(grid_location) + hash32(vec2<f32>(grid_location)).xy;
            var rand_pos = hash32(vec2<f32>(grid_location)).xy;
            rand_pos = clamp(rand_pos, vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 1.0));

            // let rand_pos = hash32(vec2<f32>(grid_location)).xy 
            //     * vec2<f32>(f32(uni.iResolution.x), f32(uni.iResolution.y));

            // let pos = vec2<f32>(0.0, 0.0);
            var rand_kind = hash32(vec2<f32>(grid_location + 100)).x;
            rand_kind = floor(rand_kind * 6.0);

            let rand_vel = (hash32(vec2<f32>(grid_location + 200)).xy - 0.5) * 2. * max_vel;

            // generate random u32 for id
            let id = u32(hash32(vec2<f32>(grid_location + 300)).x * u32max); 



            *quoi =  encode(GridSlot(rand_pos, rand_vel, id, 1u, u32(rand_kind)) );
                       
            
        } else {
            *quoi =  empty_encoded_slot;
        }

        i_dont_get_it = false;


    // #else

        // let encoded_b = &buffer_b.pixels[get_index(grid_location)];
        // buffer_a.pixels[get_index(grid_location)] = *encoded_b;

        // let quoi = &buffer_a.pixels[get_index(grid_location)] ;

        // var slot = decode(*quoi);
        // let new_pos = slot.pos + slot.vel / 1000000.0 ;

        // var new_grid_location = grid_location;

        // if (new_pos.x < 0.) {
        //     new_grid_location = vec2<i32>(grid_location.x - 1, grid_location.y);
        //     slot.pos.x = 1. + new_pos.x;
        // }
        
        // if (new_pos.x > 1.) {
        //     new_grid_location = vec2<i32>(grid_location.x + 1, grid_location.y);
        //     slot.pos.x = new_pos.x - 1.;
        // }
         
        // if (new_pos.y < 0.) {
        //     new_grid_location = vec2<i32>(grid_location.x, grid_location.y - 1);
        //     slot.pos.y = 1. + new_pos.y;
        // }

        // if (new_pos.y > 1.) {
        //     new_grid_location = vec2<i32>(grid_location.x, grid_location.y + 1);
        //     slot.pos.y = new_pos.y - 1.;
        // }

        // if (new_pos.x < 0.) || (new_pos.x > 1.) || (new_pos.y < 0.) || (new_pos.y > 1.) {
        //     let new_quoi = &buffer_a.pixels[get_index(new_grid_location)];
        //     *new_quoi = encode(slot);


        //     // *quoi = empty_encoded_slot;



        // } else {
        //     slot.pos = new_pos;
        //     *quoi = encode(slot);

            
        // }

        

    # endif

    if i_dont_get_it {
        let encoded_b = &buffer_b.pixels[get_index(grid_location)];
        buffer_a.pixels[get_index(grid_location)] = *encoded_b;
    }




    

    // neighbor_slot.pos = new_pos;

    // let new_encoded_slot = encode(neighbor_slot);

    // buffer_a.pixels[get_index(neighbor_loc)] = new_encoded_slot;



    

    

}