# syntax=docker/dockerfile:1
# Build from the repo root, the demo needs the library next to it:
#   docker build -f demo/Dockerfile .

ARG ELIXIR_IMAGE=docker.io/hexpm/elixir:1.20.4-erlang-29.1.2-debian-trixie-20261027-slim
ARG RUNNER_IMAGE=docker.io/library/debian:trixie-20261027-slim

FROM ${ELIXIR_IMAGE} AS build

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app
COPY mix.exs mix.lock ./
COPY demo/mix.exs demo/mix.lock demo/

WORKDIR /app/demo
RUN mix deps.get --only prod

COPY lib /app/lib
COPY demo/config config
COPY demo/lib lib
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 IP=0.0.0.0 PORT=4000
RUN useradd --system --create-home app
WORKDIR /app
COPY --from=build --chown=app /app/demo/_build/prod/rel/demo ./
USER app

EXPOSE 4000
CMD ["bin/demo", "start"]
