// grid size = 



@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));


    # ifdef INIT
        let rand = hash32(vec2<f32>(location) );
        var color = vec4<f32>(0.1, 0.2, 0.3, 1.0);
        if (rand.x > 0.9) {
            color = vec4<f32>(0.3, 0.2, 0.1, 1.0);
        }

        let quoi = &buffer_a.pixels[get_index(location)] ;
        *quoi = color;
        return;
    # endif

    

    

}