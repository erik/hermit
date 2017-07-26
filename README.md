# Hermit

Piping command line output to the web.

``` bash

# No client needed! Pipe directly to netcat.
#
$ echo hello, world | nc hermit.server.tld 1337
Your pipe is available at http://hermit.server.tld/v/RNWG8Eua

# For ncurses apps, we can use tee with process substitution.
# Add a sleep command to get a chance to see the view URL.
#
$ (sleep 5; emacs -nw README.md) | tee >(nc hermit.server.tld 1337)
Your pipe is available at http://hermit.server.tld/v/XASdwked

# Can also use the seashells.io client (github.com/anishathalye/seashells)
$ htop | seashells -i hermit.server.tld -p 1337 -d 5
```

## Docker setup

``` bash

$ docker build -t hermit .
$ docker run -t -p 1337:1337 -p 8090:8090 hermit

# To set config values, specify environment variables with `-e`:
$ docker run -t -e HERMIT_HOST=example.com \
                -e HERMIT_SINK_PORT=1234   \
                hermit

# To mount the log directory outside of the docker (for inspection, log
# rotation, backup, ...)
$ docker run -t -v /path/to/local/dir:/hermit/logs hermit
```

## Native setup

First, install [elixir](https://elixir-lang.org/install.html) and erlang.

``` bash
# if you've never used mix / elixir before:
$ mix do local.hex, local.rebar

# by default, hermit will place log files here
$ mkdir /tmp/hermit

$ mix deps.get
$ MIX_ENV=prod mix compile
$ MIX_ENV=prod mix run --no-halt
```

## Configuration

Hermit is configured through environment variables, which are described in
[lib/hermit/Config.ex](https://github.com/erik/hermit/blob/master/lib/hermit/Config.ex).

Set them appropriately and rerun `MIX_ENV=prod mix run --no-halt`.

## Why

hermit is a from scratch implementation of [seashells.io](http://seashells.io),
designed to be self hosted, because the idea of seashells.io is
super cool, but the server [isn't open source](https://github.com/anishathalye/seashells/issues/2).

Also I wanted to play with elixir.
