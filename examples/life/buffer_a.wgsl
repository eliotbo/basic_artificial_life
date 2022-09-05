// grid size = 



@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));


    # ifdef INIT
        let rand = hash32(vec2<f32>(location + 1000) );
        // let rand = noise2d(vec2<f32>(location + 1000));

        var color = vec4<f32>(0.1, 0.2, 0.3, 1.0);
        let quoi = &buffer_a.pixels[get_index(location)] ;

        if (rand.x > 0.9) {
            let quoi = &buffer_a.pixels[get_index(location)] ;
            let rand_pos = hash32(vec2<f32>(location)).xy;
            // let pos = vec2<f32>(0.0, 0.0);
            var rand_kind = hash32(vec2<f32>(location + 100)).x;
            rand_kind = floor(rand_kind * 6.0);
            *quoi =  encode(GridSlot(rand_pos, 1u, 1u, u32(rand_kind)) );
                       
            
        } else {
            *quoi =  encode(GridSlot(vec2<f32>(0., 0.), 0u, 0u, 0u) );
        }



        return;
    # endif

    

    

}