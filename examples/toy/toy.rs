use bevy::{
    diagnostic::{FrameTimeDiagnosticsPlugin, LogDiagnosticsPlugin},
    prelude::*,
};

use basic_artificial_life::*;

// TODO: start from lobster's code instead of mine
// - use buffer instead of pixels for particles
// -    add possibility for a second particle per cell
// - change the decode and encode functions
// - add way to adjust grid size

fn main() {
    let mut app = App::new();

    app.insert_resource(ClearColor(Color::GRAY))
        .insert_resource(WindowDescriptor {
            width: 1600.,
            height: 800.,
            cursor_visible: true,
            // position: WindowPosition::At(Vec2::new(500.0, 400.0)),
            position: WindowPosition::At(Vec2::new(50.0, 40.0)),
            // present_mode: PresentMode::Immediate, // uncomment for unthrottled FPS
            ..default()
        })
        .insert_resource(ShadertoyCanvas {
            width: 1600. as u32,
            height: 800.0 as u32,
            borders: 0.0,
            position: Vec3::new(0.0, 0.0, 0.0),
        })
        .add_plugins(DefaultPlugins)
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
) {
    let example = "toy";
    st_res.include_debugger = false;

    let all_shader_handles: ShaderHandles =
        make_and_load_shaders2(example, &asset_server, st_res.include_debugger);

    asset_server.watch_for_changes().unwrap();
    commands.insert_resource(all_shader_handles);
}

// system that updates the uniform
