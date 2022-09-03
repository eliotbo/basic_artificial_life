var<private> R: vec2<f32>;

fn D(location: vec2<f32>) -> vec4<f32> {
	return buffer_d.pixels[get_index( vec2<i32>(location))]  * texture_const;
} 




[[stage(compute), workgroup_size(8, 8, 1)]]
fn update([[builtin(global_invocation_id)]] invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let U = vec2<f32>(f32(location.x), f32(location.y));



	R = uni.iResolution.xy;
	let n: vec4<f32> = D(U + vec2<f32>(0., 1.));
	let e: vec4<f32> = D(U + vec2<f32>(1., 0.));
	let s: vec4<f32> = D(U + vec2<f32>(0., -1.));
	let w: vec4<f32> = D(U + vec2<f32>(-1., 0.));
	let dx: vec4<f32> = e - w;
	let dy: vec4<f32> = n - s;
	var Q = (D(U) + abs(dx) + abs(dy)) / 3.;

    textureStore(texture, location, Q);
	


} 