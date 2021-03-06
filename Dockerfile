FROM elixir:1.4

EXPOSE 1337 8090

ENV HERMIT_DIR=/hermit/logs/
VOLUME /hermit/logs/

WORKDIR /hermit

RUN mix local.hex --force
RUN mix local.rebar --force

ADD ./mix.exs ./mix.lock /hermit/
RUN mix deps.get

ADD ./lib /hermit/lib
ADD ./web /hermit/web

RUN MIX_ENV=prod mix compile

CMD MIX_ENV=prod mix run --no-halt
