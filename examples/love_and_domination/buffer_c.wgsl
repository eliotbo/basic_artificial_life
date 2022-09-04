var<private>  R: vec2<f32>;
// fn A(location: vec2<f32>) -> vec4<f32> {
// 	return textureLoad(buffer_a, vec2<i32>(location)) * texture_const;
// } 

fn B(location: vec2<f32>)-> vec4<f32> {
	// return textureLoad(buffer_b, vec2<i32>(location)) * texture_const;
	return buffer_b.pixels[get_index( vec2<i32>(location))]  * texture_const;
} 

fn C(location: vec2<f32>) -> vec4<f32> {
	// return textureLoad(buffer_c, vec2<i32>(location)) * texture_const;
	return buffer_c.pixels[get_index( vec2<i32>(location))]  * texture_const;
} 



[[stage(compute), workgroup_size(8, 8, 1)]]
fn update([[builtin(global_invocation_id)]] invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
// }

// fn mainImage( Q: vec4<f32>,  U: vec2<f32>) -> () {

    let U = vec2<f32>(f32(location.x), f32(location.y));
	R = uni.iResolution.xy;
	var Q = vec4<f32>(0.);
	for (var i: f32 = -BLUR_DEPTH; i <= BLUR_DEPTH; i = i + 1.) {
		let c: vec4<f32> = B(U + vec2<f32>(0., i));
		Q = Q + (2. * c * sqrt(s2) / s2 * exp(-i * i * 0.5 / s2));
	
	}	
    Q = mix(Q, C(U), 0.1);
    // textureStore(buffer_c, location, Q / texture_const);
	buffer_c.pixels[get_index(location)] = Q / texture_const;


    // Q = textureLoad(buffer_b, vec2<i32>(location));
    // textureStore(buffer_c, location, Q);


} 
