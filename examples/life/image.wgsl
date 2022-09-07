
// sdf of a circle
fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
  let d = length(p - c);
  return d - r;
}






fn sdXSegment(p: f32, x: f32) -> f32 {
    return length( p - x );
}

fn sdBox(p: vec2<f32>, b: vec2<f32>) -> f32 {
	let d: vec2<f32> = abs(p) - b;
	return length(max(d, vec2<f32>(0.))) + min(max(d.x, d.y), 0.);
} 



fn ball_sdf(
    color: vec4<f32>, 
    location: vec2<i32>, 
    grid_loc: vec2<i32>, 
    slot: GridSlot,
    coef: f32
) -> f32 {

    let relative_ball_position = slot.pos;

    let absolute_ball_position = 
        (vec2<f32>(grid_loc) ) * coef 
        + relative_ball_position * coef;

    let ball_radius_co = coef * ball_radius;
    let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius_co);

    return s;

   
}




@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    let float_loc = vec2<f32>(location);
    // let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

     
    // expansion coefficient
    let eco = uni.iResolution.x / f32(uni.grid_size.x);
    let grid_loc = vec2<i32>(vec2<f32>(location) / eco);

    let ball_radius_co = eco * ball_radius;

    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    let background_color = vec4<f32>(0.1, 0.1, 0.1, 1.0) / 3.;
    // let background_color = soft_gray;
    // var color = dark_purple / 4.0;
    var color = background_color;
    color.a = 1.0;



    let co = eco;
    let co2 = co / 1.;

    var grid_color = background_color * 1.3;
    grid_color.a = 1.0;
    let sx = sdXSegment(float_loc.x % co, co2);
    let sy = sdXSegment(float_loc.y % co, co2);
    color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sx));
    color = mix(color, grid_color, 1.0 - smoothstep(0.0, 3.0, sy));


    // //////////////////// trails ///////////////////////////////////////
    let non_normalized_trail = buffer_c.pixels[get_index(grid_loc)].intensities;
    var trail = non_normalized_trail / max_trail_intensity;
    // let trail_sdf = sdCircle(vec2<f32>(location) , (vec2<f32>(grid_loc ) + 0.5) * eco, ball_radius_co);
    let trail_sdf = sdBox(vec2<f32>(location) , (vec2<f32>(grid_loc ) + 1.) * eco);

    var bright_blue = blue * 1.4;

    bright_blue.a = (trail.x + trail.y + trail.z + trail.w) / 4.0; 
    var transparent_green = bright_blue;
    transparent_green.a = 0.0;

    let trail_green = mix(transparent_green, bright_blue, 1.0 - smoothstep(-2.0, 0.0, trail_sdf));


    color = mix(color, trail_green, trail_green.a / 10.0);


    // //////////////////// trails ///////////////////////////////////////






    // let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
    // let slot: GridSlot = decode(slot_encoded);

    // todo:

    // 2) add gravity to forces step
    // 3) add collision detection
    // 

    let ball_brightness = 1.2;

    //  let ball_radius = 20.;

    for (var i = -1; i < 2; i=i+1) {
        for (var j = -1; j < 2; j=j+1) {

            
            

            var neighbor_loc = grid_loc + vec2<i32>(i, j);

            // torus (pacman type boundaries)
            neighbor_loc = neighbor_loc % vec2<i32>(uni.grid_size.xy);

            let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
            var neighbor_slot = decode(neighbor_slot_encoded);


            if (neighbor_slot.mass > 0u) {

                // let ball_position = neighbor_slot.pos *   eco;
                
                let ball_position = (vec2<f32>(neighbor_loc) + neighbor_slot.pos ) *   eco;

                let s = sdCircle(vec2<f32>(location) , ball_position, ball_radius_co);

                var ball_color = pink;

                
                switch (neighbor_slot.kind) {
                    case 0u { ball_color = pink * ball_brightness; }
                    case 1u { ball_color = salmon * ball_brightness; }
                    case 2u { ball_color = aqua * ball_brightness; }
                    // case 3u { ball_color = yellow; }
                    default { ball_color = dark_green * ball_brightness; }

                }

                color = mix(color, ball_color, 1.0 - smoothstep(-2.0, 0.0, s));
                color = mix(color, gray, 1.0 - smoothstep(-2.0, 2.0, abs(s)));
            }
        }
    }

    textureStore(texture, location, color);
}