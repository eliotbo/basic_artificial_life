use bevy::{
    diagnostic::{FrameTimeDiagnosticsPlugin, LogDiagnosticsPlugin},
    prelude::*,
};

use basic_artificial_life::*;
use bevy_framepace::{FramepacePlugin, FramepaceSettings, Limiter};

// TODO: start from lobster's code instead of mine
// - use buffer instead of pixels for particles
// -    add possibility for a second particle per cell
// - change the decode and encode functions
// - add way to adjust grid size

// Ideas:
// 1) make mass go up and two particles share the same cell. Then, it becomes a
//    new particle with new properties and it can spontaneously split into two
//    of the original particles. When it does, it generates a repulsive force
//    field that pushes the particles close by outwards. This would make way for
//    new particles to be born.

// pub const NUM_PARTICLES_X: u32 = 800;
// pub const NUM_PARTICLES_Y: u32 = 400;
// pub const NUM_PARTICLES: usize = (NUM_PARTICLES_X * NUM_PARTICLES_Y) as usize;

// pub const WINDOW_WIDTH: f32 = 800.;
// pub const WINDOW_HEIGHT: f32 = 400.;

fn main() {
    let mut app = App::new();

    app.insert_resource(ClearColor(Color::GRAY))
        .insert_resource(WindowDescriptor {
            width: WINDOW_WIDTH,
            height: WINDOW_HEIGHT,
            cursor_visible: true,
            // position: WindowPosition::At(Vec2::new(500.0, 400.0)),
            position: WindowPosition::At(Vec2::new(50.0, 40.0)),
            present_mode: bevy::window::PresentMode::Immediate, // uncomment for unthrottled FPS
            ..default()
        })
        .insert_resource(ShadertoyCanvas {
            width: WINDOW_WIDTH as u32,
            height: WINDOW_HEIGHT as u32,
            borders: 0.0,
            position: Vec3::new(0.0, 0.0, 0.0),
        })
        .add_plugins(DefaultPlugins)
        .add_plugin(FramepacePlugin)
        .add_plugin(ShadertoyPlugin)
        .add_plugin(FrameTimeDiagnosticsPlugin::default())
        .add_plugin(LogDiagnosticsPlugin::default())
        .add_startup_system(setup)
        .run();
}

fn setup(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    mut st_res: ResMut<ShadertoyResources>,
    mut settings: ResMut<FramepaceSettings>,
) {
    let example = "toy";
    st_res.include_debugger = false;

    let all_shader_handles: ShaderHandles =
        make_and_load_shaders2(example, &asset_server, st_res.include_debugger);

    asset_server.watch_for_changes().unwrap();
    commands.insert_resource(all_shader_handles);

    settings.limiter = Limiter::from_framerate(30.0);
}

// system that updates the uniform
