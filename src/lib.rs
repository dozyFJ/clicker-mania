//! Clicker Mania — WolfCraft Rust/wgpu-based portrait clicker.
pub mod game;

use std::{sync::Arc, time::Instant};
use winit::{application::ApplicationHandler, event::WindowEvent, event_loop::{ActiveEventLoop, EventLoop}, window::{Window, WindowId}};
use wolfcraft_common::gpu::GpuContext;

struct Graphics {
    gpu: GpuContext,
    egui: egui::Context,
    state: egui_winit::State,
    renderer: egui_wgpu::Renderer,
}

#[derive(Default)]
struct App {
    window: Option<Arc<Window>>,
    gfx: Option<Graphics>,
    game: game::Game,
    last_tick: Option<Instant>,
}

fn ui(ctx: &egui::Context, game: &mut game::Game) {
    use egui::{Color32, RichText, Stroke};
    let blue = Color32::from_rgb(25, 53, 109);
    let gold = Color32::from_rgb(255, 207, 91);
    let screen = ctx.screen_rect();
    let width = screen.width();
    let button_size = (width * 0.58).min(280.0);
    egui::CentralPanel::default()
        .frame(egui::Frame::none().fill(Color32::from_rgb(70, 146, 190)))
        .show(ctx, |ui| {
            let painter = ui.painter();
            let r = ui.max_rect();
            painter.rect_filled(egui::Rect::from_min_max(egui::pos2(r.left(), r.center().y + 70.0), r.right_bottom()), 0.0, Color32::from_rgb(77, 174, 133));
            painter.circle_filled(egui::pos2(r.center().x, r.center().y + 100.0), button_size * 0.72, Color32::from_rgb(32, 77, 114));
        });
    egui::TopBottomPanel::top("stats").frame(egui::Frame::none().fill(blue).inner_margin(egui::Margin::same(16.0))).show(ctx, |ui| {
        ui.vertical_centered(|ui| {
            ui.label(RichText::new("CLICKER MANIA").size(29.0).strong().color(gold));
            ui.label(RichText::new(format!("МОНЕТЫ: {}", game.coins.floor() as u64)).size(27.0).strong().color(Color32::WHITE));
            ui.label(RichText::new(format!("ВРАГ Lv.{}  HP {}/{}", game.enemy_level, game.enemy_hp, game.enemy_max_hp)).size(23.0).strong().color(gold));
            ui.label(RichText::new(format!("ГЕРОЙ Lv.{}  КОМБО x{}", game.hero_level, 1 + game.combo / 10)).size(17.0).color(Color32::LIGHT_GREEN));
        });
    });
    egui::TopBottomPanel::bottom("dock").frame(egui::Frame::none().fill(blue).inner_margin(egui::Margin::same(9.0))).show(ctx, |ui| {
        ui.columns(4, |cols| {
            for (i, (label, tab)) in [
                ("БОЙ", game::Tab::Home),
                ("КАПСУЛЫ", game::Tab::Capsules),
                ("УЛУЧШ.", game::Tab::Upgrades),
                ("НАСТР.", game::Tab::Settings),
            ].into_iter().enumerate() {
                let active = game.tab == tab;
                let button = egui::Button::new(RichText::new(label).size(14.0).strong().color(Color32::WHITE))
                    .fill(if active { Color32::from_rgb(232, 149, 48) } else { Color32::from_rgb(47, 115, 191) })
                    .stroke(Stroke::new(2.0, gold))
                    .rounding(12.0)
                    .min_size(egui::vec2((width - 56.0) / 4.0, 66.0));
                if cols[i].add(button).clicked() { game.tab = tab; }
            }
        });
    });
    egui::CentralPanel::default().frame(egui::Frame::none().fill(Color32::TRANSPARENT)).show(ctx, |ui| {
        ui.vertical_centered(|ui| {
            ui.add_space((ui.available_height() * 0.25).max(15.0));
            match game.tab {
                game::Tab::Home => {
                    let (rect, response) = ui.allocate_exact_size(egui::vec2(button_size, button_size), egui::Sense::click());
                    let p = ui.painter();
                    let center = rect.center();
                    p.circle_filled(center + egui::vec2(0.0, 12.0), button_size * 0.48, Color32::from_rgb(118, 32, 59));
                    p.circle_filled(center, button_size * 0.46, Color32::from_rgb(255, 78, 100));
                    p.circle_filled(center - egui::vec2(button_size * 0.1, button_size * 0.16), button_size * 0.22, Color32::from_rgba_unmultiplied(255, 185, 191, 100));
                    p.text(center, egui::Align2::CENTER_CENTER, "АТАКА!", egui::FontId::proportional(38.0), Color32::WHITE);
                    if response.clicked() { game.tap(); }
                    ui.add_space(18.0);
                    ui.label(RichText::new("АТАКУЙ ВРАГОВ И ПОЛУЧАЙ МОНЕТЫ!").size(18.0).strong().color(Color32::WHITE));
                }
                game::Tab::Capsules => { ui.heading("3D КАПСУЛЫ"); ui.label("Скоро здесь появятся питомцы"); }
                game::Tab::Upgrades => {
                    ui.heading("УЛУЧШЕНИЯ");
                    ui.label(format!("Базовый доход: {:.0}/сек", game.base_income));
                    if ui.add(egui::Button::new(format!("УЛУЧШИТЬ — {:.0} монет", game.upgrade_price())).fill(gold).min_size(egui::vec2(width * 0.8, 64.0))).clicked() { game.upgrade(); }
                }
                game::Tab::Settings => { ui.heading("НАСТРОЙКИ"); ui.label("Clicker Mania — WolfCraft Engine"); }
            }
        });
    });
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.gfx.is_some() { return; }
        let window = self.window.get_or_insert_with(|| Arc::new(event_loop.create_window(
            Window::default_attributes().with_title("Clicker Mania").with_inner_size(winit::dpi::LogicalSize::new(420.0, 780.0))
        ).expect("window"))).clone();
        let gpu = GpuContext::new(window.clone(), true, false).expect("WolfCraft GPU");
        let egui = egui::Context::default();
        let state = egui_winit::State::new(egui.clone(), egui::ViewportId::ROOT, &window, Some(window.scale_factor() as f32), None, None);
        let renderer = egui_wgpu::Renderer::new(&gpu.device, gpu.config.format, None, 1, false);
        self.gfx = Some(Graphics { gpu, egui, state, renderer });
        self.last_tick = Some(Instant::now());
        window.request_redraw();
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _: WindowId, event: WindowEvent) {
        if matches!(event, WindowEvent::CloseRequested) { event_loop.exit(); return; }
        let Some(g) = self.gfx.as_mut() else { return };
        let response = g.state.on_window_event(&g.gpu.window, &event);
        match event {
            WindowEvent::Resized(size) => g.gpu.resize(size.width, size.height),
            WindowEvent::RedrawRequested => {
                let now = Instant::now();
                let dt = now.duration_since(self.last_tick.replace(now).unwrap_or(now)).as_secs_f64().min(0.25);
                self.game.tick(dt);
                let input = g.state.take_egui_input(&g.gpu.window);
                let output = g.egui.run(input, |ctx| ui(ctx, &mut self.game));
                g.state.handle_platform_output(&g.gpu.window, output.platform_output);
                let size = g.gpu.window.inner_size();
                if size.width == 0 || size.height == 0 { return; }
                let pixels_per_point = g.egui.pixels_per_point();
                let shapes = g.egui.tessellate(output.shapes, pixels_per_point);
                let descriptor = egui_wgpu::ScreenDescriptor { size_in_pixels: [size.width, size.height], pixels_per_point };
                for (id, delta) in &output.textures_delta.set {
                    g.renderer.update_texture(&g.gpu.device, &g.gpu.queue, *id, delta);
                }
                let Ok(frame) = g.gpu.surface.get_current_texture() else { g.gpu.resize(size.width, size.height); return; };
                let view = frame.texture.create_view(&wgpu::TextureViewDescriptor::default());
                let mut encoder = g.gpu.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: Some("button-sim") });
                g.renderer.update_buffers(&g.gpu.device, &g.gpu.queue, &mut encoder, &shapes, &descriptor);
                {
                    let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                        label: Some("button-sim-ui"),
                        color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                            view: &view, resolve_target: None,
                            ops: wgpu::Operations { load: wgpu::LoadOp::Clear(wgpu::Color { r: 0.1, g: 0.25, b: 0.45, a: 1.0 }), store: wgpu::StoreOp::Store },
                        })],
                        depth_stencil_attachment: None, timestamp_writes: None, occlusion_query_set: None,
                    });
                    g.renderer.render(&mut pass, &shapes, &descriptor);
                }
                g.gpu.queue.submit(Some(encoder.finish()));
                frame.present();
                for id in &output.textures_delta.free { g.renderer.free_texture(id); }
                g.gpu.window.request_redraw();
            }
            _ => { if response.repaint { g.gpu.window.request_redraw(); } }
        }
    }

    fn suspended(&mut self, _: &ActiveEventLoop) { self.gfx = None; }
}

pub fn run_desktop() {
    let event_loop = EventLoop::new().expect("event loop");
    let mut app = App::default();
    event_loop.run_app(&mut app).expect("application loop");
}

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
fn android_main(android_app: winit::platform::android::activity::AndroidApp) {
    use winit::{event_loop::EventLoopBuilder, platform::android::EventLoopBuilderExtAndroid};
    android_logger::init_once(android_logger::Config::default().with_max_level(log::LevelFilter::Info));
    let event_loop = EventLoopBuilder::default().with_android_app(android_app).build().expect("android event loop");
    let mut app = App::default();
    event_loop.run_app(&mut app).expect("application loop");
}
