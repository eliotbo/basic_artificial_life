// struct GridBuffer {
//     pixels: array<vec4<f32>>,
// };

// struct GridSlot {
//     pos: vec2<f32>,
//     vel: vec2<f32>,
//     id: u32,
//     mass: u32,
//     kind: u32,
// }

struct Particle {
	X: vec2<f32>,
	NX: vec2<f32>,
	R: f32,
	M: f32,
    dummy: vec2<f32>,
};

struct GridSlot {
    particle1: Particle,
    particle2: Particle,
};

struct Trails {
    intensities: vec4<f32>,
};

struct GridSlotEncoded {
    particle1: Particle,
    particle2: Particle,
};

struct TrailBuffer {
    pixels: array<Trails>,
};

struct GridBuffer {
    pixels: array<GridSlotEncoded>,
};

struct CommonUniform {
    iResolution: vec2<f32>,
    changed_window_size: f32,
    padding0: f32,
    
    iTime: f32,
    iTimeDelta: f32,
    iFrame: f32,
    iSampleRate: f32,
    iMouse: vec4<f32>,
    
    forces: mat4x4<f32>,
    grid_size: vec4<u32>,
};


@group(0) @binding(0)
var<uniform> uni: CommonUniform;

@group(0) @binding(1)
 var<storage, read_write> buffer_a: GridBuffer;

@group(0) @binding(2)
 var<storage, read_write> buffer_b: GridBuffer;

@group(0) @binding(3)
 var<storage, read_write> buffer_c: GridBuffer;

@group(0) @binding(4)
 var<storage, read_write> buffer_d: GridBuffer;


// TODO: is the -1 necessary?
fn get_index( location: vec2<i32>) -> i32 {
    return (i32(uni.grid_size.y) - 0) * (i32(location.x ) + 0)  + i32(location.y )  ;
}


// fn get_image_index( location: vec2<i32>) -> i32 {
//     return i32(uni.iResolution.y) * i32(location.x )  + i32(location.y ) ;
//     // return i32(uni.grid_size.y) * i32(location.x )  + i32(location.y ) ;
// }


// RUST_LOG="wgpu=error,naga=warn,info" cargo run --release --example simpler_particles  

var<private> R: vec2<f32>;
var<private> Mouse: vec4<f32>;
var<private> time: f32;
var<private> s0: vec4<u32>;
// let particle_size: f32 = 10.5;
let particle_size: f32 = 5.0;
let relax_value: f32 = 0.3;

fn Rot(ang: f32) -> mat2x2<f32> {
	return mat2x2<f32>(cos(ang), -sin(ang), sin(ang), cos(ang));
} 

fn Dir(ang: f32) -> vec2<f32> {
	return vec2<f32>(cos(ang), sin(ang));
} 

fn sdBox(p: vec2<f32>, b: vec2<f32>) -> f32 {
	var d: vec2<f32> = abs(p) - b;
	return length(max(d, vec2<f32>(0.))) + min(max(d.x, d.y), 0.);
} 

fn border(p: vec2<f32>) -> f32 {
	let bound: f32 = -sdBox(p - R * 0.5, R * vec2<f32>(0.5, 0.5));
	let box: f32 = sdBox(Rot(0. * time - 0.) * (p - R * vec2<f32>(0.5, 0.6)), R * vec2<f32>(0.05, 0.01));
	let drain: f32 = -sdBox(p - R * vec2<f32>(0.5, 0.7), R * vec2<f32>(1.5, 0.5));
	// return bound - 15.;
	// return min(bound, box);
	return max(drain, min(bound, box));
} 

fn bN(p: vec2<f32>) -> vec3<f32> {
	var dx: vec3<f32> = vec3<f32>(-1., 0., 1.);
	let idx: vec4<f32> = vec4<f32>(-1. / 1., 0., 1. / 1., 0.25);
	var r: vec3<f32> = idx.zyw * border(p + dx.zy) + idx.xyw * border(p + dx.xy) + idx.yzw * border(p + dx.yz) + idx.yxw * border(p + dx.yx);
	return vec3<f32>(normalize(r.xy), r.z + 0.0001);
} 

fn decode(g: GridSlotEncoded) -> GridSlot {
    return GridSlot(
        g.particle1,
        g.particle2
    );
}

fn encode(g: GridSlot) -> GridSlotEncoded {
    return GridSlotEncoded(
        g.particle1,
        g.particle2
    );
}



fn getParticle(data: GridSlotEncoded, pos: vec2<f32>) -> Particle {
    let grid_slot = decode(data);
	var P: Particle = grid_slot.particle1;
	P.X = P.X + pos;
	P.NX = P.NX + pos;

    return P;

    // var P2: particle = grid_slot.particle2;
    // P2.X = P2.X + pos;
    // P2.NX = P2.NX + pos;

	// return GridSlot(P, P2);
} 

fn saveParticles(P_in1: Particle, P_in2: Particle, pos: vec2<f32>) -> GridSlotEncoded {
	var P = P_in1;
	P.X = P.X - pos;
	P.NX = P.NX - pos;

    var P2 = P_in2;
    P2.X = P2.X - pos;
    P2.NX = P2.NX - pos;

	return GridSlotEncoded(P, P2);
} 


fn rng_initialize(p: vec2<f32>, frame: i32)  {
	s0 = vec4<u32>(u32(p.x), u32(p.y), u32(frame), u32(p.x) + u32(p.y));
} 

// // https://www.pcg-random.org/
// void pcg4d(inout uvec4 v)
// {
// 	v = v * 1664525u + 1013904223u;
//     v.x += v.y*v.w; v.y += v.z*v.x; v.z += v.x*v.y; v.w += v.y*v.z;
//     v = v ^ (v>>16u);
//     v.x += v.y*v.w; v.y += v.z*v.x; v.z += v.x*v.y; v.w += v.y*v.z;
// }


fn pcg4d(v: ptr<private, vec4<u32>>)  {

	(*v) = (*v) * 1664525u + 1013904223u;
	(*v).x = (*v).x + ((*v).y * (*v).w);
	(*v).y = (*v).y + ((*v).z * (*v).x);
	(*v).z = (*v).z + ((*v).x * (*v).y);
	(*v).w = (*v).w + ((*v).y * (*v).z);


	let v2 = vec4<u32>((*v).x >> 16u, (*v).y >> 16u, (*v).z >> 16u, (*v).w >> 16u);

	(*v) = (*v) ^ v2;
	// (*v) = (*v) ^ ((*v) >> 16u);
	(*v).x = (*v).x + ((*v).y * (*v).w);
	(*v).y = (*v).y + ((*v).z * (*v).x);
	(*v).z = (*v).z + ((*v).x * (*v).y);
	(*v).w = (*v).w + ((*v).y * (*v).z);
} 

fn rand() -> f32 {
	pcg4d(&s0);
	return f32(s0.x) / f32(4294967300.);
} 

fn rand2() -> vec2<f32> {
	pcg4d(&s0);
	return vec2<f32>(s0.xy) / f32(4294967300.);
} 

fn rand3() -> vec3<f32> {
	pcg4d(&s0);
	return vec3<f32>(s0.xyz) / f32(4294967300.);
} 

fn rand4() -> vec4<f32> {
	pcg4d(&s0);
	return vec4<f32>(s0) / f32(4294967300.);
} 

 

// RUST_LOG="wgpu=error,naga=warn,info" cargo run --release --example simpler_particles  

// let indirect_index = atomicAdd(&spawner.count, 1);


fn Simulation(
	// ch: ptr<storage, GridBuffer, read>,  
    // ch: array<GridSlotEncoded>, 
	P: ptr<function, Particle>, 
	pos: vec2<f32>
)  {
	var F: vec2<f32> = vec2<f32>(0.);
	var I: i32 = i32(ceil(particle_size));
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

	let dp: vec2<f32> = (*P).NX;
	var d: f32 = border(dp);
	if (d < 0.) { F = F - (bN(dp).xy * d); }
	(*P).NX = (*P).NX + (F * 0.9 / 3.);
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    // let R: vec2<f32> = uni.iResolution.xy;
    // let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    
	// var U: vec4<f32>;
	var pos = vec2<f32>(f32(location.x), f32(location.y) );

	R = uni.iResolution.xy;
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

