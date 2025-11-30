import gg
import os

const default_window_width = 573//1280
const default_window_height = 337//720

struct App {
mut:
	gg          &gg.Context = unsafe { nil }
	ui          Ui
	theme       &Theme = themes[0]
	theme_idx   int
	updates     u64

	p          &os.Process = unsafe { nil }
	input      string
	text       string
	col 	   int
	shift_is_held bool
	dirty 	   bool
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
	app.ui.dpi_scale = s
	// do i have to match mac. i always spend forever doing it
	// i dont have to match their scaling. but i should match my scaling
	cw := app.gg.text_width("J")
	ch := app.gg.text_height("J")

	vw := int(f32(w) / s / cw)
	vh := int(f32(h) / s / ch)
	println('window resized to ${w}x${h}, view size ${vw}x${vh}, scale=${s}, cw=${cw}, ch=${ch}')

	app.ui.padding_size = 16 // int(m / 38)
	app.ui.header_size = app.ui.padding_size
	app.ui.border_size = app.ui.padding_size * 2
	app.ui.font_size = 18 //int(m / 10) // 54
	app.ui.window_height = h
	app.ui.window_width = w
}

fn (app &App) draw() {
	xpad, ypad := app.ui.x_padding, app.ui.y_padding
	labelx := xpad + app.ui.border_size
	labely := ypad + app.ui.border_size / 2

	for i, line in app.text.split('\n') {
		row := app.ui.font_size * i
		app.gg.draw_text(labelx, labely+row, line, gg.TextCfg{
			size: app.ui.font_size
			color: app.theme.text_color
		})
	}

	app.gg.draw_text(labelx, app.ui.window_height - labely - app.ui.font_size, app.input, gg.TextCfg{
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
				//
				.escape { app.gg.quit() }
				.n, .r { 
					println("double")
				}
				.t { app.next_theme() }
				.left_shift, .right_shift {
					app.shift_is_held = true
				}
				.enter {
					app.p.stdin_write("\n")
					app.text += "\n"
					app.input = ""
				}
				else {
					r := rune(e.key_code)
					c := if !app.shift_is_held && (r >= `A` && r <= `Z`) {
						(r + 32).str()
					} else {
						r.str()
					}
					app.input += c
					app.p.stdin_write(c)
				}
			}
			app.dirty = true
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
		if app.p.is_pending(.stdout) {
			data := app.p.stdout_read()
			app.text += data
			app.dirty = true
		}
		// app.p.wait()
	}
	// if !app.dirty {
	// 	return
	// }
	app.gg.begin()
	if do_update {
		// app.update_tickers()
	}
	app.draw()
	app.gg.end()
	app.dirty = false
}

fn init(mut app App) {
	app.resize()
}

fn main() {
	// TODO wrapper of fork+exec, but maybe use posix_spawn if this isnt good enough
	mut p := os.new_process("/bin/sh")
	// args := ['']
	// p.set_args(args)
	p.set_redirect_stdio()
	p.use_pgroup = true // i remember this being useful, but forgot why
	p.run()
	p.stdin_write("echo hello from v\n")

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
	app.p = p
	app.gg.run()
}
