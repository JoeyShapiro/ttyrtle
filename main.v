import gg
import math

const zooming_percent_per_frame = 5
const movement_percent_per_frame = 10

const window_title = 'Ttyrtle'
const default_window_width = 544
const default_window_height = 560

const predictions_per_move = 300
const prediction_depth = 8

struct App {
mut:
	gg          &gg.Context = unsafe { nil }
	ui          Ui
	theme       &Theme = themes[0]
	theme_idx   int
	moves       int
	updates     u64

	is_ai_mode bool
	ai_fpm     u64 = 8
	text       string
	shift_is_held bool
}

struct Ui {
mut:
	dpi_scale     f32
	tile_size     int
	border_size   int
	padding_size  int
	header_size   int
	font_size     int
	window_width  int
	window_height int
	x_padding     int
	y_padding     int
}

struct Theme {
	bg_color        gg.Color
	padding_color   gg.Color
	text_color      gg.Color
	game_over_color gg.Color
	victory_color   gg.Color
	tile_colors     []gg.Color
}

const themes = [
	&Theme{
		bg_color:        gg.rgb(250, 248, 239)
		padding_color:   gg.rgb(143, 130, 119)
		victory_color:   gg.rgb(100, 160, 100)
		game_over_color: gg.rgb(190, 50, 50)
		text_color:      gg.black
		tile_colors:     [
			gg.rgb(205, 193, 180), // Empty / 0 tile
			gg.rgb(238, 228, 218), // 2
			gg.rgb(237, 224, 200), // 4
			gg.rgb(242, 177, 121), // 8
			gg.rgb(245, 149, 99), // 16
			gg.rgb(246, 124, 95), // 32
			gg.rgb(246, 94, 59), // 64
			gg.rgb(237, 207, 114), // 128
			gg.rgb(237, 204, 97), // 256
			gg.rgb(237, 200, 80), // 512
			gg.rgb(237, 197, 63), // 1024
			gg.rgb(237, 194, 46),
		]
	},
	&Theme{
		bg_color:        gg.rgb(55, 55, 55)
		padding_color:   gg.rgb(68, 60, 59)
		victory_color:   gg.rgb(100, 160, 100)
		game_over_color: gg.rgb(190, 50, 50)
		text_color:      gg.white
		tile_colors:     [
			gg.rgb(123, 115, 108),
			gg.rgb(142, 136, 130),
			gg.rgb(142, 134, 120),
			gg.rgb(145, 106, 72),
			gg.rgb(147, 89, 59),
			gg.rgb(147, 74, 57),
			gg.rgb(147, 56, 35),
			gg.rgb(142, 124, 68),
			gg.rgb(142, 122, 58),
			gg.rgb(142, 120, 48),
			gg.rgb(142, 118, 37),
			gg.rgb(142, 116, 27),
		]
	},
]

@[inline]
fn (mut app App) set_theme(idx int) {
	theme := themes[idx]
	app.theme_idx = idx
	app.theme = theme
	app.gg.set_bg_color(theme.bg_color)
}

fn (mut app App) resize() {
	mut s := app.gg.scale
	if s == 0.0 {
		s = 1.0
	}
	window_size := app.gg.window_size()
	w := window_size.width
	h := window_size.height
	m := f32(math.min(w, h))
	app.ui.dpi_scale = s
	app.ui.window_width = w
	app.ui.window_height = h
	app.ui.padding_size = int(m / 38)
	app.ui.header_size = app.ui.padding_size
	app.ui.border_size = app.ui.padding_size * 2
	app.ui.tile_size = int((m - app.ui.padding_size * 5 - app.ui.border_size * 2) / 4)
	app.ui.font_size = int(m / 10)
	// If the window's height is greater than its width, center the board vertically.
	// If not, center it horizontally
	if w > h {
		app.ui.y_padding = 0
		app.ui.x_padding = (app.ui.window_width - app.ui.window_height) / 2
	} else {
		app.ui.y_padding = (app.ui.window_height - app.ui.window_width - app.ui.header_size) / 2
		app.ui.x_padding = 0
	}
}

fn (app &App) draw() {
	xpad, ypad := app.ui.x_padding, app.ui.y_padding
	labelx := xpad + app.ui.border_size
	labely := ypad + app.ui.border_size / 2
	app.gg.draw_text(labelx, labely, app.text, gg.TextCfg{
		size: app.ui.font_size
		color: app.theme.text_color
	})
}

@[inline]
fn (mut app App) next_theme() {
	app.set_theme(if app.theme_idx == themes.len - 1 { 0 } else { app.theme_idx + 1 })
}

fn on_event(e &gg.Event, mut app App) {
	match e.typ {
		.key_down {
			match e.key_code {
				.v { app.is_ai_mode = !app.is_ai_mode }
				.page_up { app.ai_fpm = dump(math.min(app.ai_fpm + 1, 60)) }
				.page_down { app.ai_fpm = dump(math.max(app.ai_fpm - 1, 1)) }
				//
				.escape { app.gg.quit() }
				.n, .r { 
					println("double")
				}
				.t { app.next_theme() }
				.left_shift, .right_shift {
					app.shift_is_held = true
				}
				else {
					c := rune(e.key_code)
					if !app.shift_is_held && (c >= `J` && c <= `Z`) {
						app.text += (c + 32).str()
					} else {
						app.text += rune(e.key_code).str()
					}
				}
			}
		}
		.key_up {
			match e.key_code {
				.left_shift, .right_shift {
					app.shift_is_held = false
				}
				else {}
			}
		}
		.resized, .restored, .resumed {
			app.resize()
		}
		.mouse_down {
			println("mouse down at ${e.mouse_x}, ${e.mouse_y}")
		}
		.mouse_up {
			println("mouse up at ${e.mouse_x}, ${e.mouse_y}")
		}
		else {}
	}
}

fn frame(mut app App) {
	mut do_update := false
	if app.gg.timer.elapsed().milliseconds() > 60 {
		app.gg.timer.restart()
		do_update = true
		app.updates++
	}
	app.gg.begin()
	if do_update {
		// app.update_tickers()
	}
	app.draw()
	app.gg.end()
}

fn init(mut app App) {
	app.resize()
}

fn main() {
	mut app := &App{}
	app.gg = gg.new_context(
		bg_color:     app.theme.bg_color
		width:        default_window_width
		height:       default_window_height
		sample_count: 2 // higher quality curves
		window_title: 'Ttyrtle'
		frame_fn:     frame
		event_fn:     on_event
		init_fn:      init
		user_data:    app
		font_path:    'JetBrainsMonoNerdFont-Regular.ttf'
	)
	app.gg.run()
}
