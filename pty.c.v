#include <util.h>
#include <termios.h>
#include <unistd.h>
#include <spawn.h>

#flag linux -lutil
#flag darwin -lutil

struct C.termios {
	// dummy
	c_iflag int
	c_oflag int
	c_cflag int
	c_lflag int
}

struct C.winsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

struct C.posix_spawn_file_actions_t {
	// dummy
}

struct C.posix_spawnattr_t {
	// dummy
}

fn C.openpty(amaster &int, aslave &int, name &char, termios &C.termios, winp &C.winsize) int
fn C.tcgetattr(fd int, termios &C.termios) int
fn C.tcsetattr(fd int, optional_actions int, termios &C.termios)
fn C.posix_spawn_file_actions_init(actions &C.posix_spawn_file_actions_t) int
fn C.posix_spawn_file_actions_adddup2(actions &C.posix_spawn_file_actions_t, fd int, newfd int) int
fn C.posix_spawn_file_actions_addclose(actions &C.posix_spawn_file_actions_t, fd int) int
fn C.posix_spawnattr_init(attr &C.posix_spawnattr_t) int
fn C.posix_spawnattr_setflags(attr &C.posix_spawnattr_t, flags int) int
