# Hindsight-API package — wraps the uv2nix-built venv into a stable
# /nix/store/.../bin/hindsight-* set.
#
# Entry points (from hindsight-api/pyproject.toml [project.scripts]):
#   hindsight-api         — the full Hindsight API server (host:8888)
#   hindsight-worker      — background worker
#   hindsight-local-mcp   — local MCP server entry point (what we use)
#   hindsight-admin       — admin CLI
{
  lib,
  stdenv,
  makeWrapper,
  callPackage,
  python312,

  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:
let
  hindsightVenv = callPackage ./python.nix {
    inherit uv2nix pyproject-nix pyproject-build-systems;
  };

  binaries = [
    "hindsight-api"
    "hindsight-worker"
    "hindsight-local-mcp"
    "hindsight-admin"
  ];
in
stdenv.mkDerivation {
  pname = "hindsight-api";
  version = (lib.importTOML ../hindsight-api/pyproject.toml).project.version;

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (name: ''
      makeWrapper ${hindsightVenv}/bin/${name} $out/bin/${name}
    '') binaries}
    runHook postInstall
  '';

  passthru = {
    inherit hindsightVenv;
  };

  meta = {
    description = "Hindsight — agent memory system";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = lib.licenses.asl20;
    mainProgram = "hindsight-local-mcp";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
