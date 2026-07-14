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

  # mlx is an optional Apple-Silicon reranker backend (the `jina-mlx` code path
  # in hindsight_api.engine.jina_mlx_reranker), imported lazily and only when
  # that backend is explicitly selected.  The `local-ml` extra pulls it in with
  # the marker `sys_platform != 'win32'`, so it lands on Linux too — but the
  # Linux mlx wheel ships only `core.so` with a dangling `libmlx.so` reference
  # (the actual backend, mlx-metal, is darwin-only and has no Linux counterpart
  # in the lock).  auto-patchelf therefore hard-fails the wheel on Linux.
  #
  # Since the import is lazy and unused unless the jina-mlx reranker is chosen,
  # let the wheel install with the dangling ref on Linux instead of failing the
  # whole venv.  No-op on darwin, where mlx-metal satisfies libmlx.so normally.
  mlxLinuxFixup = final: prev:
    lib.optionalAttrs stdenv.hostPlatform.isLinux {
      mlx = prev.mlx.overrideAttrs (old: {
        autoPatchelfIgnoreMissingDeps =
          (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [ "libmlx.so" ];
      });
    };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python312;
    }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
        mlxLinuxFixup
      ]);
in
# Empty list = just hindsight-api's main `[project.dependencies]`, no extras,
# no PEP 735 dep-groups (hindsight-api defines none).  The `[all]` extra on
# the transitive hindsight-api-slim dep is picked up automatically via the
# workspace resolution.
pythonSet.mkVirtualEnv "hindsight-api-env" {
  hindsight-api = [ ];
}
