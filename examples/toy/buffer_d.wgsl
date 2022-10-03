
fn Simulation(
	// ch: ptr<storage, GridBuffer, read>,  
    // ch: array<GridSlotEncoded>, 
	P: ptr<function, Particle>, 
	pos: vec2<f32>
)  {
	var F: vec2<f32> = vec2<f32>(0.);
	var I: i32 = i32(ceil(particle_size)) + 2;
	// var I: i32 = 4;

	for (var i: i32 = -I; i <= I; i = i + 1) {
	for (var j: i32 = -I; j <= I; j = j + 1) {

		if (i == 0 && j == 0) {		continue;   }


		let tpos: vec2<f32> = pos + vec2<f32>(f32(i), f32(j));

        var data: GridSlotEncoded = buffer_c.pixels[get_index(vec2<i32>(tpos))];
        // var data: GridSlotEncoded = (*ch).pixels[get_index(vec2<i32>(tpos))];
		// let data: vec4<f32> = textureLoad(ch, vec2<i32>(tpos));

		let P0: Particle = getParticle(data, tpos);

		// if the cell is empty, no compute is needed
		if (P0.M == 0.) {	continue;   }

		let dx: vec2<f32> = P0.NX - (*P).NX;
		var d: f32 = length(dx);
		var r: f32 = (*P).R + P0.R;

		var m: f32 = 2. / (*P).M / (1. / (*P).M + 1. / P0.M);

		m = ((*P).M - P0.M) / ((*P).M + P0.M) + 2. * P0.M / ((*P).M + P0.M);

		m = P0.M / ((*P).M + P0.M);

		if (d < r) { F = F - (normalize(dx) * (r - d) * m); }
	}
	}

	// let dp: vec2<f32> = (*P).NX * R2G;

    let dp: vec2<f32> = (*P).NX * R2G;
	var d: f32 = border_r(dp, (*P).R);

	if (d < 0.) { F = F - (bN(dp).xy * d); }
	(*P).NX = (*P).NX + (F * 0.9 / 3.);
}



@compute @workgroup_size(16, 16, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    // let R: vec2<f32> = uni.iResolution.xy;
    // let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    
	// var U: vec4<f32>;
	var pos = vec2<f32>(f32(location.x), f32(location.y) );

	R = uni.iResolution.xy;
    Grid = vec2<f32>(uni.grid_size.xy);
    R2G = R / vec2<f32>(uni.grid_size.xy);

	time = uni.iTime;
	Mouse = uni.iMouse;

    var data: GridSlotEncoded = buffer_c.pixels[get_index(vec2<i32>(pos))];

	// let data: vec4<f32> = textureLoad(buffer_c, vec2<i32>(pos));

	var P: Particle = getParticle(data, pos);

    if (P.M > 0.) { Simulation(&P, pos); }
	// if (P.M > 0.) { Simulation(&buffer_c, &P, pos); }

	let U: GridSlotEncoded = saveParticles(P, P, pos);

    buffer_d.pixels[get_index(location)] = U;
	// textureStore(buffer_d, location, U);
} 

