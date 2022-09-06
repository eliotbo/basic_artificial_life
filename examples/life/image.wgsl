
// sdf of a circle
fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
  let d = length(p - c);
  return d - r;
}


let bg = vec4<f32>(0.10210, 0.083, 0.186, 1.0);

// let purple = vec4<f32>(130.0 / 255.0, 106.0 / 255.0, 237.0 / 255.0, 1.0);
let purple = vec4<f32>(0.510, 0.416, 0.929, 1.0);

// let pink = vec4<f32>(200.0 / 255.0, 121.0 / 255.0, 255.0 / 255.0, 1.0);
let pink = vec4<f32>(0.784, 0.475, 1.0, 1.0);

// let c3 = vec4<f32>(255.0 / 255.0, 183.0 / 255.0, 255.0 / 255.0, 1.0);
let salmon = vec4<f32>(1.0, 0.718, 1.0, 1.0);

// let c4 = vec4<f32>(59.0 / 255.0, 244.0 / 255.0, 251.0 / 255.0, 1.0);
let aqua = vec4<f32>(0.231, 0.957, 0.984, 1.0);

// let c5 = vec4<f32>(202.0 / 255.0, 255.0 / 255.0, 138.0 / 255.0, 1.0);
let green = vec4<f32>(0.792, 1.0, 0.541, 1.0);


let brown = vec4<f32>(0.498, 0.41, 0.356, 1.0);

// let red = vec4<f32>(1.0, 0.0, 0.0, 1.0);
// let green = vec4<f32>(0.0, 1.0, 0.0, 1.0);
// let blue = vec4<f32>(0.0, 0.0, 1.0, 1.0);
// let yellow = vec4<f32>(1.0, 1.0, 0.0, 1.0);
// let cyan = vec4<f32>(0.0, 1.0, 1.0, 1.0);

let black = vec4<f32>(0.0, 0.0, 0.0, 1.0);
let gray = vec4<f32>(0.051, 0.051, 0.051, 1.0);



fn sdXSegment(p: f32, x: f32) -> f32 {
    return length( p - x );
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

    let ball_radius = coef/4.2;
    let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius);

    return s;

   
}




@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    let float_loc = vec2<f32>(location);
    // let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

     

    let expansion_coefficient = uni.iResolution.x / f32(uni.grid_size.x);
    let grid_loc = vec2<i32>(vec2<f32>(location) / expansion_coefficient);



    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    var color = bg * 2.2;
    color.a = 1.0;



    let co = expansion_coefficient;
    let co2 = co / 1.;
    let sx = sdXSegment(float_loc.x % co, co2);
    let sy = sdXSegment(float_loc.y % co, co2);
    color = mix(color, gray, 1.0 - smoothstep(0.0, 3.0, sx));
    color = mix(color, gray, 1.0 - smoothstep(0.0, 3.0, sy));



    // let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
    // let slot: GridSlot = decode(slot_encoded);

    // todo:
    // 1) add velocity to GridSlot
    // 2) add collision with walls
    // 2) add gravity to forces step
    // 3) add collision detection
    // 

     let ball_radius = expansion_coefficient * 0.25;

    //  let ball_radius = 20.;

    for (var i = -1; i < 2; i=i+1) {
        for (var j = -1; j < 2; j=j+1) {

            
            

            var neighbor_loc = grid_loc + vec2<i32>(i, j);

            // torus (pacman type boundaries)
            neighbor_loc = neighbor_loc % vec2<i32>(uni.grid_size.xy);
            let neighbor_slot_encoded: GridSlotEncoded = buffer_b.pixels[get_index(neighbor_loc)];
            var neighbor_slot = decode(neighbor_slot_encoded);


            if (neighbor_slot.mass > 0u) {

                // let ball_position = neighbor_slot.pos *   expansion_coefficient;
                
                let ball_position = (vec2<f32>(neighbor_loc) + neighbor_slot.pos ) *   expansion_coefficient;

                let s = sdCircle(vec2<f32>(location) , ball_position, ball_radius);

                var ball_color = pink;

                
                switch (neighbor_slot.kind) {
                    case 0u { ball_color = pink; }
                    case 1u { ball_color = salmon; }
                    case 2u { ball_color = aqua; }
                    // case 3u { ball_color = yellow; }
                    default { ball_color = green; }

                }

                color = mix(color, ball_color, 1.0 - smoothstep(-0.0, 1.0, s));
            }
        }
    }

    textureStore(texture, location, color);
}