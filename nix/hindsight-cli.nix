# Hindsight CLI — Rust binary built against the in-tree client crate.
#
# The CLI lives in hindsight-cli/ but depends on hindsight-clients/rust via a
# `path = "../hindsight-clients/rust"` dep, and that crate's build.rs reads
# hindsight-docs/static/openapi.json.  So the build needs the whole repo as
# source, not just hindsight-cli/.
{
  lib,
  rustPlatform,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage {
  pname = "hindsight-cli";
  version = (lib.importTOML ../hindsight-cli/Cargo.toml).package.version;

  src = ../.;

  # buildRustPackage cd's into this subdir for the build/test phases.  The
  # source tree is still unpacked at the top so the `path = "../..."` dep
  # resolves correctly.
  buildAndTestSubdir = "hindsight-cli";

  # Cargo.lock lives in hindsight-cli/, not at the repo root.  `cargoRoot`
  # tells the vendor-setup hook where to look for and write back Cargo.lock.
  cargoRoot = "hindsight-cli";

  cargoLock = {
    lockFile = ../hindsight-cli/Cargo.lock;
  };

  nativeBuildInputs = [ pkg-config ];

  # reqwest pulls in native-tls → openssl-sys on Linux; on darwin native-tls
  # uses Security.framework (now auto-linked by stdenv in recent nixpkgs, so
  # no explicit framework inputs needed).
  buildInputs = [ openssl ];

  # The integration tests in hindsight-cli/tests/ require a running API and
  # network — skip in the sandbox.
  doCheck = false;

  meta = {
    description = "Hindsight CLI — semantic memory system";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = lib.licenses.mit;
    mainProgram = "hindsight";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
