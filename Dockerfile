# ---- Builder Stage ----
# Use a specific Rust version for reproducibility. Update as needed.
# Using Debian Bookworm as the base OS for the builder.
FROM rust:1.85.1-bookworm AS builder

# Set the working directory
WORKDIR /usr/src/app

# Install necessary build dependencies if needed (e.g., for specific crates)
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     pkg-config openssl libssl-dev \
#     && rm -rf /var/lib/apt/lists/*;

# --- Caching Dependencies ---
# Create a dummy project to cache dependencies separately.
# This layer is invalidated only when Cargo.toml or Cargo.lock changes.
RUN cargo init --bin .
COPY Cargo.toml Cargo.lock ./

# Build *only* dependencies to cache them.
# This might fetch crates needed for tests/benches too, optimizing further
# might involve tools like `cargo-chef`.
RUN cargo build --release --locked
# Clean up the dummy src and target specific to the dummy build
RUN rm -f src/main.rs
RUN rm -rf target/release/deps/app* # Remove executable/libs specific to dummy build

# --- Building the Actual Application ---
# Copy your actual application source code
COPY src ./src

# If you have static assets, templates, or config files needed at *build time*,
# copy them here. Example:
# COPY static ./static
# COPY templates ./templates
# COPY config.toml ./

# Build the application executable, leveraging cached dependencies
# Force rebuild of only the local crate's code
RUN rm -rf target/
RUN cargo build --release --locked

# ---- Runtime Stage ----
# Use a minimal, secure base image. Distroless 'cc' contains glibc and other
# common libraries needed by dynamically linked Rust binaries (default).
FROM gcr.io/distroless/cc-debian12 AS runtime
# Alternatives:
# - debian:stable-slim : Small, but includes a shell and package manager.
# - gcr.io/distroless/static-debian12 : If you build with musl (static linking).

# Set the working directory
WORKDIR /app

# Copy the built application binary from the builder stage
# !!! IMPORTANT: Change 'my-axum-app' to your actual binary name !!!
COPY --from=builder /usr/src/app/target/release/docker-axum .

# Copy any runtime assets (static files, templates, default configs)
# needed by the application from the builder stage.
# Example: If your app serves static files from a 'static' directory:
# COPY --from=builder /usr/src/app/static ./static
# Example: If your app uses templates:
# COPY --from=builder /usr/src/app/templates ./templates

# Expose the port the application listens on
EXPOSE 3000

# Set the command to run the application
# !!! IMPORTANT: Change 'docker-axum' to your actual binary name !!!
CMD ["./docker-axum"]

# Optional: Healthcheck (adjust path and port as needed)
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s \
  CMD curl --fail http://localhost:3000/health || exit 1
