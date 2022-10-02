// RUST_LOG="wgpu=error,naga=warn,info" cargo run --release --example simpler_particles  

var<private> R: vec2<f32>;
var<private> Grid: vec2<f32>;
var<private> R2G: vec2<f32>; // grid.x to resolution.x ratio
var<private> Mouse: vec4<f32>;
var<private> time: f32;
var<private> s0: vec4<u32>;
// let particle_size: f32 = 10.5;
let particle_size: f32 = 2.2;
let relax_value: f32 = 0.3;

// struct Particle {
// 	X: vec2<f32>,
// 	NX: vec2<f32>,
// 	R: f32,
// 	M: f32,
//     K: u32, // Kind
//     dummy: f32,
// };
// let empty_particle: Particle = Particle(
//     vec2<f32>(0.), 
//     vec2<f32>(0.), 
//     0., 0., 0, 0.);

//////////////////////////// colors ////////////////////////////
//////////////////////////// colors ////////////////////////////
//////////////////////////// colors ////////////////////////////
// let purple = vec4<f32>(130.0 / 255.0, 106.0 / 255.0, 237.0 / 255.0, 1.0);
let purple = vec4<f32>(0.510, 0.416, 0.929, 1.0);


// let pink = vec4<f32>(200.0 / 255.0, 121.0 / 255.0, 255.0 / 255.0, 1.0);
let pink = vec4<f32>(0.784, 0.475, 1.0, 1.0);


// let c3 = vec4<f32>(255.0 / 255.0, 183.0 / 255.0, 255.0 / 255.0, 1.0);
let salmon = vec4<f32>(1.0, 0.718, 1.0, 1.0);

// let c4 = vec4<f32>(59.0 / 255.0, 244.0 / 255.0, 251.0 / 255.0, 1.0);
let aqua = vec4<f32>(0.231, 0.957, 0.984, 1.0);

// let c5 = vec4<f32>(202.0 / 255.0, 255.0 / 255.0, 138.0 / 255.0, 1.0);
let yellow = vec4<f32>(0.792, 1.0, 0.541, 1.0);
let brown = vec4<f32>(0.498, 0.41, 0.356, 1.0);
let beige = vec4<f32>(0.839, 0.792, 0.596, 1.0);
let dark_purple = vec4<f32>(0.447, 0.098, 0.353, 1.0);

// 12, 202, 74
// let dark_green = vec4<f32>(12.0 / 255.0, 202.0 / 255.0, 74.0 / 255.0, 1.0);
let dark_green = vec4<f32>(0.047, 0.792, 0.290, 1.0);


// let soft_gray =  vec4<f32>(68.0 / 255.0, 64.0 / 255.0, 84.0 / 255.0, 1.0);
let soft_gray =  vec4<f32>(0.267, 0.251, 0.329, 1.0);

let black = vec4<f32>(0.0, 0.0, 0.0, 1.0);
let gray = vec4<f32>(0.051, 0.051, 0.051, 1.0);

// let blue = vec4<f32>(21, 244, 238);
let blue = vec4<f32>(0.082, 0.957, 0.933, 1.0);
//////////////////////////// colors ////////////////////////////
//////////////////////////// colors ////////////////////////////
//////////////////////////// colors ////////////////////////////


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
    let edge = 10.0 * R2G;
	let bound: f32 = -sdBox(p - R * (0.5 - 0.0), R / 2.0 - edge );
    // let bound: f32 = -sdBox(p, R * vec2<f32>(1.0, 1.0));

	// let box: f32 = sdBox(Rot(0. * time - 0.) * (p - R * vec2<f32>(0.5, 0.6)), R * vec2<f32>(0.05, 0.01));
	// let drain: f32 = -sdBox(p - R * vec2<f32>(0.5, 0.7), R * vec2<f32>(1.5, 0.5));
	// return bound - 15.;
	// return min(bound, box);
	// return max(drain, min(bound, box));
    return bound;
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



fn getParticle(data: GridSlotEncoded, gpos: vec2<f32>) -> Particle {
    let grid_slot = decode(data);
	var P: Particle = grid_slot.particle1;
	P.X = P.X + gpos;
	P.NX = P.NX + gpos;

    return P;

    // var P2: particle = grid_slot.particle2;
    // P2.X = P2.X + gpos;
    // P2.NX = P2.NX + gpos;

	// return GridSlot(P, P2);
} 

fn saveParticles(P_in1: Particle, P_in2: Particle, gpos: vec2<f32>) -> GridSlotEncoded {
	var P = P_in1;
	P.X = P.X - gpos;
	P.NX = P.NX - gpos;

    var P2 = P_in2;
    P2.X = P2.X - gpos;
    P2.NX = P2.NX - gpos;

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