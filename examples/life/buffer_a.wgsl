@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

    // let color = vec4<f32>(0.5);
    let color = vec4<f32>(0.1, 0.2, 0.3, 1.0);
    // textureStore(buffer_a, location, color);
    // buffer_a.pixels[get_index(location)] = color;

    let quoi = &buffer_a.pixels[get_index(location)] ;
    *quoi = color;
}