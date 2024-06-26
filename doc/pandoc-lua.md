---
title: pandoc-lua
section: 1
date: September 22, 2022
---

# SYNOPSIS

`pandoc-lua` [*options*] [*script* [*args*]]

# DESCRIPTION

`pandoc-lua` is a standalone Lua interpreter with behavior similar
to that of the standard `lua` executable, but exposing all of
pandoc's Lua libraries. All `pandoc.*` packages, as well as the
packages `re` and `lpeg`, are available via global variables.
Furthermore, the globals `PANDOC_VERSION`, `PANDOC_STATE`, and
`PANDOC_API_VERSION` are set at startup.

If no script argument is given, then the script is assumed to be
passed in via *stdin*. When called without arguments, `pandoc-lua`
behaves as `pandoc-lua -v -i` when the standard input (`stdin`) is
a terminal, and as `pandoc-lua -` otherwise. On Windows the
program will always behave as if it was connected to a terminal.

When called without the option `-E`, the interpreter checks for an
environment variable `LUA_INIT` before running any argument. If
the variable content has the format *`@filename`*, then
`pandoc-lua` executes the file. Otherwise, `pandoc-lua` executes
the string itself.

# OPTIONS

`-e stat`
:   Execute statement `stat`.

`-l mod`
:   If mod has the pattern `g=m`, then require library `m` into
    global `g`; otherwise require library `mod` into global
    `mod`.

`-v`
:   Show version information.

`-i`
:   Enter interactive mode after running *script*.

`-E`
:   Ignore environment variables. This is not fully implemented
    yet and only ignores the `LUA_INIT` variable. Other variables
    like `LUA_PATH` and `LUA_CPATH` are **not** ignored.

`-W`
:   Turn warnings on.

# INTERACTIVE MODE

In interactive mode, the Lua interpreter repeatedly prompts and
waits for a line. After reading a line, Lua first tries to
interpret the line as an expression. If it succeeds, it prints its
value. Otherwise, it interprets the line as a statement. If you
write an incomplete statement, the interpreter waits for its
completion by issuing a different prompt.

Exit the interactive mode by pressing `Ctrl-D` or `Ctrl-C`, or by
typing `os.exit()`. The *Isocline* library is used for line
editing. Press `F1` to get a list of available keybindings; the
`ctrl` key is abbreviated as `^` in that list.

# AUTHORS

Copyright 2023 John MacFarlane (jgm@berkeley.edu) and
contributors. Released under the [GPL], version 2 or later. This
software carries no warranty of any kind. (See COPYRIGHT for full
copyright and warranty notices.)

Lua: Copyright 1994-2023 Lua.org, PUC-Rio.

[GPL]: https://www.gnu.org/copyleft/gpl.html "GNU General Public License"

