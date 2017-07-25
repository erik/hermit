FROM elixir:1.4

EXPOSE 1337
EXPOSE 8090

WORKDIR /hermit

ADD ./lib /hermit/lib
ADD ./web /hermit/web
ADD ./mix.exs ./mix.lock /hermit/

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN MIX_ENV=prod mix compile

CMD MIX_ENV=prod mix run --no-halt
