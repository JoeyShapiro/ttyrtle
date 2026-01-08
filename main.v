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

	p          &PsuedoTerminal = unsafe { nil }
	input      string
	commands     []Command
	max_rows 	   int
	total_rows   int
	screen_rows int
	cur_row int
	scroll_offset f32
	shift_is_held bool
	dirty 	   bool
}

struct Command {
	input  string
mut:
	stdios []Stdio
	code   int
}

struct Stdio {
	std_type  StdType
	text string
}

enum StdType {
	stdin
	stdout
	stderr
}

struct Ui {
mut:
	dpi_scale     f32
	tile_size     int
	border_size   int
	font_size     int
	window_width  int
	window_height int
	x_padding     int
	y_padding     int
	scrollable_area int
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

	app.ui.border_size = 16 // int(m / 38)
	app.ui.font_size = 18 //int(m / 10) // 54
	app.ui.x_padding = 0
	app.ui.y_padding = 0
	app.ui.window_height = h
	app.ui.window_width = w
	input_size := app.ui.font_size
	app.ui.scrollable_area = app.ui.window_height - (app.ui.border_size*2 + app.ui.y_padding*2 + input_size)

	app.screen_rows = ((app.ui.window_height-2 * (app.ui.y_padding + app.ui.border_size)) / app.ui.font_size)-1
}

fn (app &App) draw() {
	start_x := app.ui.x_padding + app.ui.border_size
	start_y := app.ui.y_padding + app.ui.border_size
	mut row_cur := 0
	row_offset := int(app.scroll_offset / app.ui.font_size)

	// draw from the bottom up
	// TODO i will need total_rows for handling multi line everything. so might as well use that somehow
	//      but i am getting ahead of myself
output:
	for i := app.commands.len-1; i >= 0; i-- {
		cmd := app.commands[i]

		for stdio in cmd.stdios {
			lines := stdio.text.split('\n')
			for j := lines.len - 1; j >= 0; j-- {
				line := lines[j]
				// i cant just follow newlines. i have to start a new line for the next input
				// TODO maybe add notice like zsh with %
				if line == '' && j == lines.len - 1 {
					continue
				}

				if row_cur < row_offset {
					row_cur++
					continue
				}
				row := app.screen_rows - row_cur + row_offset
				app.gg.draw_text(start_x, start_y+row*app.ui.font_size, line, gg.TextCfg{
					size: app.ui.font_size
					color: match stdio.std_type {
						.stdout { app.theme.text_color }
						.stderr { gg.red }
						else { gg.gray }
					}
				})
				row_cur++
				if row_cur-row_offset >= app.screen_rows+1 {
					break output
				}
			}

			if row_cur < row_offset {
				row_cur++
				continue
			}
			row := app.screen_rows - row_cur + row_offset
			app.gg.draw_text(start_x, start_y+row*app.ui.font_size, cmd.input, gg.TextCfg{
				size: app.ui.font_size
				color: app.theme.padding_color
			})
			row_cur++
			if row_cur-row_offset >= app.screen_rows+1 {
				break output
			}
		}
	}

	// draw thumb scroll bar
	if app.total_rows > app.screen_rows {
		// TODO use scrollable area
		thumb_h := f32(app.screen_rows) / f32(app.total_rows) * f32(app.ui.window_height)
		inv_thumb_pos := f32(row_offset) / f32(app.total_rows - app.screen_rows) * f32(app.ui.window_height - thumb_h)
		thumb_pos := f32(app.ui.window_height) - inv_thumb_pos - thumb_h
		app.gg.draw_rect_filled(app.ui.window_width-10, thumb_pos, 5, thumb_h, app.theme.padding_color)
		// TODO maybe make this count towards the collision
		app.gg.draw_circle_filled(f32(app.ui.window_width)-7.5, thumb_pos, 2.5, app.theme.padding_color)
		app.gg.draw_circle_filled(f32(app.ui.window_width)-7.5, thumb_pos+thumb_h, 2.5, app.theme.padding_color)
	}

	app.gg.draw_text(start_x, app.ui.window_height - start_y - app.ui.font_size, "$ "+app.input, gg.TextCfg{
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
				.escape { app.gg.quit() }
				// .n, .r { 
				// 	println("double")
				// }
				// .t { app.next_theme() }
				.left_shift, .right_shift {
					app.shift_is_held = true
				}
				.enter {
					app.total_rows += app.input.count('\n')+1
					app.commands << Command{
						input: app.input
					}
					app.p.stdin_write("\n")
					app.input = ""
				}
				.backspace {
					if app.input.len > 0 {
						app.input = app.input[..app.input.len - 1]
						app.p.stdin_write("\x7f") // DEL
					}
				}
				else {
					r := rune(e.key_code)
					c := if !app.shift_is_held && (r >= `A` && r <= `Z`) {
						(r + 32).str()
					} else if app.shift_is_held && (r <= `A` || r >= `Z`) {
						match r {
							'~'.runes()[0] { "~" }
							`1` { "!" }
							`2` { "@" }
							`3` { "#" }
							`4` { "$" }
							`5` { "%" }
							`6` { "^" }
							`7` { "&" }
							`8` { "*" }
							`9` { "(" }
							`0` { ")" }
							`-` { "_" }
							`=` { "+" }
							`[` { "{" }
							`]` { "}" }
							`\\` { "|" }
							`;` { ":" }
							`'` { "\"" }
							`,` { "<" }
							`.` { ">" }
							`/` { "?" }
							else { r.str() }
						}
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
		.mouse_scroll {
			app.scroll_offset += e.scroll_y // * 10 // scroll speed

			if app.scroll_offset < 0 {
				app.scroll_offset = 0
			}

			scroll_range_max := app.total_rows*app.ui.font_size - app.ui.scrollable_area
			if app.scroll_offset > scroll_range_max {
				app.scroll_offset = if scroll_range_max < 0 {
					0
				} else {
					scroll_range_max
				}
			}
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
		// could do this in a different thread with blocking and non-blocking reads
		// but this seems much better
		if app.p.is_pending(.stdout) {
			data := app.p.stdout_read()
			app.total_rows += data.count('\n')
			app.commands[app.commands.len - 1].stdios << Stdio{
				std_type: .stdout
				text: data
			}
			app.dirty = true
		}
		if app.p.is_pending(.stderr) {
			data := app.p.stderr_read()
			app.total_rows += data.count('\n')
			app.commands[app.commands.len - 1].stdios << Stdio{
				std_type: .stderr
				text: data
			}
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
	mut termios := C.termios{}
	termios.c_iflag = (C.ICRNL | C.IXON | C.IXANY | C.IMAXBEL | C.BRKINT | C.IUTF8)
	termios.c_oflag = (C.OPOST | C.ONLCR)
	termios.c_cflag = (C.CREAD | C.CS8 | C.HUPCL)
	termios.c_lflag = (C.ICANON | C.ISIG | C.IEXTEN | C.ECHO | C.ECHOE | C.ECHOK | C.ECHOKE | C.ECHOCTL)

	mut winsize := C.winsize{
		ws_row:    24
		ws_col:    80
		ws_xpixel: 0
		ws_ypixel: 0
	}
	mut master_fd := 0
	mut slave_fd := 0
	mut cname := []char{len: 1024}
	r  := C.openpty(&master_fd, &slave_fd, cname.data, &termios, &winsize)
	if r != 0 {
		eprintln('failed to open pty $r')
		return
	}

	name := unsafe { cstring_to_vstring(cname.data) }
	println('parent, master ${master_fd} slave ${slave_fd}, ${name}')

	C.tcgetattr(master_fd, &termios)
	C.tcsetattr(master_fd, C.TCSAFLUSH, &termios)
	

	// TODO child has to do this anyway. it seems
	// TODO wrapper of fork+exec, but maybe use posix_spawn if this isnt good enough
	mut p := os.new_process("/bin/sh")
	mut pty := PsuedoTerminal(*p)
	
	// args := ['']
	// p.set_args(args)
	pty.set_redirect_stdio()
	pty.use_pgroup = true // i remember this being useful, but forgot why
	pty.run_pty(master_fd, slave_fd)

	mut app := &App{}
	app.gg = gg.new_context(
		bg_color:     app.theme.bg_color
		width:        default_window_width
		height:       default_window_height
		sample_count: 2 // higher quality curves
		window_title: 'ttyrtle'
		frame_fn:     frame
		event_fn:     on_event
		init_fn:      init
		user_data:    app
		font_path:    'JetBrainsMonoNerdFont-Regular.ttf'
		// font_path: 'Monocraft.ttf'
	)

	app.total_rows = 1
	app.commands << Command{
		input: "echo hello from v"
	}
	pty.stdin_write("echo hello from v\n")

	app.p = &pty
	app.max_rows = 1000
	app.gg.run()
}

type PsuedoTerminal = os.Process

pub fn (mut pty PsuedoTerminal) run_pty(master_fd int, slave_fd int) {
	if pty.status != .not_started {
		return
	}
	pty.spawn_pty(master_fd, slave_fd)
}

fn (mut pty PsuedoTerminal) spawn_pty(master int, slave int) int {
	if !pty.env_is_custom {
		pty.env = []string{}
		current_environment := os.environ()
		for k, v in current_environment {
			pty.env << '${k}=${v}'
		}
	}
	mut pid := 0
	$if windows {
		// TODO add windows
		pid = pty.win_spawn_process()
	} $else {
		// TODO switch to posix_spawn
		pid = pty.unix_spawn_pty(master, slave)
	}
	pty.pid = pid
	pty.status = .running

	return 0
}

fn (mut pty PsuedoTerminal) posix_spawn_pty(master int, slave int) int {
	// TODO add pipes
	mut actions := unsafe { &C.posix_spawn_file_actions_t(malloc(256)) }
	defer { unsafe { free(actions) } }

	C.posix_spawn_file_actions_init(actions)
	
	C.posix_spawn_file_actions_adddup2(actions, slave, C.STDIN_FILENO)
	C.posix_spawn_file_actions_adddup2(actions, slave, C.STDOUT_FILENO)
	C.posix_spawn_file_actions_adddup2(actions, slave, C.STDERR_FILENO)
	C.posix_spawn_file_actions_addclose(actions, master)

	mut spawn_attr := unsafe { &C.posix_spawnattr_t(malloc(256)) }
	defer { unsafe { free(spawn_attr) } }
	C.posix_spawnattr_init(spawn_attr)

	flags := C.POSIX_SPAWN_SETSID
	mut rc := C.posix_spawnattr_setflags(spawn_attr, flags)
	if rc != 0 {
		println("attr failed")
	}

	mut env_ptrs := []&char{cap: pty.env.len + 1}
    for env_var in pty.env {
        env_ptrs << env_var.str
    }
    env_ptrs << '\0'.str  // NULL terminator

	mut pid := 0
	rc = C.posix_spawn(&pid, pty.filename.str,actions, spawn_attr, 0, &char(env_ptrs.data))
	if rc != 0 {
		println(unsafe { cstring_to_vstring(C.strerror(rc)) })
		return 0
	}

	pty.stdio_fd[0] = master // store the write end of child's in
	pty.stdio_fd[1] = master // store the read end of child's out
	pty.stdio_fd[2] = master // store the read end of child's err

	return pid
}


fn (mut pty PsuedoTerminal) unix_spawn_pty(master int, slave int) int {
	pid := os.fork()
	if pid != 0 {
		// This is the parent process after the fork.
		// Note: pid contains the process ID of the child process
		if pty.use_stdio_ctl {
			pty.stdio_fd[0] = master // store the write end of child's in
			pty.stdio_fd[1] = master // store the read end of child's out
			pty.stdio_fd[2] = master // store the read end of child's err
			// close the rest of the pipe fds, the parent does not need them
			os.fd_close(slave)
		}
		return pid
	}
	//
	// Here, we are in the child process.
	// It still shares file descriptors with the parent process,
	// but it is otherwise independent and can do stuff *without*
	// affecting the parent process.
	//
	if pty.use_pgroup {
		C.setpgid(0, 0)
	}
	if pty.use_stdio_ctl {
		// Redirect the child standard in/out/err to the pipes that
		// were created in the parent.
		// Close the parent's pipe fds, the child do not need them:
		os.fd_close(master)
		// redirect the pipe fds to the child's in/out/err fds:
		C.dup2(slave, 0)
		C.dup2(slave, 1)
		C.dup2(slave, 2)
		// close the pipe fdsx after the redirection
		os.fd_close(slave)
	}
	if pty.work_folder != '' {
		if !os.is_abs_path(pty.filename) {
			// Ensure p.filename contains an absolute path, so it
			// can be located reliably, even after changing the
			// current folder in the child process:
			pty.filename = os.abs_path(pty.filename)
		}
		os.chdir(pty.work_folder) or {}
	}
	os.execve(pty.filename, pty.args, pty.env) or {
		eprintln(err)
		exit(1)
	}
	return 0
}
