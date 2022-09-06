// grid size = 



@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let grid_location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));


    # ifdef INIT
        let rand = hash32(vec2<f32>(grid_location + 1000) );
        // let rand = noise2d(vec2<f32>(grid_location + 1000));

        var color = vec4<f32>(0.1, 0.2, 0.3, 1.0);
        let quoi = &buffer_a.pixels[get_index(grid_location)];

        let expansion_coefficient = uni.iResolution.x / f32(uni.grid_size.x);

        // generate a particle if the random number allows it
        if (rand.x > 0.7) {
            let quoi = &buffer_a.pixels[get_index(grid_location)];

            // random position within the grid cell
            var rand_pos = hash32(vec2<f32>(grid_location)).xy;
            // rand_pos = clamp(rand_pos, vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 1.0));


            // random type of particle
            var rand_kind = hash32(vec2<f32>(grid_location + 100)).x;
            rand_kind = floor(rand_kind * 6.0);

            // random initial velocity
            let rand_vel = (hash32(vec2<f32>(grid_location + 200)).xy - 0.5) * 2. * max_vel;

            // generate random u32 for id
            let id = u32(hash32(vec2<f32>(grid_location + 300)).x * u32max); 



            *quoi =  encode(GridSlot(rand_pos, rand_vel, id, 1u, u32(rand_kind)) );
            return;
            
        } else {
            *quoi =  empty_encoded_slot;
            return;
        }


    # endif


    let encoded_b = &buffer_b.pixels[get_index(grid_location)];
    buffer_a.pixels[get_index(grid_location)] = *encoded_b;
    







    

}