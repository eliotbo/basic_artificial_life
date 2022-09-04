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
//

use bevy::{
    core::{cast_slice, FloatOrd, Pod, Time, Zeroable},
    core_pipeline::node::MAIN_PASS_DEPENDENCIES,
    diagnostic::{FrameTimeDiagnosticsPlugin, LogDiagnosticsPlugin},
    prelude::*,
    render::{
        render_asset::RenderAssets,
        render_graph::{self, NodeLabel, RenderGraph},
        // render_resource::*,
        render_resource::{std140::AsStd140, *},
        renderer::{RenderContext, RenderDevice, RenderQueue},
        RenderApp,
        RenderStage,
    },
    window::{PresentMode, WindowResized},
};

use std::{borrow::Cow, num::NonZeroU64}; // not compatible with WASM -->

mod texture_a;
use texture_a::*;

mod helpers;
use helpers::*;

mod texture_b;
use texture_b::*;

mod texture_c;
use texture_c::*;

mod texture_d;
use texture_d::*;

// pub const SIZE: (u32, u32) = (1280, 720);
pub const WORKGROUP_SIZE: u32 = 8;
// pub const NUM_PARTICLES: u32 = 256;
pub const BORDERS: f32 = 0.8;

pub const WINDOW_WIDTH: f32 = 960.;
pub const WINDOW_HEIGHT: f32 = 600.;

#[derive(Clone)]
pub struct ShadertoyTextures {
    font_texture_handle: Handle<Image>,
    rgba_noise_256_handle: Handle<Image>,
}

pub struct ShadertoyResources {
    number_of_frames: u32,
    time_since_reset: f32,
    include_debugger: bool,
}

fn main() {
    let mut app = App::new();

    app.insert_resource(ClearColor(Color::GRAY))
        .insert_resource(WindowDescriptor {
            width: 960.,
            height: 600.,
            cursor_visible: true,
            present_mode: PresentMode::Immediate, // uncomment for unthrottled FPS
            ..default()
        })
        // .insert_resource(BuffersData::default())
        .insert_resource(CommonUniform::new(Vec2::new(960., 600.)))
        .insert_resource(CanvasSize {
            width: (960.0_f32 * BORDERS).floor() as u32,
            height: (600.0_f32 * BORDERS).floor() as u32,
        })
        .insert_resource(ShadertoyResources {
            number_of_frames: 0,
            time_since_reset: 0.0,
            include_debugger: false,
        })
        .add_plugins(DefaultPlugins)
        .add_system(bevy::input::system::exit_on_esc_system)
        .add_plugin(ShadertoyPlugin)
        .add_plugin(FrameTimeDiagnosticsPlugin::default())
        .add_plugin(LogDiagnosticsPlugin::default())
        .add_startup_system(setup)
        .add_system(update_common_uniform)
        .run();
}

fn setup(
    mut commands: Commands,
    mut images: ResMut<Assets<Image>>,
    canvas_size: Res<CanvasSize>,
    // mut shaders: ResMut<Assets<Shader>>,
    asset_server: Res<AssetServer>,
    windows: Res<Windows>,
    st_res: Res<ShadertoyResources>,
    mut common_uniform: ResMut<CommonUniform>,
    // mut custom_materials: ResMut<Assets<CustomMaterial>>,
) {
    commands.spawn_bundle(OrthographicCameraBundle::new_2d());

    let mut image = Image::new_fill(
        Extent3d {
            width: canvas_size.width,
            height: canvas_size.height,
            depth_or_array_layers: 1,
        },
        TextureDimension::D2,
        &[0, 0, 0, 0],
        TextureFormat::Rgba32Float,
    );
    image.texture_descriptor.usage =
        TextureUsages::COPY_DST | TextureUsages::STORAGE_BINDING | TextureUsages::TEXTURE_BINDING;

    let image = images.add(image);

    commands.insert_resource(MainImage(image.clone()));

    commands.spawn_bundle(SpriteBundle {
        sprite: Sprite {
            custom_size: Some(Vec2::new(
                canvas_size.width as f32,
                canvas_size.height as f32,
            )),
            ..default()
        },
        texture: image.clone(),
        // // the y axis of a bevy window is flipped compared to shadertoy. We fix it
        // // by rotating the sprite 180 degrees, but this comes at the cost of a mirrored
        // // image in the x axis.
        // transform: Transform::from_rotation(bevy::math::Quat::from_rotation_z(
        //     core::f32::consts::PI,
        // )),
        transform: Transform::from_translation(Vec3::new(0.0, 0.5, 0.0)),
        ..default()
    });

    let font_texture_handle: Handle<Image> = asset_server.load("textures/font.png");
    let rgba_noise_256_handle: Handle<Image> = asset_server.load("textures/rgba_noise_256.png");

    commands.insert_resource(ShadertoyTextures {
        font_texture_handle,
        rgba_noise_256_handle,
    });

    // wait for the textures to be loaded
    // TODO: check if the textures are loaded in the queue phase
    use std::{thread, time};
    let ten_millis = time::Duration::from_millis(100);
    thread::sleep(ten_millis);

    let window = windows.primary();
    // let mut common_uniform = CommonUniform::default();

    common_uniform.i_resolution.x = window.width();
    common_uniform.i_resolution.y = window.height();
    // commands.insert_resource(common_uniform);

    // TODO
    // rain: https://www.shadertoy.com/view/wdGSzw
    // fix clouds

    // let example = "clouds";
    // let example = "minimal";
    // let example = "paint";
    // let example = "paint_streams2";
    // let example = "seascape";
    // let example = "sunset";
    // let example = "fluid";
    // let example = "dry_ice";

    // let example = "fire";
    // let example = "debugger";
    // let example = "molecular_dynamics";
    // let example = "love_and_domination";
    // let example = "dancing_tree";
    let example = "life";

    let all_shader_handles: ShaderHandles =
        make_and_load_shaders2(example, &asset_server, st_res.include_debugger);

    commands.insert_resource(all_shader_handles);
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

#[derive(Component, Default, Clone, AsStd140)]
pub struct CommonUniform {
    pub i_time: f32,
    pub i_time_delta: f32,
    pub i_frame: f32,
    pub i_sample_rate: f32, // sound sample rate

    pub i_mouse: Vec4,
    pub i_resolution: Vec2,

    pub forces: Mat4,

    // pub i_channel_time: Vec4,
    // pub i_channel_resolution: Vec4,
    // pub i_date: [i32; 4],
    pub changed_window_size: f32,
}

impl CommonUniform {
    pub fn new(i_resolution: Vec2) -> Self {
        Self {
            i_resolution,
            ..Default::default()
        }
    }
}

// pub struct QuadTreeMeta {
//     buffer: Buffer,
// }

pub struct CommonUniformMeta {
    buffer: Buffer,
}

pub struct Buffers {
    // buffer_a: BufferVec<BufferA>,
    buffer_a: Buffer,
    buffer_b: Buffer,
    buffer_c: Buffer,
    buffer_d: Buffer,
    quad_tree_buffer: Buffer,
}

impl Buffers {
    pub fn new(
        render_device: &RenderDevice,
        label: Option<&str>,
        window_size: Option<Vec2>,
    ) -> Self {
        let mut pixels_capacity_bytes: BufferAddress =
            WINDOW_WIDTH as u64 * WINDOW_HEIGHT as u64 * 4 * 4;

        if let Some(resolution) = window_size {
            pixels_capacity_bytes = resolution.x as u64 * resolution.y as u64 * 4 * 4;
        }

        let buffer_a = render_device.create_buffer(&BufferDescriptor {
            label,
            size: pixels_capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffer_b = render_device.create_buffer(&BufferDescriptor {
            label,
            size: pixels_capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffer_c = render_device.create_buffer(&BufferDescriptor {
            label,
            size: pixels_capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffer_d = render_device.create_buffer(&BufferDescriptor {
            label,
            size: pixels_capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let quad_tree_buffer = render_device.create_buffer(&BufferDescriptor {
            label,
            size: pixels_capacity_bytes,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        Self {
            buffer_a,
            buffer_b,
            buffer_c,
            buffer_d,
            quad_tree_buffer,
        }
    }

    fn make_buffer_layout(binding: u32, size: u64) -> BindGroupLayoutEntry {
        BindGroupLayoutEntry {
            binding,
            visibility: ShaderStages::COMPUTE,
            ty: BindingType::Buffer {
                ty: BufferBindingType::Storage { read_only: false },
                has_dynamic_offset: false,
                min_binding_size: BufferSize::new(size),
            },
            count: None,
        }
    }

    fn make_buffer_bind_group(&self, binding: u32, buffer_size: u64, name: &str) -> BindGroupEntry {
        let buffer = match name {
            "a" => &self.buffer_a,
            "b" => &self.buffer_b,
            "c" => &self.buffer_c,
            "d" => &self.buffer_d,
            _ => &self.quad_tree_buffer,
        };

        BindGroupEntry {
            binding,
            resource: BindingResource::Buffer(BufferBinding {
                buffer,
                offset: 0,
                size: Some(NonZeroU64::new(buffer_size).unwrap()),
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
    mut canvas_size: ResMut<CanvasSize>,

    mut frames_accum: ResMut<ShadertoyResources>,

    render_device: Res<RenderDevice>,
) {
    // update resolution
    for window_resize in window_resize_event.iter() {
        // let old_buffer_length =
        //     (common_uniform.i_resolution.x * common_uniform.i_resolution.y) as i32;

        common_uniform.changed_window_size = 1.0;

        common_uniform.i_resolution.x = (window_resize.width * BORDERS).floor();
        common_uniform.i_resolution.y = (window_resize.height * BORDERS).floor();

        canvas_size.width = common_uniform.i_resolution.x as u32;
        canvas_size.height = common_uniform.i_resolution.y as u32;

        for (mut sprite, _, image_handle) in query.iter_mut() {
            // let pos = transform.translation;

            sprite.custom_size = Some(common_uniform.i_resolution);

            make_new_texture(&canvas_size, image_handle, &mut images);

            // println!("sprite.custom_size : {:?}", sprite.custom_size);
        }
    }

    // update mouse position
    let window = windows.primary();
    if let Some(mouse_pos) = window.cursor_position() {
        let mut mp = mouse_pos;
        // println!("mp: {:?}", mp);

        for (_, transform, _) in query.iter() {
            let pos = transform.translation.truncate();
            let window_size = Vec2::new(window.width(), window.height());
            let top_left = pos + (window_size - common_uniform.i_resolution) / 2.0;

            // let bottom_right = top_left + common_uniform.i_resolution;

            common_uniform.i_mouse.x = mp.x - top_left.x;
            // common_uniform.i_mouse.y = common_uniform.i_resolution.y - (mp.y - top_left.y);
            common_uniform.i_mouse.y = (mp.y - top_left.y);
            // println!("mouse: {:?}", mouse_button_input.pressed(MouseButton::Left));

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
            // println!("mouse: {:?}", common_uniform.i_mouse);
        }

        // println!("{:?}", mp);
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

#[derive(Clone)]
pub struct ShaderHandles {
    pub image_shader: Handle<Shader>,
    pub texture_a_shader: Handle<Shader>,
    pub texture_b_shader: Handle<Shader>,
    pub texture_c_shader: Handle<Shader>,
    pub texture_d_shader: Handle<Shader>,
}

impl Plugin for ShadertoyPlugin {
    fn build(&self, app: &mut App) {
        // let mut common_uniform = app.world.resource_mut::<CommonUniform>();
        // common_uniform.i_frame += 1.0;

        let render_app = app.sub_app_mut(RenderApp);

        let render_device = render_app.world.resource::<RenderDevice>();

        if let Some(canvas) = render_app.world.get_resource::<CanvasSize>() {
            println!("canvas: {:?}", canvas);
        }

        let common_uniform_buffer = render_device.create_buffer(&BufferDescriptor {
            label: Some("common uniform buffer"),
            size: CommonUniform::std140_size_static() as u64,
            usage: BufferUsages::UNIFORM | BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let quad_tree_buffer = render_device.create_buffer(&BufferDescriptor {
            label: Some("quad tree buffer"),
            size: CommonUniform::std140_size_static() as u64,
            usage: BufferUsages::COPY_DST | BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let buffers = Buffers::new(&render_device.clone(), None, None);
        //
        render_app
            .insert_resource(CommonUniformMeta {
                buffer: common_uniform_buffer,
            })
            // .insert_resource(QuadTreeMeta {
            //     buffer: quad_tree_buffer,
            // })
            .insert_resource(buffers)
            .insert_resource(CommonUniform::default())
            .add_system_to_stage(RenderStage::Prepare, prepare_common_uniform_and_buffers)
            .init_resource::<ShadertoyPipelines>()
            .add_system_to_stage(RenderStage::Extract, extract_main_image)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group.label("main_queue"))
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_a.after("main_queue"))
            // .init_resource::<TextureAPipeline>();
            // .add_system_to_stage(RenderStage::Extract, extract_texture_a)
            // .init_resource::<TextureBPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_b)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_b.after("main_queue"))
            // .init_resource::<TextureCPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_c)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_c.after("main_queue"))
            // .init_resource::<TextureDPipeline>()
            // .add_system_to_stage(RenderStage::Extract, extract_texture_d)
            .add_system_to_stage(RenderStage::Queue, queue_bind_group_d.after("main_queue"));

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

        // render_graph
        //     .add_node_edge("texture_a", "main_image")
        //     .unwrap();

        render_graph
            .add_node_edge("main_image", MAIN_PASS_DEPENDENCIES)
            .unwrap();
    }
}

pub struct ShadertoyPipelines {
    main_image_group_layout: BindGroupLayout,
    buffers_group_layout: BindGroupLayout,
}

impl ShadertoyPipelines {
    pub fn new(buffer_min_binding_size: u64, render_device: &RenderDevice) -> Self {
        let uniform_descriptor = BindGroupLayoutEntry {
            binding: 0,
            visibility: ShaderStages::COMPUTE,
            ty: BindingType::Buffer {
                ty: BufferBindingType::Uniform,
                has_dynamic_offset: false,
                min_binding_size: BufferSize::new(CommonUniform::std140_size_static() as u64),
            },
            count: None,
        };

        let buffers_group_layout =
            render_device.create_bind_group_layout(&BindGroupLayoutDescriptor {
                label: Some("any_buffer_layout"),
                entries: &[
                    uniform_descriptor,
                    Buffers::make_buffer_layout(1, buffer_min_binding_size),
                    Buffers::make_buffer_layout(2, buffer_min_binding_size),
                    Buffers::make_buffer_layout(3, buffer_min_binding_size),
                    Buffers::make_buffer_layout(4, buffer_min_binding_size),
                    Buffers::make_buffer_layout(10, buffer_min_binding_size),
                ],
            });

        let main_image_group_layout =
            render_device.create_bind_group_layout(&BindGroupLayoutDescriptor {
                label: Some("main_layout"),
                entries: &[
                    uniform_descriptor,
                    Buffers::make_buffer_layout(1, buffer_min_binding_size),
                    Buffers::make_buffer_layout(2, buffer_min_binding_size),
                    Buffers::make_buffer_layout(3, buffer_min_binding_size),
                    Buffers::make_buffer_layout(4, buffer_min_binding_size),
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
                    // BindGroupLayoutEntry {
                    //     binding: 10,
                    //     visibility: ShaderStages::COMPUTE,
                    //     ty: BindingType::Sampler(SamplerBindingType::Filtering),
                    //     count: None,
                    // },
                    Buffers::make_buffer_layout(10, buffer_min_binding_size),
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
        let mut buffer_min_binding_size =
            (WINDOW_HEIGHT as u64 * WINDOW_WIDTH as u64 * 4 * 4) as u64;

        let common_uni = world.get_resource_mut::<CommonUniform>();
        if let Some(uniform) = common_uni {
            buffer_min_binding_size =
                uniform.i_resolution.x as u64 * uniform.i_resolution.y as u64 * 4 * 4;
        }

        let render_device = world.resource::<RenderDevice>();

        ShadertoyPipelines::new(buffer_min_binding_size, render_device)
    }
}

#[derive(Deref)]
struct MainImage(Handle<Image>);

struct MainImageBindGroup {
    main_image_bind_group: BindGroup,
    init_pipeline: CachedComputePipelineId,
    update_pipeline: CachedComputePipelineId,
}

// write the extracted common uniform into the corresponding uniform buffer
pub fn prepare_common_uniform_and_buffers(
    // mut commands: Commands,
    common_uniform_meta: ResMut<CommonUniformMeta>,
    // buffers_meta: ResMut<Buffers>,
    // buffer_a: Res<BufferA>,
    render_queue: Res<RenderQueue>,
    mut common_uniform: ResMut<CommonUniform>,
    // mut buffers: ResMut<Buffers>,
    render_device: Res<RenderDevice>,
    mut pipelines: ResMut<ShadertoyPipelines>,
) {
    use bevy::render::render_resource::std140::Std140;
    let std140_common_uniform = common_uniform.as_std140();
    let bytes = std140_common_uniform.as_bytes();

    render_queue.write_buffer(
        &common_uniform_meta.buffer,
        0,
        bevy::core::cast_slice(&bytes),
    );

    // modify the pipelines according to the new window size if applicable
    if common_uniform.changed_window_size > 0.5 {
        *pipelines = ShadertoyPipelines::new(
            common_uniform.i_resolution.x as u64 * common_uniform.i_resolution.y as u64 * 4 * 4,
            &render_device,
        );
        common_uniform.changed_window_size = 0.0;
    }
}

pub struct ChangeBufferSize(pub bool);

fn extract_main_image(
    mut commands: Commands,
    image: Res<MainImage>,
    font_image: ResMut<ShadertoyTextures>,
    common_uniform: Res<CommonUniform>,
    all_shader_handles: Res<ShaderHandles>,
    canvas_size: Res<CanvasSize>,

    mut window_resize_event: EventReader<WindowResized>,
    // render_device: Res<RenderDevice>,
    // mut render_graph: ResMut<RenderGraph>,
    // mut buffers: ResMut<Buffers>,
    // mut pipelines: ResMut<ShadertoyPipelines>,
) {
    // insert common uniform only once
    commands.insert_resource(common_uniform.clone());

    commands.insert_resource(MainImage(image.clone()));

    commands.insert_resource(font_image.clone());

    commands.insert_resource(all_shader_handles.clone());

    commands.insert_resource(canvas_size.clone());

    let mut change_buffer_size = false;

    for _ in window_resize_event.iter() {
        change_buffer_size = true;

        // *buffers = Buffers::new(
        //     &render_device.clone(),
        //     None,
        //     Some(common_uniform.i_resolution),
        // );
    }

    commands.insert_resource(ChangeBufferSize(change_buffer_size));
}

fn queue_bind_group(
    mut commands: Commands,
    pipelines: ResMut<ShadertoyPipelines>,

    gpu_images: Res<RenderAssets<Image>>,
    shadertoy_textures: Res<ShadertoyTextures>,
    main_image: Res<MainImage>,
    render_device: Res<RenderDevice>,
    mut pipeline_cache: ResMut<PipelineCache>,
    all_shader_handles: Res<ShaderHandles>,
    common_uniform: ResMut<CommonUniform>,
    common_uniform_meta: ResMut<CommonUniformMeta>,
    // quad_tree_meta: ResMut<QuadTreeMeta>,
    mut buffers: ResMut<Buffers>,
    mut change_buffer_size_res: ResMut<ChangeBufferSize>,
    mut render_graph: ResMut<RenderGraph>,
    // mut texture_a_node: ResMut<TextureANode>,
    // mut main_node: ResMut<MainNode>,
) {
    // buffe size is number_of_pixels * 4 (rgba) * 4 bytes (float)
    let buffer_size =
        common_uniform.i_resolution.x as u64 * common_uniform.i_resolution.y as u64 * 4 * 4;

    if change_buffer_size_res.0 {
        change_buffer_size_res.0 = false;

        *buffers = Buffers::new(
            &render_device.clone(),
            None,
            Some(common_uniform.i_resolution),
        );

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

    let main_init_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
        label: None,
        layout: Some(vec![pipelines.main_image_group_layout.clone()]),
        shader: all_shader_handles.image_shader.clone(),
        shader_defs: vec!["INIT".to_string()],
        entry_point: Cow::from("update"),
    });

    let main_update_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
        label: None,
        layout: Some(vec![pipelines.main_image_group_layout.clone()]),
        shader: all_shader_handles.image_shader.clone(),
        shader_defs: vec![],
        entry_point: Cow::from("update"),
    });

    let main_view = &gpu_images[&main_image.0];
    let font_view = &gpu_images[&shadertoy_textures.font_texture_handle];
    let rgba_noise_256_view = &gpu_images[&shadertoy_textures.rgba_noise_256_handle];

    let main_image_bind_group = render_device.create_bind_group(&BindGroupDescriptor {
        label: Some("main_bind_group"),
        layout: &pipelines.main_image_group_layout,
        entries: &[
            BindGroupEntry {
                binding: 0,
                resource: common_uniform_meta.buffer.as_entire_binding(),
            },
            buffers.make_buffer_bind_group(1, buffer_size, "a"),
            buffers.make_buffer_bind_group(2, buffer_size, "b"),
            buffers.make_buffer_bind_group(3, buffer_size, "c"),
            buffers.make_buffer_bind_group(4, buffer_size, "d"),
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
            buffers.make_buffer_bind_group(10, buffer_size, "quad_tree"),
            // BindGroupEntry {
            //     binding: 10,
            //     resource: quad_tree.buffer.as_entire_binding(),
            // },
        ],
    });

    commands.insert_resource(MainImageBindGroup {
        main_image_bind_group,
        init_pipeline: main_init_pipeline.clone(),
        update_pipeline: main_update_pipeline.clone(),
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
        // let mut changed_window = world.resource_mut::<ChangeBufferSize>();
        // if changed_window.0 {
        //     self.state = ShadertoyState::Loading;
        //     changed_window.0 = false;
        // }

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
        let canvas_size = world.resource::<CanvasSize>();

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
                pass.dispatch(
                    canvas_size.width / WORKGROUP_SIZE,
                    canvas_size.height / WORKGROUP_SIZE,
                    1,
                );
            }

            ShadertoyState::Update => {
                let update_pipeline = pipeline_cache
                    .get_compute_pipeline(update_pipeline_cache)
                    .unwrap();
                pass.set_pipeline(update_pipeline);
                pass.dispatch(
                    canvas_size.width / WORKGROUP_SIZE,
                    canvas_size.height / WORKGROUP_SIZE,
                    1,
                );
            }
        }

        Ok(())
    }
}
