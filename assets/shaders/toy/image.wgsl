
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
    K: u32, // Kind
    dummy: f32,
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


@group(0) @binding(5)
var texture: texture_storage_2d<rgba32float, read_write>;

@group(0) @binding(6)
var font_texture: texture_2d<f32>;

@group(0) @binding(7)
var font_texture_sampler: sampler;

@group(0) @binding(8)
var rgba_noise_256_texture: texture_2d<f32>;

@group(0) @binding(9)
var rgba_noise_256_texture_sampler: sampler;

@group(0) @binding(10)
var blue_noise_texture: texture_2d<f32>;

@group(0) @binding(11)
var blue_noise_texture_sampler: sampler;




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


// // sdf of a circle
// fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
//   let d = length(p - c);
//   return d - r;
// }






fn sdXSegment(p: f32, x: f32) -> f32 {
    return length( p - x );
}

// fn sdBox(p: vec2<f32>, b: vec2<f32>) -> f32 {
// 	let d: vec2<f32> = abs(p) - b;
// 	return length(max(d, vec2<f32>(0.))) + min(max(d.x, d.y), 0.);
// } 



// fn ball_sdf(
//     color: vec4<f32>, 
//     location: vec2<i32>, 
//     grid_loc: vec2<i32>, 
//     slot: GridSlot,
//     coef: f32
// ) -> f32 {

//     let relative_ball_position = slot.pos;

//     let absolute_ball_position = 
//         (vec2<f32>(grid_loc) ) * coef 
//         + relative_ball_position * coef;

//     let ball_radius_co = coef * ball_radius;
//     let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius_co);

//     return s;

   
// }




// @compute @workgroup_size(8, 8, 1)
// fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
//     let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

//     let float_loc = vec2<f32>(location);
//     // let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

     
//     // expansion coefficient
//     let eco = uni.iResolution.x / f32(uni.grid_size.x);
//     let grid_loc = vec2<i32>(vec2<f32>(location) / eco);

//     let ball_radius_co = eco * ball_radius;

//     // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
//     let background_color = vec4<f32>(0.1, 0.1, 0.1, 1.0) / 3.;
//     // let background_color = soft_gray;
//     // var color = dark_purple / 4.0;
//     var color = background_color;
//     color.a = 1.0;



//     let co = eco;
//     let co2 = co / 1.;

//     var grid_color = background_color * 1.3;
//     grid_color.a = 1.0;
//     let sx = sdXSegment(float_loc.x % co, co2);
//     let sy = sdXSegment(float_loc.y % co, co2);
//     color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sx));
//     color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sy));


//     // //////////////////// trails ///////////////////////////////////////
//     let non_normalized_trail = buffer_c.pixels[get_index(grid_loc)].intensities;
//     var trail = non_normalized_trail / max_trail_intensity;
//     // let trail_sdf = sdCircle(vec2<f32>(location) , (vec2<f32>(grid_loc ) + 0.5) * eco, ball_radius_co);
//     let trail_sdf = sdBox(vec2<f32>(location) , (vec2<f32>(grid_loc ) + 1.) * eco);

//     var bright_blue = blue * 1.4;

//     bright_blue.a = (trail.x + trail.y + trail.z + trail.w) / 4.0; 
//     var transparent_green = bright_blue;
//     transparent_green.a = 0.0;

//     let trail_green = mix(transparent_green, bright_blue, 1.0 - smoothstep(-2.0, 0.0, trail_sdf));


//     color = mix(color, trail_green, trail_green.a / 10.0);


//     // //////////////////// trails ///////////////////////////////////////






//     // let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
//     // let slot: GridSlot = decode(slot_encoded);

//     // todo:

//     // 2) add gravity to forces step
//     // 3) add collision detection
//     // 

//     let ball_brightness = 1.2;

//     //  let ball_radius = 20.;

//     for (var i = -1; i < 2; i=i+1) {
//         for (var j = -1; j < 2; j=j+1) {

            
            

//             var neighbor_loc = grid_loc + vec2<i32>(i, j);

//             // torus (pacman type boundaries)
//             neighbor_loc = neighbor_loc % vec2<i32>(uni.grid_size.xy);

//             let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
//             var neighbor_slot = decode(neighbor_slot_encoded);


//             if (neighbor_slot.mass > 0u) {

//                 // let ball_position = neighbor_slot.pos *   eco;
                
//                 let ball_position = (vec2<f32>(neighbor_loc) + neighbor_slot.pos ) *   eco;

//                 let s = sdCircle(vec2<f32>(location) , ball_position, ball_radius_co);

//                 var ball_color = pink;

                
//                 switch (neighbor_slot.kind) {
//                     case 0u { ball_color = pink * ball_brightness; }
//                     case 1u { ball_color = salmon * ball_brightness; }
//                     case 2u { ball_color = aqua * ball_brightness; }
//                     case 3u { ball_color =  vec4<f32>(0.082, 0.3, 0.933, 1.0); }
//                     default { ball_color = dark_green * ball_brightness; }

//                 }

//                 color = mix(color, ball_color, 1.0 - smoothstep(-2.0, 0.0, s));
//                 color = mix(color, gray, 1.0 - smoothstep(-2.0, 2.0, abs(s)));
//             }
//         }
//     }

//     textureStore(texture, location, color);
// }

// @compute @workgroup_size(8, 8, 1)
// fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
//      R = uni.iResolution.xy;
//     let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));

//     let col = vec4<f32>(1.0, 0.0, 0.0, 1.0);
//     textureStore(texture, y_inverted_location, col);
// }

fn opSmoothUnion(d1: f32, d2: f32, k: f32 ) -> f32 {
    let h: f32 = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

fn opSmoothIntersection( d1: f32, d2: f32, k: f32 ) -> f32 {
    let h: f32 = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h); }

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    R = uni.iResolution.xy;
    Grid = vec2<f32>(uni.grid_size.xy);
    R2G = R / vec2<f32>(uni.grid_size.xy);

    let y_inverted_location = vec2<i32>(i32(invocation_id.x), i32(R.y) - i32(invocation_id.y));

    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    /////////////////////////// grid ///////////////////////////////////////
    let float_loc = vec2<f32>(location);

    let eco = uni.iResolution.x / f32(uni.grid_size.x) * 1.0;
    let grid_loc = vec2<i32>(vec2<f32>(location) / eco);

    let ball_radius_co = eco * particle_size;

    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    let gray = 0.00241;
    let background_color = vec4<f32>(gray, gray, gray, 1.0) ;
    // let background_color = soft_gray;
    // var color = dark_purple / 4.0;
    var color = background_color;
    color.a = 1.0;

    let co = eco;
    let co2 = co / 1.;

    // var grid_color = background_color * 1.3;
    var grid_color =  vec4<f32>(0.2, 0.2, 0.2, 1.0) * 0.5;
    grid_color.a = 1.0;

    let sx = sdXSegment(float_loc.x % co, co2);
    let sy = sdXSegment(float_loc.y % co, co2);

    let sxy = 1. - smoothstep(0.0, 3.0, sx) + 1. - smoothstep(0.0, 3.0, sy);

    color = mix(color,  grid_color,   sxy);

    

    /////////////////////////// grid ///////////////////////////////////////

    var col = color;
	// var col: vec4<f32>;

    let grid_f32 = R / vec2<f32>(f32(uni.grid_size.x), f32(uni.grid_size.y));
    // let G2R = R.x / f32(uni.grid_size.x);
    // let grid_f32 = 1.0;

	var pos = vec2<f32>(f32(location.x), f32(location.y) );

    var pos_grid = vec2<f32>(f32(location.x) + 0.5, f32(location.y) + 0.5) / grid_f32;

	R = uni.iResolution.xy;

	time = uni.iTime;

	// var colxyz = col.xyz;
	// colxyz = vec3<f32>(1.);
	// col.x = colxyz.x;
	// col.y = colxyz.y;
	// col.z = colxyz.z;

	var d: f32 = 100.;
    var d2: f32 = 100.;
    var mind: f32 = 100.;
	var c: vec3<f32> = vec3<f32>(1.);
	var m: f32 = 1.;
	var I: i32 = i32(ceil(particle_size)) + 2;

    var ball_color = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    var ball_brightness = 0.4;
	let cc = 4.0;

    var do_break = false;
	for (var i: i32 = -I; i <= I; i = i + 1) {
        
	for (var j: i32 = -I; j <= I; j = j + 1) {

		var tpos: vec2<i32> = vec2<i32>(pos_grid) + vec2<i32>(i, j);

        var data: GridSlotEncoded = buffer_d.pixels[get_index(tpos)];
		// var data: vec4<f32> = textureLoad(buffer_d, vec2<i32>(tpos));

		var P0: Particle = getParticle(data, vec2<f32>(tpos));

		if (P0.M == 0.) { continue; }

        // var nd: f32 = distance(pos, P0.NX )  - P0.R ;
		// var nd: f32 = distance(pos, P0.NX * cc)  - P0.R * cc;
        var nd: f32 = distance(pos, P0.NX * R2G)  - P0.R * R2G.x / 1.05;
        // var nd: f32 = distance(pos_grid, P0.NX ) - P0.R ;

        
        d = opSmoothUnion(d, nd, 5.95);
        // d = opSmoothIntersection(d, nd, 0.25);
        
        // choose the closest particle as the one to draw 
		if (nd < mind) {
			let V: vec2<f32> = (P0.NX - P0.X) * 1. / 2. ;
			c = vec3<f32>(V * 0.5 + 0.5, (P0.M - 1.) / 3.);
			c = mix(vec3<f32>(1.), c, length(V));
			m = P0.M;
            mind = nd;

            // ball_brightness = c.z;
            
            switch (P0.K){
                case 0u { ball_color = pink * ball_brightness; }
                case 1u { ball_color = salmon * ball_brightness; }
                case 2u { ball_color = beige * ball_brightness; }
                case 3u { ball_color =  dark_purple * ball_brightness; }
                default { ball_color = dark_green * ball_brightness; }

            }
		}

		// d = min(d, nd);
        

		// if (d < 0.) {
        //     do_break = true;
        //     break;
        // }
        
	}

    // if (do_break) { break; }

	}

    // if (!do_break) { ball_color = vec4<f32>(0.0, 0.0, 0.0, 0.0); }

	var s: f32 = 100.;
	let off: vec2<f32> = vec2<f32>(5., 5.);
    


	if (d < 0.) { 
        // d = sin(d * 2.0);
        col = mix(ball_color, col, d + 0.);
     }


	// col = vec4<f32>(abs(d), abs(d), abs(d), col.a);

    


	// if (d < 0.) {
	// 	var colxyz = col.xyz;
	// 	colxyz = col.xyz * (c);
	// 	col.x = colxyz.x;
	// 	col.y = colxyz.y;
	// 	col.z = colxyz.z;

	// 	var colxyz = col.xyz;
	// 	colxyz = col.xyz / (0.4 + m * 0.25);
	// 	col.x = colxyz.x;
	// 	col.y = colxyz.y;
	// 	col.z = colxyz.z;
	// }

	// var colxyz = col.xyz;
	// colxyz = clamp(col.xyz, vec3<f32>(0.), vec3<f32>(1.));
	// col.x = colxyz.x;
	// col.y = colxyz.y;
	// col.z = colxyz.z;

	// if (d > 0.) {
	// 	 var colxyz = col.xyz;
	// 	colxyz = col.xyz * (mix(vec3<f32>(0.5), vec3<f32>(1.), clamp(s, 0., 1.)));
	// 	col.x = colxyz.x;
	// 	col.y = colxyz.y;
	// 	col.z = colxyz.z; 
	// }

	// if (pos.x < 3.) || (pos.x > R.x - 3.) || (pos.y < 3.) || (pos.y > R.y - 3.) { 
	// 	var colxyz = col.xyz;
	// 	colxyz = vec3<f32>(0.5);
	// 	col.x = colxyz.x;
	// 	col.y = colxyz.y;
	// 	col.z = colxyz.z; 
	// }

    // col = background_color;
    // col = mix(col, grid_color,  1.0 - smoothstep(0.0, 3.0, sxy));
	// col = vec4<f32>(1.0, 0.0, 0.0, 1.0);
	col.w = 1.0;

    // col.a = 1.0;

	textureStore(texture, y_inverted_location, col);
} 

