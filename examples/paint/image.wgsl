[[stage(compute), workgroup_size(8, 8, 1)]]
fn update([[builtin(global_invocation_id)]] invocation_id: vec3<u32>) {
    let R: vec2<f32> = uni.iResolution.xy;
    let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    var alive = true;

    // var O: vec4<f32> =  mix(bufferLoad(location),vec4<f32>(0.5), 0.1);
     var O: vec4<f32> =  mix(buffer_a.pixels[get_index(location)],vec4<f32>(0.5), 0.1);



    textureStore(texture, y_inverted_location, O);
}