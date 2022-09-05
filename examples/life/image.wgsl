
// sdf of a circle
fn sdCircle(p: vec2<f32>, c: vec2<f32>, r: f32) -> f32 {
  let d = length(p - c);
  return d - r;
}

let red = vec4<f32>(1.0, 0.0, 0.0, 1.0);
let green = vec4<f32>(0.0, 1.0, 0.0, 1.0);
let blue = vec4<f32>(0.0, 0.0, 1.0, 1.0);
let yellow = vec4<f32>(1.0, 1.0, 0.0, 1.0);
let cyan = vec4<f32>(0.0, 1.0, 1.0, 1.0);

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
    let buffer_location_index = get_index(vec2<i32>(invocation_id.xy));

     

    let expansion_coefficient = uni.iResolution.x / f32(uni.grid_size.x);
    let grid_loc = vec2<i32>(vec2<f32>(location) / expansion_coefficient);



    // var color = vec4<f32>(0.25, 0.8, 0.8, 1.0);
    var color = vec4<f32>(0.1, 0.2, 0.3, 1.0);

    let slot_encoded: GridSlotEncoded =   buffer_a.pixels[get_index(grid_loc)] ;
    let slot: GridSlot = decode(slot_encoded);



    for (var i = -1; i < 2; i=i+1) {
        for (var j = -1; j < 2; j=j+1) {
            

            let neighbor_loc = grid_loc + vec2<i32>(i, j);
            let neighbor_slot_encoded: GridSlotEncoded = buffer_a.pixels[get_index(neighbor_loc)];
            let neighbor_slot: GridSlot = decode(neighbor_slot_encoded);

            // let neighbor_loc2 = grid_loc - vec2<i32>(i, j);


            if (neighbor_slot.mass > 0u) {
                // let s = ball_sdf(red, location, grid_loc, slot, expansion_coefficient);
                let relative_ball_position = neighbor_slot.pos;

                let absolute_ball_position = 
                    (vec2<f32>(neighbor_loc) ) * expansion_coefficient 
                    + relative_ball_position * expansion_coefficient;

                let ball_radius = expansion_coefficient/4.2;
                let s = sdCircle(vec2<f32>(location), absolute_ball_position, ball_radius);

                var ball_color = red;
                
                switch (neighbor_slot.kind) {
                    case 0u { ball_color = red; }
                    case 1u { ball_color = green; }
                    case 2u { ball_color = blue; }
                    case 3u { ball_color = yellow; }
                    default { ball_color = cyan; }

                }

                color = mix(color, ball_color, 1.0 - smoothstep(-0.0, 1.0, s));
            }
        }
    }

    textureStore(texture, location, color);
}