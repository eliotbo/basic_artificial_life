
@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let grid_location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));



    // instead of holding the GridSlots, buffer c hold trail information
    var current_trail = buffer_c.pixels[get_index(grid_location)];

    // var trail_color = vec4<f32>(0.0, 0.0, 0.0, 0.0);

    // trail_color 

    var i = current_trail.intensities;

    i = i * trail_decay;

    let encoded_b = buffer_b.pixels[get_index(grid_location)];
    let slot = decode(encoded_b);

    if (slot.mass > 0u) {

        switch (slot.kind) {
            case 0u { i.x += 1.0; }
            case 1u { i.y += 1.0; }
            case 2u { i.z += 1.0;  }
            // case 3u { trail_color = yellow; }
            default { i.w += 1.0;  }
        }

    }

    current_trail.intensities = clamp(i, vec4<f32>(0.0), vec4<f32>(max_trail_intensity));

    buffer_c.pixels[get_index(grid_location)] = current_trail;

}