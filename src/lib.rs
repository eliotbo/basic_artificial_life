// You actually don't need a quadtree here: https://www.shadertoy.com/view/wdG3Wd
// You can use a simple 2D grid
// 0) each particle has has a diameter d > s * sqrt(2) / 2, where s is the size of the grid cell
//      so two particles can't be in the same cell
// 1) if d < s, then a particle cannot collide with another particle further than the neighboring cells

// instead of storing velocity, you can store next position and correct the position depending on the collision
// https://www.shadertoy.com/view/3lyyDw
// verlet integration
// https://matthias-research.github.io/pages/publications/posBasedDyn.pdf

// for sorting: https://arxiv.org/pdf/1709.02520.pdf
// for BVH: https://developer.nvidia.com/blog/thinking-parallel-part-iii-tree-construction-gpu/
// sorted particles: https://www.shadertoy.com/view/XsjyRm

// given energy consumption, life forms can impart momentum to the medium in which they live,
// such that momentum is conserved.

// TODO:
// 1) reproduce the Paint stream example here
// 2) try to reproduce sand

use bevy::{
    // core::{Pod, Zeroable},
    // core_pipeline::node::MAIN_PASS_DEPENDENCIES,
    prelude::*,
    render::{
        extract_resource::{ExtractResource, ExtractResourcePlugin},
        render_asset::RenderAssets,
        render_graph::{self, NodeLabel, RenderGraph},
        // render_resource::ShaderSize,
        render_resource::*,
        // render_resource::{
        //     encase::private::WriteInto, BindGroup, BindGroupDescriptor, BindGroupEntry,
        //     BindGroupLayout, BindGroupLayoutDescriptor, BindGroupLayoutEntry, BindingResource,
        //     BindingType, Buffer, BufferBindingType, BufferDescriptor, BufferSize, BufferUsages,
        //     CachedComputePipelineId, CachedPipelineState, ComputePassDescriptor,
        //     ComputePipelineDescriptor, Extent3d, PipelineCache, SamplerBindingType, ShaderStages,
        //     ShaderType, StorageTextureAccess, TextureDimension, TextureFormat, TextureSampleType,
        //     TextureUsages, TextureViewDimension,
        // },
        renderer::{RenderContext, RenderDevice, RenderQueue},
        // MainWorld,
        RenderApp,
        RenderStage,
    },
    window::WindowResized,
};

use crevice::std140::AsStd140;
// use crevice::std430::AsStd430;
use std::{borrow::Cow, num::NonZeroU64};

use bevy::{app::ScheduleRunnerSettings, utils::Duration};

use std::fs; // not compatible with WASM -->

mod texture_a;
use texture_a::*;

mod texture_b;
use texture_b::*;

mod texture_c;
use texture_c::*;

mod texture_d;
use texture_d::*;

pub const WORKGROUP_SIZE: u32 = 8;
pub const WORKGROUP_SIZE_BUF: u32 = 8;
// pub const NUM_PARTICLES_X: u32 = 240;
// pub const NUM_PARTICLES_Y: u32 = 150;
pub const NUM_PARTICLES_X: u32 = 200;
pub const NUM_PARTICLES_Y: u32 = 100;
pub const NUM_PARTICLES: usize = (NUM_PARTICLES_X * NUM_PARTICLES_Y) as usize;

pub const WINDOW_WIDTH: f32 = 800.;
pub const WINDOW_HEIGHT: f32 = 400.;

pub const UNIFORM_NUM_SINGLES: u64 = 32;
// pub const BORDERS: f32 = 1.0;

#[derive(Clone, ExtractResource, Debug)]
pub struct ShadertoyCanvas {
    pub width: u32,
    pub height: u32,
    pub borders: f32,
    pub position: Vec3,
}

#[derive(Clone, ExtractResource)]
pub struct ShadertoyTextures {
    font_texture_handle: Handle<Image>,
    rgba_noise_256_handle: Handle<Image>,
    blue_noise_handle: Handle<Image>,
}

#[derive(Clone, ExtractResource)]
pub struct ShadertoyResources {
    number_of_frames: u32,
    time_since_reset: f32,
    pub include_debugger: bool,
}

fn setup(
    mut commands: Commands,
    mut images: ResMut<Assets<Image>>,
    canvas: Res<ShadertoyCanvas>,

    asset_server: Res<AssetServer>,
    windows: Res<Windows>,
    // time: Res<Time>,
) {
    commands.spawn_bundle(Camera2dBundle::default());
    // let window = windows.primary();

    let mut image = Image::new_fill(
        Extent3d {
            width: canvas.width,
            height: canvas.height,
            depth_or_array_layers: 1,
        },
        TextureDimension::D2,
        &[0, 0, 0, 0],
        TextureFormat::Rgba32Float,
    );
    image.texture_descriptor.usage =
        TextureUsages::COPY_DST | TextureUsages::STORAGE_BINDING | TextureUsages::TEXTURE_BINDING;

    let image = images.add(image);

    commands.insert_resource(ChangedWindowSize(false));

    commands.insert_resource(MainImage(image.clone()));

    commands.spawn_bundle(SpriteBundle {
        sprite: Sprite {
            custom_size: Some(Vec2::new(canvas.width as f32, canvas.height as f32)),
            ..default()
        },
        texture: image.clone(),
        // // the y axis of a bevy window is flipped compared to shadertoy. We fix it
        // // by rotating the sprite 180 degrees, but this comes at the cost of a mirrored
        // // image in the x axis.
        // transform: Transform::from_rotation(bevy::math::Quat::from_rotation_z(
        //     core::f32::consts::PI,
        // )),
        transform: Transform::from_translation(canvas.position),
        ..default()
    });

    let font_texture_handle: Handle<Image> = asset_server.load("textures/font.png");
    let rgba_noise_256_handle: Handle<Image> = asset_server.load("textures/rgba_noise_256.png");
    let blue_noise_handle: Handle<Image> = asset_server.load("textures/blue_noise.png");

    commands.insert_resource(ShadertoyTextures {
        font_texture_handle,
        rgba_noise_256_handle,
        blue_noise_handle,
    });

    let window = windows.primary();
    let mut common_uniform = CommonUniform::new();

    common_uniform.i_resolution.x = window.width();
    common_uniform.i_resolution.y = window.height();
    commands.insert_resource(common_uniform);

    // wait for the textures to load
    let ten_millis = std::time::Duration::from_millis(100);
    std::thread::sleep(ten_millis);

    // // let example = "clouds";
    // // let example = "minimal";
    // // let example = "paint";
    // // let example = "paint_streams2";
    // // let example = "seascape";
    // // let example = "sunset";
    // let example = "fluid";
    // // let example = "dry_ice";
    // // let example = "protean_clouds";

    // // let example = "fire2";
    // // let example = "fire";
    // // let example = "debugger";
    // // let example = "molecular_dynamics";
    // // let example = "love_and_domination";
    // // let example = "dancing_tree";

    // let all_shader_handles: ShaderHandles =
    //     make_and_load_shaders2(example, &asset_server, st_res.include_debugger);

    // commands.insert_resource(all_shader_handles);
}

// pub fn make_and_load_shaders(example: &str, asset_server: &Res<AssetServer>) -> ShaderHandles {
//     let image_shader_handle = asset_server.load(&format!("./shaders/{}/image.wgsl", example));
//     let texture_a_shader = asset_server.load(&format!("./shaders/{}/buffer_a.wgsl", example));
//     let texture_b_shader = asset_server.load(&format!("./shaders/{}/buffer_b.wgsl", example));
//     let texture_c_shader = asset_server.load(&format!("./shaders/{}/buffer_c.wgsl", example));
//     let texture_d_shader = asset_server.load(&format!("./shaders/{}/buffer_d.wgsl", example));

//     ShaderHandles {
//         image_shader: image_shader_handle,
//         texture_a_shader,
//         texture_b_shader,
//         texture_c_shader,
//         texture_d_shader,
//     }
// }

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
fn format_and_save_shader(example: &str, buffer_type: &str, include_debugger: bool) {
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

// Copied from Shadertoy.com :
// uniform vec3      iResolution;           // viewport resolution (in pixels)
// uniform float     iTime;                 // shader playback time (in seconds)
// uniform float     iTimeDelta;            // render time (in seconds)
// uniform int       iFrame;                // shader playback frame
// uniform float     iChannelTime[4];       // channel playback time (in seconds)
// uniform vec3      iChannelResolution[4]; // channel resolution (in pixels)
// uniform vec4      iMouse;                // mouse pixel coords. xy: current (if MLB down), zw: click
// uniform samplerXX iChannel0..3;          // input channel. XX = 2D/Cube
// uniform vec4      iDate;                 // (year, month, day, time in seconds)
// uniform float     iSampleRate;           // sound sample rate (i.e., 44100)

const MAX_VEL: f32 = 100.0;

// #[derive(Clone, Copy, PartialEq, Debug)]
// pub struct GridSlot {
//     pub position: Vec2, // position range is 0 to 1. --- 0 is top left of a grid slot
//     pub velocity: Vec2, // velocity range is -MAX_VEL to MAX_VEL
//     pub mass: f32,
//     pub kind: u32,
//     pub id: u32,
//     pub dummy: u32,

//     pub position2: Vec2, // position range is 0 to 1. --- 0 is top left of a grid slot
//     pub velocity2: Vec2, // velocity range is -MAX_VEL to MAX_VEL
//     pub mass2: f32,
//     pub kind2: u32,
//     pub id2: u32,
//     pub dummy2: u32,
//     // still space for two other u8s
// }

// // encoded version of ParticleSlot, such that it can be transferred to the GPU
// #[derive(Clone, Copy, AsStd140)]
// pub struct GridSlotEncoded {
//     pub position: crevice::std140::Vec2, // position range is 0 to 1. --- 0 is top left of a grid slot
//     pub velocity: crevice::std140::Vec2, // velocity range is -MAX_VEL to MAX_VEL
//     pub mass: f32,
//     pub kind: u32,
//     pub id: u32,
//     pub dummy: u32,

//     pub position2: crevice::std140::Vec2, // position range is 0 to 1. --- 0 is top left of a grid slot
//     pub velocity2: crevice::std140::Vec2, // velocity range is -MAX_VEL to MAX_VEL
//     pub mass2: f32,
//     pub kind2: u32,
//     pub id2: u32,
//     pub dummy2: u32,
// }

// impl Into<GridSlot> for GridSlotEncoded {
//     // decode
//     fn into(self) -> GridSlot {
//         GridSlot {
//             position: Vec2::new(self.position.x, self.position.y),
//             velocity: Vec2::new(self.velocity.x, self.velocity.y),
//             mass: self.mass,
//             kind: self.kind,
//             id: self.id,
//             dummy: self.dummy,

//             position2: Vec2::new(self.position2.x, self.position2.y),
//             velocity2: Vec2::new(self.velocity2.x, self.velocity2.y),
//             mass2: self.mass2,
//             kind2: self.kind2,
//             id2: self.id2,
//             dummy2: self.dummy2,
//         }
//     }
// }

// // encode
// impl Into<GridSlotEncoded> for GridSlot {
//     fn into(self) -> GridSlotEncoded {
//         GridSlotEncoded {
//             position: crevice::std140::Vec2 {
//                 x: self.position.x,
//                 y: self.position.y,
//             },
//             velocity: crevice::std140::Vec2 {
//                 x: self.velocity.x,
//                 y: self.velocity.y,
//             },
//             mass: self.mass,
//             kind: self.kind,
//             id: self.id,
//             dummy: self.dummy,

//             position2: crevice::std140::Vec2 {
//                 x: self.position2.x,
//                 y: self.position2.y,
//             },
//             velocity2: crevice::std140::Vec2 {
//                 x: self.velocity2.x,
//                 y: self.velocity2.y,
//             },
//             mass2: self.mass2,
//             kind2: self.kind2,
//             id2: self.id2,
//             dummy2: self.dummy2,
//         }
//     }
// }

// impl Default for GridSlotEncoded {
//     fn default() -> Self {
//         GridSlotEncoded {
//             position: crevice::std140::Vec2 { x: 0.0, y: 0.0 },
//             velocity: crevice::std140::Vec2 { x: 0.0, y: 0.0 },

//             position2: crevice::std140::Vec2 { x: 0.0, y: 0.0 },
//             velocity2: crevice::std140::Vec2 { x: 0.0, y: 0.0 },
//             mass: 0.,
//             kind: 0,
//             id: 0,
//             dummy: 0,
//             mass2: 0.,
//             kind2: 0,
//             id2: 0,
//             dummy2: 0,
//         }
//     }
// }

#[derive(Clone, Copy, PartialEq, Debug)]
pub struct Particle {
    pub x: Vec2,
    pub nx: Vec2,
    pub r: f32,
    pub m: f32,
    pub dummy: Vec2,
}

#[derive(Clone, Copy, PartialEq, Debug, AsStd140)]
pub struct ParticleStd140 {
    pub x: crevice::std140::Vec2,
    pub nx: crevice::std140::Vec2,
    pub r: f32,
    pub m: f32,
    pub dummy: crevice::std140::Vec2,
}

impl Default for ParticleStd140 {
    fn default() -> Self {
        ParticleStd140 {
            x: crevice::std140::Vec2 { x: 0.0, y: 0.0 },
            nx: crevice::std140::Vec2 { x: 0.0, y: 0.0 },
            r: 0.,
            m: 0.,
            dummy: crevice::std140::Vec2 { x: 0.0, y: 0.0 },
        }
    }
}

// encode
impl Into<ParticleStd140> for Particle {
    fn into(self) -> ParticleStd140 {
        ParticleStd140 {
            x: crevice::std140::Vec2 {
                x: self.x.x,
                y: self.x.y,
            },
            nx: crevice::std140::Vec2 {
                x: self.nx.x,
                y: self.nx.y,
            },
            r: self.r,
            m: self.m,
            dummy: crevice::std140::Vec2 {
                x: self.dummy.x,
                y: self.dummy.y,
            },
        }
    }
}

impl Into<Particle> for ParticleStd140 {
    fn into(self) -> Particle {
        Particle {
            x: Vec2::new(self.x.x, self.x.y),
            nx: Vec2::new(self.nx.x, self.nx.y),
            r: self.r,
            m: self.m,
            dummy: Vec2::new(self.dummy.x, self.dummy.y),
        }
    }
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub struct GridSlot {
    pub particle1: Particle,
    pub particle2: Particle,
}

#[derive(Clone, Copy, AsStd140)]
pub struct GridSlotEncoded {
    pub particle1: ParticleStd140,
    pub particle2: ParticleStd140,
}

impl Into<GridSlotEncoded> for GridSlot {
    fn into(self) -> GridSlotEncoded {
        GridSlotEncoded {
            particle1: self.particle1.into(),
            particle2: self.particle2.into(),
        }
    }
}

impl Into<GridSlot> for GridSlotEncoded {
    fn into(self) -> GridSlot {
        GridSlot {
            particle1: self.particle1.into(),
            particle2: self.particle2.into(),
        }
    }
}

impl Default for GridSlotEncoded {
    fn default() -> Self {
        GridSlotEncoded {
            particle1: ParticleStd140::default(),
            particle2: ParticleStd140::default(),
        }
    }
}

impl GridSlotEncoded {
    pub fn get_size_in_bytes() -> BufferAddress {
        let dumdum = Self::default();

        let particle_dummy = dumdum.as_std140();

        let bytes_size: BufferAddress = (particle_dummy.as_bytes().len() * NUM_PARTICLES) as u64;

        return bytes_size;
    }
}

// #[test]
// fn test_particle_slot_encoding() {
//     let slot = GridSlot {
//         // occupied: false,
//         position: Vec2::new(0.3, 0.22),
//         velocity: Vec2::new(11.0, 56.0),
//         id: 1654987,
//         mass: 15,
//         kind: 69,
//     };

//     let slot_meta: GridSlotEncoded = slot.into();
//     let slot_decoded: GridSlot = slot_meta.into();

//     assert_eq!(slot.mass, slot_decoded.mass);
//     assert_eq!(slot.kind, slot_decoded.kind);
//     assert_eq!(slot.id, slot_decoded.id);
//     assert!((slot.position - slot_decoded.position).length() < 0.01);
//     assert!((slot.velocity - slot_decoded.velocity).length() < 0.01);
//     // assert_eq!(slot.velocity, slot_decoded.velocity);
// }

pub struct Buffers {
    // buffer_a: BufferVec<BufferA>,
    // buffer_size: u64,
    buffer_a: Buffer,
    buffer_b: Buffer,
    buffer_c: Buffer,
    buffer_d: Buffer,
    // quad_tree_buffer: Buffer,
}

impl Buffers {
    pub fn new(
        render_device: &RenderDevice,
        label: Option<&str>,
        // window_size: Option<Vec2>,
    ) -> Self {
        // // TODO: change this so it reads actual window size from example
        // let mut pixels_capacity_bytes: BufferAddress =
        //     WINDOW_WIDTH as u64 * WINDOW_HEIGHT as u64 * 4 * 4;

        let capacity_bytes: BufferAddress = GridSlotEncoded::get_size_in_bytes();

        // if let Some(resolution) = window_size {
        //     pixels_capacity_bytes = resolution.x as u64 * resolution.y as u64 * 4 * 4;
        // }

        let buffer_a = render_device.create_buffer(&BufferDescriptor {
            label,
            size: capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffer_b = render_device.create_buffer(&BufferDescriptor {
            label,
            size: capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffer_c = render_device.create_buffer(&BufferDescriptor {
            label,
            size: capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffer_d = render_device.create_buffer(&BufferDescriptor {
            label,
            size: capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        // let quad_tree_buffer = render_device.create_buffer(&BufferDescriptor {
        //     label,
        //     size: capacity_bytes,
        //     usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
        //     mapped_at_creation: false,
        // });

        Self {
            buffer_a,
            buffer_b,
            buffer_c,
            buffer_d,
            // quad_tree_buffer,
            // buffer_size: pixels_capacity_bytes,
        }
    }

    fn make_buffer_layout(binding: u32) -> BindGroupLayoutEntry {
        let capacity_bytes: BufferAddress = GridSlotEncoded::get_size_in_bytes();

        BindGroupLayoutEntry {
            binding,
            visibility: ShaderStages::COMPUTE,
            ty: BindingType::Buffer {
                ty: BufferBindingType::Storage { read_only: false },
                has_dynamic_offset: false,
                min_binding_size: BufferSize::new(capacity_bytes),
            },
            count: None,
        }
    }

    fn make_buffer_bind_group(&self, binding: u32, name: &str) -> BindGroupEntry {
        let capacity_bytes: BufferAddress = GridSlotEncoded::get_size_in_bytes();

        let buffer = match name {
            "a" => &self.buffer_a,
            "b" => &self.buffer_b,
            "c" => &self.buffer_c,
            "d" => &self.buffer_d,
            _ => panic!("Invalid buffer name"),
            // _ => &self.quad_tree_buffer,
        };

        BindGroupEntry {
            binding,
            resource: BindingResource::Buffer(BufferBinding {
                buffer,
                offset: 0,
                size: Some(NonZeroU64::new(capacity_bytes).unwrap()),
            }),
        }
    }

    fn make_pipeline_descriptor(
        pipelines: &Res<ShadertoyPipelines>,
        shader_defs: Vec<String>,
        shader: Handle<Shader>,
    ) -> ComputePipelineDescriptor {
        ComputePipelineDescriptor {
            label: None,
            layout: Some(vec![pipelines.buffers_group_layout.clone()]),
            shader,
            shader_defs: shader_defs,
            entry_point: Cow::from("update"),
        }
    }
}

// use bytemuck::{Pod, Zeroable};
// #[derive(Clone, Copy, bevy::render::render_resource::ShaderType)]
#[derive(Clone, Copy, Default)]
pub struct CommonUniform {
    pub i_resolution: Vec2,
    pub changed_window_size: f32,
    pub padding0: f32,

    pub i_time: f32,
    pub i_time_delta: f32,
    pub i_frame: f32,
    pub i_sample_rate: f32, // sound sample rate

    pub i_mouse: Vec4,

    pub forces: Mat4,

    pub grid_size: UVec2,
    // pub i_channel_time: Vec4,
    // pub i_channel_resolution: Vec4,
    // pub i_date: Vec4,
}

impl CommonUniform {
    pub fn new() -> Self {
        Self {
            grid_size: UVec2::new(NUM_PARTICLES_X, NUM_PARTICLES_Y),
            ..Default::default()
        }

        // Self {
        //     i_resolution: Vec2::ZERO,
        //     changed_window_size: 0.0,
        //     padding0: 0.0,

        //     i_time: 0.,
        //     i_time_delta: 0.,
        //     i_frame: 0.,
        //     i_sample_rate: 0.,

        //     i_mouse: Vec4::ZERO,
        //     // i_channel_time: Vec4::ZERO,
        //     // i_channel_resolution: Vec4::ZERO,
        //     // i_date: Vec4::ZERO,
        // }
    }

    pub fn into_crevice(&self) -> CommonUniformCrevice {
        CommonUniformCrevice {
            i_resolution: crevice::std140::Vec2 {
                x: self.i_resolution.x,
                y: self.i_resolution.y,
            },

            changed_window_size: self.changed_window_size,
            padding0: self.padding0,

            i_time: self.i_time,
            i_time_delta: self.i_time_delta,
            i_frame: self.i_frame,
            i_sample_rate: self.i_sample_rate,

            i_mouse: crevice::std140::Vec4 {
                x: self.i_mouse.x,
                y: self.i_mouse.y,
                z: self.i_mouse.z,
                w: self.i_mouse.w,
            },

            forces: crevice::std140::Mat4 {
                x: crevice::std140::Vec4 {
                    x: self.forces.x_axis.x,
                    y: self.forces.x_axis.y,
                    z: self.forces.x_axis.z,
                    w: self.forces.x_axis.w,
                },
                y: crevice::std140::Vec4 {
                    x: self.forces.y_axis.x,
                    y: self.forces.y_axis.y,
                    z: self.forces.y_axis.z,
                    w: self.forces.y_axis.w,
                },
                z: crevice::std140::Vec4 {
                    x: self.forces.z_axis.x,
                    y: self.forces.z_axis.y,
                    z: self.forces.z_axis.z,
                    w: self.forces.z_axis.w,
                },
                w: crevice::std140::Vec4 {
                    x: self.forces.w_axis.x,
                    y: self.forces.w_axis.y,
                    z: self.forces.w_axis.z,
                    w: self.forces.w_axis.w,
                },
            },

            grid_size: crevice::std140::UVec2 {
                x: self.grid_size.x,
                y: self.grid_size.y,
            },
        }
    }
}

#[derive(Clone, Copy, AsStd140)]
pub struct CommonUniformCrevice {
    pub i_resolution: crevice::std140::Vec2,
    pub changed_window_size: f32,
    pub padding0: f32,

    pub i_time: f32,
    pub i_time_delta: f32,
    pub i_frame: f32,
    pub i_sample_rate: f32, // sound sample rate

    pub i_mouse: crevice::std140::Vec4,
    pub forces: crevice::std140::Mat4,
    pub grid_size: crevice::std140::UVec2,
}

#[derive(Deref)]
pub struct ExtractedUniform(pub CommonUniformCrevice);

impl ExtractResource for ExtractedUniform {
    type Source = CommonUniform;

    fn extract_resource(common_uniform: &Self::Source) -> Self {
        ExtractedUniform(common_uniform.into_crevice().clone())
    }
}

pub struct CommonUniformMeta {
    buffer: Buffer,
    // buffer_size: u64,
}

fn make_new_texture(
    // old_buffer_length: i32,
    canvas_size: &Vec2,
    image_handle: &Handle<Image>,
    images: &mut ResMut<Assets<Image>>,
) {
    if let Some(image) = images.get_mut(image_handle) {
        // There is no easy way to get the data from the gpu to the cpu, so when we
        // resize the image, we lose all the data. There might be a way to get the
        // data soon though.

        image.resize(Extent3d {
            width: canvas_size.x as u32,
            height: canvas_size.y as u32,
            depth_or_array_layers: 1,
        });
    }
}

// also updates the size of the buffers and main texture accordign to the window size
// TODO: update date, channel time, channe l_resolution, sample_rate
fn update_common_uniform(
    mut common_uniform: ResMut<CommonUniform>,
    mut window_resize_event: EventReader<WindowResized>,
    mut query: Query<(&mut Sprite, &Transform, &Handle<Image>)>,
    mut images: ResMut<Assets<Image>>,
    windows: Res<Windows>,
    time: Res<Time>,
    mouse_button_input: Res<Input<MouseButton>>,
    canvas: ResMut<ShadertoyCanvas>,
    // texture_a: Res<TextureA>,
    // texture_b: Res<TextureB>,
    // texture_c: Res<TextureC>,
    // texture_d: Res<TextureD>,
    mut frames_accum: ResMut<ShadertoyResources>,
    mut changed_window_size: ResMut<ChangedWindowSize>,
) {
    // update resolution
    changed_window_size.0 = false;
    for _window_resize in window_resize_event.iter() {
        // canvas.width = common_uniform.i_resolution.x as u32;
        // canvas.height = common_uniform.i_resolution.y as u32;

        // common_uniform.i_resolution.x = (window_resize.width * (1. - canvas.borders)).floor();
        // common_uniform.i_resolution.y = (window_resize.height * (1. - canvas.borders)).floor();

        common_uniform.i_resolution.x = (canvas.width as f32 * (1. - canvas.borders)).floor();
        common_uniform.i_resolution.y = (canvas.height as f32 * (1. - canvas.borders)).floor();
        changed_window_size.0 = true;

        for (mut sprite, _, image_handle) in query.iter_mut() {
            sprite.custom_size = Some(common_uniform.i_resolution);

            make_new_texture(&common_uniform.i_resolution, image_handle, &mut images);
            // make_new_texture(&common_uniform.i_resolution, &texture_a.0, &mut images);
            // make_new_texture(&common_uniform.i_resolution, &texture_b.0, &mut images);
            // make_new_texture(&common_uniform.i_resolution, &texture_c.0, &mut images);
            // make_new_texture(&common_uniform.i_resolution, &texture_d.0, &mut images);
        }
    }

    // update mouse position
    let window = windows.primary();
    if let Some(mouse_pos) = window.cursor_position() {
        let mp = mouse_pos;
        // println!("{:?}", mp);

        for (_, transform, _) in query.iter() {
            let pos = transform.translation.truncate();
            let window_size = Vec2::new(window.width(), window.height());
            let top_left = pos + (window_size - common_uniform.i_resolution) / 2.0;

            common_uniform.i_mouse.x = mp.x - top_left.x;

            common_uniform.i_mouse.y = mp.y - top_left.y;

            if mouse_button_input.just_pressed(MouseButton::Left) {
                common_uniform.i_mouse.z = common_uniform.i_mouse.x;
                common_uniform.i_mouse.w = common_uniform.i_mouse.y;
            }

            if mouse_button_input.pressed(MouseButton::Left) {
                common_uniform.i_mouse.z = common_uniform.i_mouse.z.abs();
                common_uniform.i_mouse.w = common_uniform.i_mouse.w.abs();
            } else {
                common_uniform.i_mouse.z = -common_uniform.i_mouse.z.abs();
                common_uniform.i_mouse.w = -common_uniform.i_mouse.w.abs();
            }
        }
    }

    // update time
    common_uniform.i_time = time.seconds_since_startup() as f32;
    common_uniform.i_time_delta = time.delta_seconds() as f32;
    frames_accum.time_since_reset += time.delta_seconds();
    frames_accum.number_of_frames += 1;
    let fps_refresh_time = 0.5; // seconds

    if frames_accum.time_since_reset > fps_refresh_time {
        common_uniform.i_sample_rate =
            frames_accum.number_of_frames as f32 / frames_accum.time_since_reset;
        frames_accum.time_since_reset = 0.0;
        frames_accum.number_of_frames = 0;
    }

    common_uniform.i_frame += 1.0;
}

pub struct ShadertoyPlugin;

#[derive(Clone, ExtractResource)]
pub struct ShaderHandles {
    pub image_shader: Handle<Shader>,
    pub texture_a_shader: Handle<Shader>,
    pub texture_b_shader: Handle<Shader>,
    pub texture_c_shader: Handle<Shader>,
    pub texture_d_shader: Handle<Shader>,
}

impl Plugin for ShadertoyPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugin(ExtractResourcePlugin::<ExtractedUniform>::default())
            // .add_plugin(ExtractResourcePlugin::<TextureA>::default())
            // .add_plugin(ExtractResourcePlugin::<TextureB>::default())
            // .add_plugin(ExtractResourcePlugin::<TextureC>::default())
            // .add_plugin(ExtractResourcePlugin::<TextureD>::default())
            .add_plugin(ExtractResourcePlugin::<MainImage>::default())
            .add_plugin(ExtractResourcePlugin::<ChangedWindowSize>::default())
            .add_plugin(ExtractResourcePlugin::<ShadertoyResources>::default())
            .add_plugin(ExtractResourcePlugin::<ShadertoyTextures>::default())
            .add_plugin(ExtractResourcePlugin::<ShaderHandles>::default())
            .add_plugin(ExtractResourcePlugin::<ShadertoyCanvas>::default())
            .add_startup_system(setup)
            .add_system(update_common_uniform)
            .insert_resource(ShadertoyResources {
                number_of_frames: 0,
                time_since_reset: 0.0,
                include_debugger: false,
            });

        let render_app = app.sub_app_mut(RenderApp);

        let render_device = render_app.world.resource::<RenderDevice>();

        let buffers = Buffers::new(&render_device.clone(), None);

        let buffer = render_device.create_buffer(&BufferDescriptor {
            label: Some("common uniform buffer"),
            size: std::mem::size_of::<f32>() as u64 * UNIFORM_NUM_SINGLES,
            usage: BufferUsages::UNIFORM | BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        render_app
            .insert_resource(CommonUniformMeta {
                buffer: buffer.clone(),
                // buffer_size: buffers.buffer_size,
            })
            .insert_resource(buffers)
            .insert_resource(ScheduleRunnerSettings::run_loop(Duration::from_secs_f64(
                1.0 / 120.0,
            )))
            .add_system_to_stage(RenderStage::Prepare, prepare_common_uniform)
            .init_resource::<ShadertoyPipelines>()
            // .add_system_to_stage(RenderStage::Extract, extract_stuff_here)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group)
            // .init_resource::<TextureAPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_a)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_a)
            // .init_resource::<TextureBPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_b)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_b)
            // .init_resource::<TextureCPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_c)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_c)
            // .init_resource::<TextureDPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_d)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_d);

        let mut render_graph = render_app.world.resource_mut::<RenderGraph>();

        render_graph.add_node("main_image", MainNode::default());
        render_graph.add_node("texture_a", TextureANode::default());
        render_graph.add_node("texture_b", TextureBNode::default());
        render_graph.add_node("texture_c", TextureCNode::default());
        render_graph.add_node("texture_d", TextureDNode::default());

        render_graph
            .add_node_edge("texture_a", "texture_b")
            .unwrap();

        render_graph
            .add_node_edge("texture_b", "texture_c")
            .unwrap();

        render_graph
            .add_node_edge("texture_c", "texture_d")
            .unwrap();

        render_graph
            .add_node_edge("texture_d", "main_image")
            .unwrap();

        render_graph
            .add_node_edge("main_image", bevy::render::main_graph::node::CAMERA_DRIVER)
            .unwrap();
    }
}

// pub struct ShadertoyPipelines {
//     main_image_group_layout: BindGroupLayout,
// }

pub struct ShadertoyPipelines {
    pub main_image_group_layout: BindGroupLayout,
    // pub abcd_group_layout: BindGroupLayout,
    buffers_group_layout: BindGroupLayout,
}

impl ShadertoyPipelines {
    pub fn make_texture_layout(binding: u32) -> BindGroupLayoutEntry {
        BindGroupLayoutEntry {
            binding,
            visibility: ShaderStages::COMPUTE,
            ty: BindingType::StorageTexture {
                access: StorageTextureAccess::ReadWrite,
                format: TextureFormat::Rgba32Float,
                view_dimension: TextureViewDimension::D2,
            },
            count: None,
        }
    }

    pub fn new(render_device: &RenderDevice) -> Self {
        // info!(
        //     "buffer_min_binding_size: {}",
        //     std::mem::size_of::<CommonUniformCrevice>() as u64
        // );
        let uniform_descriptor = BindGroupLayoutEntry {
            binding: 0,
            visibility: ShaderStages::COMPUTE,
            ty: BindingType::Buffer {
                ty: BufferBindingType::Uniform,
                has_dynamic_offset: false,
                min_binding_size: BufferSize::new(
                    std::mem::size_of::<f32>() as u64 * UNIFORM_NUM_SINGLES,
                ),
                // min_binding_size: BufferSize::new(
                //     std::mem::size_of::<CommonUniformCrevice>() as u64
                // ),
            },
            count: None,
        };

        // let abcd_group_layout =
        //     render_device.create_bind_group_layout(&BindGroupLayoutDescriptor {
        //         label: Some("abcd_layout"),
        //         entries: &[
        //             uniform_descriptor,
        //             ShadertoyPipelines::make_texture_layout(1),
        //             ShadertoyPipelines::make_texture_layout(2),
        //             ShadertoyPipelines::make_texture_layout(3),
        //             ShadertoyPipelines::make_texture_layout(4),
        //         ],
        //     });

        let buffers_group_layout =
            render_device.create_bind_group_layout(&BindGroupLayoutDescriptor {
                label: Some("any_buffer_layout"),
                entries: &[
                    uniform_descriptor,
                    Buffers::make_buffer_layout(1),
                    Buffers::make_buffer_layout(2),
                    Buffers::make_buffer_layout(3),
                    Buffers::make_buffer_layout(4),
                    // Buffers::make_buffer_layout(10, buffer_min_binding_size),
                ],
            });

        let main_image_group_layout =
            render_device.create_bind_group_layout(&BindGroupLayoutDescriptor {
                label: Some("main_layout"),
                entries: &[
                    uniform_descriptor,
                    // ShadertoyPipelines::make_texture_layout(1),
                    // ShadertoyPipelines::make_texture_layout(2),
                    // ShadertoyPipelines::make_texture_layout(3),
                    // ShadertoyPipelines::make_texture_layout(4),
                    Buffers::make_buffer_layout(1),
                    Buffers::make_buffer_layout(2),
                    Buffers::make_buffer_layout(3),
                    Buffers::make_buffer_layout(4),
                    BindGroupLayoutEntry {
                        binding: 5,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::StorageTexture {
                            access: StorageTextureAccess::ReadWrite,
                            format: TextureFormat::Rgba32Float,
                            view_dimension: TextureViewDimension::D2,
                        },
                        count: None,
                    },
                    // font texture
                    BindGroupLayoutEntry {
                        binding: 6,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Texture {
                            sample_type: TextureSampleType::Float { filterable: true },
                            view_dimension: TextureViewDimension::D2,
                            multisampled: false,
                        },
                        count: None,
                    },
                    BindGroupLayoutEntry {
                        binding: 7,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Sampler(SamplerBindingType::Filtering),
                        count: None,
                    },
                    // noise texture
                    BindGroupLayoutEntry {
                        binding: 8,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Texture {
                            sample_type: TextureSampleType::Float { filterable: true },
                            view_dimension: TextureViewDimension::D2,
                            multisampled: false,
                        },
                        count: None,
                    },
                    BindGroupLayoutEntry {
                        binding: 9,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Sampler(SamplerBindingType::Filtering),
                        count: None,
                    },
                    // blue noise texture
                    BindGroupLayoutEntry {
                        binding: 10,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Texture {
                            sample_type: TextureSampleType::Float { filterable: true },
                            view_dimension: TextureViewDimension::D2,
                            multisampled: false,
                        },
                        count: None,
                    },
                    BindGroupLayoutEntry {
                        binding: 11,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Sampler(SamplerBindingType::Filtering),
                        count: None,
                    },
                ],
            });

        ShadertoyPipelines {
            main_image_group_layout,
            buffers_group_layout,
        }
    }
}

impl FromWorld for ShadertoyPipelines {
    fn from_world(world: &mut World) -> Self {
        let render_device = world.resource::<RenderDevice>();

        // let mut buffer_min_binding_size =
        //     (WINDOW_HEIGHT as u64 * WINDOW_WIDTH as u64 * 4 * 4) as u64;
        // let common_uni = world.get_resource::<CommonUniform>();
        // if let Some(uniform) = common_uni {
        //     buffer_min_binding_size =
        //         uniform.i_resolution.x as u64 * uniform.i_resolution.y as u64 * 4 * 4;
        // }

        ShadertoyPipelines::new(render_device)
    }
}

// impl FromWorld for ShadertoyPipelines {
//     fn from_world(world: &mut World) -> Self {
//         let main_image_group_layout =
//             world
//                 .resource::<RenderDevice>()
//                 .create_bind_group_layout(&BindGroupLayoutDescriptor {
//                     label: Some("main_layout"),
//                     entries: &[
//                         BindGroupLayoutEntry {
//                             binding: 0,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::Buffer {
//                                 ty: BufferBindingType::Uniform,
//                                 has_dynamic_offset: false,
//                                 min_binding_size: BufferSize::new(
//                                     CommonUniform::std140_size_static() as u64,
//                                 ),
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 1,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::StorageTexture {
//                                 access: StorageTextureAccess::ReadWrite,
//                                 format: TextureFormat::Rgba32Float,
//                                 view_dimension: TextureViewDimension::D2,
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 2,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::StorageTexture {
//                                 access: StorageTextureAccess::ReadWrite,
//                                 format: TextureFormat::Rgba32Float,
//                                 view_dimension: TextureViewDimension::D2,
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 3,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::StorageTexture {
//                                 access: StorageTextureAccess::ReadWrite,
//                                 format: TextureFormat::Rgba32Float,
//                                 view_dimension: TextureViewDimension::D2,
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 4,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::StorageTexture {
//                                 access: StorageTextureAccess::ReadWrite,
//                                 format: TextureFormat::Rgba32Float,
//                                 view_dimension: TextureViewDimension::D2,
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 5,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::StorageTexture {
//                                 access: StorageTextureAccess::ReadWrite,
//                                 format: TextureFormat::Rgba32Float,
//                                 view_dimension: TextureViewDimension::D2,
//                             },
//                             count: None,
//                         },
//                         // BindGroupLayoutEntry {
//                         //     binding: 6,
//                         //     visibility: ShaderStages::COMPUTE,
//                         //     ty: BindingType::StorageTexture {
//                         //         access: StorageTextureAccess::ReadWrite,
//                         //         format: TextureFormat::Rgba32Float,
//                         //         view_dimension: TextureViewDimension::D2,
//                         //     },
//                         //     count: None,
//                         // },
//                         BindGroupLayoutEntry {
//                             binding: 6,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::Texture {
//                                 sample_type: TextureSampleType::Float { filterable: true },
//                                 view_dimension: TextureViewDimension::D2,
//                                 multisampled: false,
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 7,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::Sampler(SamplerBindingType::Filtering),
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 8,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::Texture {
//                                 sample_type: TextureSampleType::Float { filterable: true },
//                                 view_dimension: TextureViewDimension::D2,
//                                 multisampled: false,
//                             },
//                             count: None,
//                         },
//                         BindGroupLayoutEntry {
//                             binding: 9,
//                             visibility: ShaderStages::COMPUTE,
//                             ty: BindingType::Sampler(SamplerBindingType::Filtering),
//                             count: None,
//                         },
//                     ],
//                 });

//         ShadertoyPipelines {
//             main_image_group_layout,
//         }
//     }
// }

#[derive(Deref, Clone, ExtractResource)]
struct MainImage(Handle<Image>);

// use bevy::core::cast_slice;

struct MainImageBindGroup {
    main_image_bind_group: BindGroup,
    init_pipeline: CachedComputePipelineId,
    update_pipeline: CachedComputePipelineId,
}

// write the extracted common uniform into the corresponding uniform buffer
pub fn prepare_common_uniform(
    common_uniform_meta: ResMut<CommonUniformMeta>,
    render_queue: Res<RenderQueue>,
    extrated_common_uniform_crevice: ResMut<ExtractedUniform>,
    // mut extracted_uniform: ResMut<ExtractedUniform>,
    render_device: Res<RenderDevice>,
    mut pipelines: ResMut<ShadertoyPipelines>,
) {
    // // use bevy::render::render_resource::std140::Std140;
    let std140_common_uniform = extrated_common_uniform_crevice.0.as_std140();
    let bytes = std140_common_uniform.as_bytes();

    // let mut uni = extracted_uniform.0;
    // let blah = uni.write_into::<Buffer>(*common_uniform_meta.buffer);
    // let as_bytes = bevy::core::cast_slice([uni.clone()]);

    // let as_bytes = &uni.0.to_owned().

    // TODO: DO THIS IN THE EXTRACT PHASE?
    // modify the pipelines according to the new window size if applicable
    if extrated_common_uniform_crevice.changed_window_size > 0.5 {
        // let buffer_size = extrated_common_uniform_crevice.i_resolution.x as u64
        //     * extrated_common_uniform_crevice.i_resolution.y as u64
        //     * 4
        //     * 4;
        *pipelines = ShadertoyPipelines::new(&render_device);
    }

    // TODO: HOW TO ACTUALLY SERIALIZE THE UNIFORM
    render_queue.write_buffer(
        &common_uniform_meta.buffer,
        0,
        bytes,
        // as_bytes,
        // bytemuck::cast_slice(as_bytes),
        // bevy::core::cast_slice(&bytes),
    );
}

#[derive(Deref, Clone, ExtractResource)]
pub struct ChangedWindowSize(pub bool);

fn queue_bind_group(
    mut commands: Commands,
    pipeline: Res<ShadertoyPipelines>,

    gpu_images: Res<RenderAssets<Image>>,
    shadertoy_textures: Res<ShadertoyTextures>,
    main_image: Res<MainImage>,
    buffers: ResMut<Buffers>,
    // texture_a_image: Res<TextureA>,
    // texture_b_image: Res<TextureB>,
    // texture_c_image: Res<TextureC>,
    // texture_d_image: Res<TextureD>,
    // textures: Res<ExtractedTextures>,
    render_device: Res<RenderDevice>,
    mut pipeline_cache: ResMut<PipelineCache>,
    all_shader_handles: Res<ShaderHandles>,
    common_uniform_meta: ResMut<CommonUniformMeta>,
    // crevice_common_uniform: Res<ExtractedUniform>,
    changed_size_res: ResMut<ChangedWindowSize>,
    mut render_graph: ResMut<RenderGraph>,
) {
    // let buffer_size = crevice_common_uniform.0.i_resolution.x as u64
    //     * crevice_common_uniform.0.i_resolution.y as u64
    //     * 4
    //     * 4;

    if changed_size_res.0 {
        let main_node: &mut MainNode = render_graph
            .get_node_mut(NodeLabel::Name(Cow::from("main_image")))
            .unwrap();
        main_node.state = ShadertoyState::Loading;

        let texture_a_node: &mut TextureANode = render_graph
            .get_node_mut(NodeLabel::Name(Cow::from("texture_a")))
            .unwrap();
        texture_a_node.state = ShadertoyState::Loading;

        let texture_b_node: &mut TextureBNode = render_graph
            .get_node_mut(NodeLabel::Name(Cow::from("texture_b")))
            .unwrap();
        texture_b_node.state = ShadertoyState::Loading;

        let texture_c_node: &mut TextureCNode = render_graph
            .get_node_mut(NodeLabel::Name(Cow::from("texture_c")))
            .unwrap();
        texture_c_node.state = ShadertoyState::Loading;

        let texture_d_node: &mut TextureDNode = render_graph
            .get_node_mut(NodeLabel::Name(Cow::from("texture_d")))
            .unwrap();
        texture_d_node.state = ShadertoyState::Loading;
    }

    let init_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
        label: None,
        layout: Some(vec![pipeline.main_image_group_layout.clone()]),
        shader: all_shader_handles.image_shader.clone(),
        shader_defs: vec!["INIT".to_string()],
        entry_point: Cow::from("update"),
    });

    let update_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
        label: None,
        layout: Some(vec![pipeline.main_image_group_layout.clone()]),
        shader: all_shader_handles.image_shader.clone(),
        shader_defs: vec![],
        entry_point: Cow::from("update"),
    });

    let main_view = &gpu_images[&main_image.0];
    let font_view = &gpu_images[&shadertoy_textures.font_texture_handle];
    let rgba_noise_256_view = &gpu_images[&shadertoy_textures.rgba_noise_256_handle];
    let blue_noise_view = &gpu_images[&shadertoy_textures.blue_noise_handle];

    let main_image_bind_group = render_device.create_bind_group(&BindGroupDescriptor {
        label: Some("main_bind_group"),
        layout: &pipeline.main_image_group_layout,
        entries: &[
            BindGroupEntry {
                binding: 0,
                resource: common_uniform_meta.buffer.as_entire_binding(),
            },
            buffers.make_buffer_bind_group(1, "a"),
            buffers.make_buffer_bind_group(2, "b"),
            buffers.make_buffer_bind_group(3, "c"),
            buffers.make_buffer_bind_group(4, "d"),
            BindGroupEntry {
                binding: 5,
                resource: BindingResource::TextureView(&main_view.texture_view),
            },
            BindGroupEntry {
                binding: 6,
                resource: BindingResource::TextureView(&font_view.texture_view),
            },
            BindGroupEntry {
                binding: 7,
                resource: BindingResource::Sampler(&font_view.sampler),
            },
            BindGroupEntry {
                binding: 8,
                resource: BindingResource::TextureView(&rgba_noise_256_view.texture_view),
            },
            BindGroupEntry {
                binding: 9,
                resource: BindingResource::Sampler(&rgba_noise_256_view.sampler),
            },
            BindGroupEntry {
                binding: 10,
                resource: BindingResource::TextureView(&blue_noise_view.texture_view),
            },
            BindGroupEntry {
                binding: 11,
                resource: BindingResource::Sampler(&blue_noise_view.sampler),
            },
        ],
    });

    commands.insert_resource(MainImageBindGroup {
        main_image_bind_group,
        init_pipeline: init_pipeline.clone(),
        update_pipeline: update_pipeline.clone(),
    });
}

pub enum ShadertoyState {
    Loading,
    Init,
    Update,
}

pub struct MainNode {
    pub state: ShadertoyState,
}

impl Default for MainNode {
    fn default() -> Self {
        Self {
            state: ShadertoyState::Loading,
        }
    }
}

impl render_graph::Node for MainNode {
    fn update(&mut self, world: &mut World) {
        let pipeline_cache = world.resource::<PipelineCache>();

        let bind_group = world.resource::<MainImageBindGroup>();

        let init_pipeline_cache = bind_group.init_pipeline;
        let update_pipeline_cache = bind_group.update_pipeline;

        match self.state {
            ShadertoyState::Loading => {
                if let CachedPipelineState::Ok(_) =
                    pipeline_cache.get_compute_pipeline_state(init_pipeline_cache)
                {
                    self.state = ShadertoyState::Init
                }
            }
            ShadertoyState::Init => {
                if let CachedPipelineState::Ok(_) =
                    pipeline_cache.get_compute_pipeline_state(update_pipeline_cache)
                {
                    self.state = ShadertoyState::Update
                }
            }
            ShadertoyState::Update => {}
        }
    }

    fn run(
        &self,
        _graph: &mut render_graph::RenderGraphContext,
        render_context: &mut RenderContext,
        world: &World,
    ) -> Result<(), render_graph::NodeRunError> {
        let bind_group = world.resource::<MainImageBindGroup>();
        let canvas_size = world.resource::<ShadertoyCanvas>();

        let init_pipeline_cache = bind_group.init_pipeline;
        let update_pipeline_cache = bind_group.update_pipeline;

        let pipeline_cache = world.resource::<PipelineCache>();

        let mut pass = render_context
            .command_encoder
            .begin_compute_pass(&ComputePassDescriptor {
                label: Some("main_compute_pass"),
            });

        pass.set_bind_group(0, &bind_group.main_image_bind_group, &[]);

        // select the pipeline based on the current state
        match self.state {
            ShadertoyState::Loading => {}

            ShadertoyState::Init => {
                let init_pipeline = pipeline_cache
                    .get_compute_pipeline(init_pipeline_cache)
                    .unwrap();
                pass.set_pipeline(init_pipeline);
                pass.dispatch_workgroups(
                    canvas_size.width / WORKGROUP_SIZE,
                    // NUM_PARTICLES_X as u32 / WORKGROUP_SIZE,
                    canvas_size.height / WORKGROUP_SIZE,
                    // NUM_PARTICLES_Y as u32 / WORKGROUP_SIZE,
                    1,
                );
            }

            ShadertoyState::Update => {
                let update_pipeline = pipeline_cache
                    .get_compute_pipeline(update_pipeline_cache)
                    .unwrap();
                pass.set_pipeline(update_pipeline);
                pass.dispatch_workgroups(
                    canvas_size.width / WORKGROUP_SIZE,
                    // NUM_PARTICLES_X as u32 / WORKGROUP_SIZE,
                    canvas_size.height / WORKGROUP_SIZE,
                    // NUM_PARTICLES_Y as u32 / WORKGROUP_SIZE,
                    1,
                );
            }
        }

        Ok(())
    }
}
