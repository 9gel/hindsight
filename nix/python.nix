# Build the hindsight-api workspace via uv2nix.
#
# uv2nix.loadWorkspace consumes the top-level pyproject.toml ([tool.uv.workspace])
# and uv.lock to resolve all members + transitive deps.  We materialize the
# `hindsight-api` workspace member into a sealed venv.
#
# Wheel preference: pg0-embedded ships a precompiled Postgres binary in its
# wheel.  Building from sdist is not feasible (it wraps the upstream Postgres
# build system).  On darwin, the wheel's macho binary uses system @rpath and
# /usr/lib/* resolution which "just works" without patchelf.  On Linux,
# patchelf would be needed — out of scope for this initial flake.
{
  python312,
  lib,
  callPackage,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  stdenv,
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./..; };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python312;
    }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
      ]);
in
# Empty list = just hindsight-api's main `[project.dependencies]`, no extras,
# no PEP 735 dep-groups (hindsight-api defines none).  The `[all]` extra on
# the transitive hindsight-api-slim dep is picked up automatically via the
# workspace resolution.
pythonSet.mkVirtualEnv "hindsight-api-env" {
  hindsight-api = [ ];
}
