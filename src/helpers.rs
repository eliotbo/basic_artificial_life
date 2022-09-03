use bevy::{prelude::*, render::render_resource::Extent3d};

use crate::ShaderHandles;
use std::fs;

#[derive(Clone, Debug)]
pub struct CanvasSize {
    pub width: u32,
    pub height: u32,
}

pub fn make_and_load_shaders(example: &str, asset_server: &Res<AssetServer>) -> ShaderHandles {
    let image_shader_handle = asset_server.load(&format!("./shaders/{}/image.wgsl", example));
    let texture_a_shader = asset_server.load(&format!("./shaders/{}/buffer_a.wgsl", example));
    let texture_b_shader = asset_server.load(&format!("./shaders/{}/buffer_b.wgsl", example));
    let texture_c_shader = asset_server.load(&format!("./shaders/{}/buffer_c.wgsl", example));
    let texture_d_shader = asset_server.load(&format!("./shaders/{}/buffer_d.wgsl", example));

    ShaderHandles {
        image_shader: image_shader_handle,
        texture_a_shader,
        texture_b_shader,
        texture_c_shader,
        texture_d_shader,
    }
}

pub fn make_and_load_shaders2(
    example: &str,
    asset_server: &Res<AssetServer>,
    include_debugger: bool,
) -> ShaderHandles {
    // let image_shader_handle = asset_server.load(&format!("shaders/{}/image.wgsl", example));
    // let example_string = example.to_string();
    //

    format_and_save_shader(example, "image", include_debugger);
    format_and_save_shader(example, "buffer_a", false);
    format_and_save_shader(example, "buffer_b", false);
    format_and_save_shader(example, "buffer_c", false);
    format_and_save_shader(example, "buffer_d", false);

    let image_shader_handle = asset_server.load(&format!("./shaders/{}/image.wgsl", example));
    let texture_a_shader = asset_server.load(&format!("./shaders/{}/buffer_a.wgsl", example));
    let texture_b_shader = asset_server.load(&format!("./shaders/{}/buffer_b.wgsl", example));
    let texture_c_shader = asset_server.load(&format!("./shaders/{}/buffer_c.wgsl", example));
    let texture_d_shader = asset_server.load(&format!("./shaders/{}/buffer_d.wgsl", example));

    ShaderHandles {
        image_shader: image_shader_handle,
        texture_a_shader,
        texture_b_shader,
        texture_c_shader,
        texture_d_shader,
    }
}

// This function uses the std library and isn't compatible with wasm
pub fn format_and_save_shader(example: &str, buffer_type: &str, include_debugger: bool) {
    let common_prelude = include_str!("./templates/common_prelude.wgsl");

    let template = match buffer_type {
        "image" => include_str!("./templates/image_template.wgsl"),
        "buffer_a" => include_str!("./templates/buffer_a_template.wgsl"),
        "buffer_b" => include_str!("./templates/buffer_b_template.wgsl"),
        "buffer_c" => include_str!("./templates/buffer_c_template.wgsl"),
        "buffer_d" => include_str!("./templates/buffer_d_template.wgsl"),
        _ => include_str!("./templates/buffer_d_template.wgsl"),
    };

    let mut shader_content = template.replace("{{COMMON_PRELUDE}}", common_prelude);

    if include_debugger {
        let debbuger_str = include_str!("./templates/debugger.wgsl");
        shader_content = shader_content.replace("{{DEBUGGER}}", debbuger_str);
    } else {
        shader_content = shader_content.replace("{{DEBUGGER}}", "");
    }

    let path_to_code_block = format!("./examples/{}/{}.wgsl", example, buffer_type);
    let path_to_common = format!("./examples/{}/common.wgsl", example);
    println!("common: {}", path_to_common);

    let common = fs::read_to_string(path_to_common).expect("could not read file.");
    let image_main = fs::read_to_string(path_to_code_block).expect("could not read file.");

    let mut shader_content = shader_content.replace("{{COMMON}}", &common);
    shader_content = shader_content.replace("{{CODE_BLOCK}}", &image_main);
    let folder = format!("./assets/shaders/{}", example);
    let path = format!("{}/{}.wgsl", folder, buffer_type);
    println!("{}", path);
    let _ = fs::create_dir(folder);
    fs::write(path, shader_content).expect("Unable to write file");
}

pub fn make_new_texture(
    // old_buffer_length: i32,
    canvas_size: &CanvasSize,
    image_handle: &Handle<Image>,
    images: &mut ResMut<Assets<Image>>,
) {
    if let Some(image) = images.get_mut(image_handle) {
        // There is no easy way to get the data from the gpu to the cpu, so when we
        // resize the image, we lose all the data. There might be a way to get the
        // data soon though.

        image.resize(Extent3d {
            width: canvas_size.width,
            height: canvas_size.height,
            depth_or_array_layers: 1,
        });
    }
}
