use bevy::{
    prelude::*,
    render::{
        render_graph,
        render_resource::*,
        renderer::{RenderContext, RenderDevice},
    },
};

use crate::{
    Buffers, CommonUniformMeta, ShaderHandles, ShadertoyCanvas, ShadertoyPipelines, ShadertoyState,
    NUM_PARTICLES_X, NUM_PARTICLES_Y, WORKGROUP_SIZE,
};

struct TextureDBindGroup {
    texture_d_bind_group: BindGroup,
    init_pipeline: CachedComputePipelineId,
    update_pipeline: CachedComputePipelineId,
}

pub fn queue_bind_group_d(
    mut commands: Commands,
    pipelines: Res<ShadertoyPipelines>,
    render_device: Res<RenderDevice>,
    mut pipeline_cache: ResMut<PipelineCache>,
    common_uniform_meta: ResMut<CommonUniformMeta>,

    all_shader_handles: Res<ShaderHandles>,
    // common_uniform: Res<ExtractedUniform>,
    buffers: ResMut<Buffers>,
) {
    // buffe size is number_of_pixels * 4 (rgba) * 4 bytes (float)
    // let buffer_size = buffers.buffer_size;
    // let buffer_size =
    //     common_uniform.0.i_resolution.x as u64 * common_uniform.0.i_resolution.y as u64 * 4 * 4;
    // common_uniform.i_resolution.x as u64 * common_uniform.i_resolution.y as u64 * 4 * 4;

    let init_pipeline = pipeline_cache.queue_compute_pipeline(Buffers::make_pipeline_descriptor(
        &pipelines,
        vec!["INIT".to_string()],
        all_shader_handles.texture_d_shader.clone(),
    ));

    let update_pipeline = pipeline_cache.queue_compute_pipeline(Buffers::make_pipeline_descriptor(
        &pipelines,
        vec![],
        all_shader_handles.texture_d_shader.clone(),
    ));

    let texture_d_bind_group = render_device.create_bind_group(&BindGroupDescriptor {
        label: Some("texture_d_bind_group"),
        layout: &pipelines.buffers_group_layout,
        entries: &[
            BindGroupEntry {
                binding: 0,
                resource: common_uniform_meta.buffer.as_entire_binding(),
            },
            buffers.make_buffer_bind_group(1, "a"),
            buffers.make_buffer_bind_group(2, "b"),
            buffers.make_buffer_bind_group(3, "c"),
            buffers.make_buffer_bind_group(4, "d"),
            // buffers.make_buffer_bind_group(10, buffer_size, "quad_tree"),
        ],
    });

    commands.insert_resource(TextureDBindGroup {
        texture_d_bind_group,
        init_pipeline: init_pipeline.clone(),
        update_pipeline: update_pipeline.clone(),
    });
}

pub struct TextureDNode {
    pub state: ShadertoyState,
}

impl Default for TextureDNode {
    fn default() -> Self {
        Self {
            state: ShadertoyState::Loading,
        }
    }
}

impl render_graph::Node for TextureDNode {
    fn update(&mut self, world: &mut World) {
        let pipeline_cache = world.resource::<PipelineCache>();

        let bind_group = world.resource::<TextureDBindGroup>();

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
        let bind_group = world.resource::<TextureDBindGroup>();
        let canvas_size = world.resource::<ShadertoyCanvas>();

        // let texture_a_bind_group = &bind_group.texture_a_bind_group;
        // let texture_b_bind_group = &bind_group.texture_b_bind_group;
        // let texture_c_bind_group = &bind_group.texture_c_bind_group;
        let texture_d_bind_group = &bind_group.texture_d_bind_group;

        let init_pipeline_cache = bind_group.init_pipeline;
        let update_pipeline_cache = bind_group.update_pipeline;

        let pipeline_cache = world.resource::<PipelineCache>();

        let mut pass = render_context
            .command_encoder
            .begin_compute_pass(&ComputePassDescriptor::default());

        pass.set_bind_group(0, texture_d_bind_group, &[]);
        // pass.set_bind_group(1, texture_b_bind_group, &[]);
        // pass.set_bind_group(2, texture_c_bind_group, &[]);
        // pass.set_bind_group(3, texture_d_bind_group, &[]);

        // select the pipeline based on the current state
        match self.state {
            ShadertoyState::Loading => {}

            ShadertoyState::Init => {
                let init_pipeline = pipeline_cache
                    .get_compute_pipeline(init_pipeline_cache)
                    .unwrap();
                pass.set_pipeline(init_pipeline);
                pass.dispatch_workgroups(
                    NUM_PARTICLES_X as u32 / WORKGROUP_SIZE,
                    NUM_PARTICLES_Y as u32 / WORKGROUP_SIZE,
                    // canvas_size.width / WORKGROUP_SIZE,
                    // canvas_size.height / WORKGROUP_SIZE,
                    1,
                );
            }

            ShadertoyState::Update => {
                let update_pipeline = pipeline_cache
                    .get_compute_pipeline(update_pipeline_cache)
                    .unwrap();
                pass.set_pipeline(update_pipeline);
                pass.dispatch_workgroups(
                    // canvas_size.width / WORKGROUP_SIZE,
                    // canvas_size.height / WORKGROUP_SIZE,
                    NUM_PARTICLES_X as u32 / WORKGROUP_SIZE,
                    NUM_PARTICLES_Y as u32 / WORKGROUP_SIZE,
                    1,
                );
            }
        }

        Ok(())
    }
}
