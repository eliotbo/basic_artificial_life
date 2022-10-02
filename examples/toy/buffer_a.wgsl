// RUST_LOG="wgpu=error,naga=warn,info" cargo run --release --example simpler_particles  

// fn Integrate2(
// 	ch: ptr<storage, GridBuffer>, 
// 	P: ptr<function, Particle>, 
// 	pos: vec2<f32>
// )  {
//     var data: GridSlotEncoded = ch.pixels[get_index(vec2<i32>(tpos))];
// }

fn Integrate(
	// ch: array<GridSlotEncoded>, 
    // ch: ptr<storage, GridBuffer, read>,
	P: ptr<function, Particle>, 
	pos: vec2<f32>
)  {
	var I: i32 = i32(ceil(particle_size));
    // var I: i32 = 3;
    var did_find_particle: bool = false;
    

	for (var i: i32 = -I; i <= I; i = i + 1) {
	for (var j: i32 = -I; j <= I; j = j + 1) {
		let tpos: vec2<f32> = pos + vec2<f32>(f32(i), f32(j));

        var data: GridSlotEncoded = buffer_d.pixels[get_index(vec2<i32>(tpos))];
		// let data: vec4<f32> = textureLoad(ch, vec2<i32>(tpos));

		if (tpos.x < 0. || tpos.y < 0.) {		continue; }

		var P0: Particle = getParticle(data, tpos);

		if (
			(P0.NX.x >= pos.x - 0.5 && P0.NX.x < pos.x + 0.5) 
			&& (P0.NX.y >= pos.y - 0.5) 
			&& (P0.NX.y < pos.y + 0.5) 
			&& (P0.M > 0.5)
		) {
			var P0V: vec2<f32> = (P0.NX - P0.X) / 2.;

			if (uni.iMouse.z > 0.) {
				let dm: vec2<f32> = P0.NX - uni.iMouse.xy / R2G;
				let d: f32 = length(dm / 50.) * R2G.x;
				P0V = P0V + (normalize(dm) * exp(-d * d) * 0.3);
			}

			P0V = P0V + (vec2<f32>(0., -0.005));
			let v: f32 = length(P0V);
			var denom = 1.; 
			if (v > 1.) { denom = v; }
			P0V = P0V / denom;
			P0.X = P0.NX;
			P0.NX = P0.NX + P0V * 2.;
			(*P) = P0;

            did_find_particle = true;
			break;
		}
	}

	}

    if (!did_find_particle) {
        (*P) = Particle(
            vec2<f32>(0.), 
            vec2<f32>(0.), 
            0., 0., 0u, 0.
        );
    }

} 



@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    // let R: vec2<f32> = uni.iResolution.xy;
    let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    
	// var U: vec4<f32>;
	var pos = vec2<f32>(f32(location.x), f32(location.y) );

	R = uni.iResolution.xy;
    R2G = R / vec2<f32>(uni.grid_size.xy);
	rng_initialize(pos, i32(uni.iFrame));
	var P: Particle;

    

    // var ddd = buffer_d;
	Integrate(&P, pos);


	#ifdef INIT
		if (rand() > 0.902) {
			P.X = pos;
			P.NX = pos + (rand2() - 0.5) * 0.;
			let r: f32 = pow(rand(), 2.);
			P.M = mix(1., 4., r);
			P.R = mix(1., particle_size, r);
            P.K = u32(rand4().a * 5.0);
            // P.K = 1u;
		} else { 
			P.X = pos;
			P.NX = pos;
			P.M = 0.;
			P.R = particle_size * 0.5;
            P.K = 0u;
		}
	// }
	#endif
    

	let U: GridSlotEncoded = saveParticles(P, P, pos);

    buffer_a.pixels[get_index(location)] = U;
	// textureStore(buffer_a, location, U);
    
} 


