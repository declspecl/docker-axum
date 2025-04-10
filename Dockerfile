FROM public.ecr.aws/docker/library/rust:bookworm AS builder
WORKDIR /usr/src/app
RUN cargo init --bin .
COPY Cargo.toml Cargo.lock ./

RUN cargo build --release --locked
RUN rm -f src/main.rs
RUN rm -rf target/release/deps/app*

COPY src ./src
RUN rm -rf target/
RUN cargo build --release --locked

FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS runtime
WORKDIR /app
COPY --from=builder /usr/src/app/target/release/docker-axum .
EXPOSE 3000
CMD ["./docker-axum"]

# HEALTHCHECK --interval=15s --timeout=3s --start-period=5s \
#   CMD curl --fail http://localhost:3000/health || exit 1
