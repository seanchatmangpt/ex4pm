# Multi-stage production Dockerfile for ex4pm Process Intelligence Control Plane
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20250224-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
COPY apps/ex4pm_core/mix.exs apps/ex4pm_core/
COPY apps/ex4pm_evidence/mix.exs apps/ex4pm_evidence/
COPY apps/ex4pm_engine/mix.exs apps/ex4pm_engine/
COPY apps/ex4pm_contracts/mix.exs apps/ex4pm_contracts/
COPY apps/ex4pm_runtime/mix.exs apps/ex4pm_runtime/
COPY apps/ex4pm_stream/mix.exs apps/ex4pm_stream/
COPY apps/ex4pm_domain/mix.exs apps/ex4pm_domain/
COPY apps/ex4pm/mix.exs apps/ex4pm/
COPY apps/ex4pm_cli/mix.exs apps/ex4pm_cli/
COPY apps/ex4pm_web/mix.exs apps/ex4pm_web/
COPY apps/ex4pm_qualification/mix.exs apps/ex4pm_qualification/

RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

COPY config config
COPY apps apps
COPY lib lib

RUN mix compile --warnings-as-errors
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl iproute2 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV="prod"
ENV PORT="8080"

WORKDIR "/app"
COPY --from=builder /app/_build/${MIX_ENV}/rel/ex4pm_umbrella ./
RUN chown -R nobody:root /app

USER nobody
EXPOSE 8080
CMD ["/app/bin/ex4pm_umbrella", "start"]
