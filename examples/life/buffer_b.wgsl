@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

}