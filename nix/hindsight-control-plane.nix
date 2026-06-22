# Hindsight Control Plane — the Next.js admin UI that ships at :9999 in the
# upstream docker images.
#
# Built via buildNpmPackage from the top-level lockfile (npm workspaces).
# CP depends on the @vectorize-io/hindsight-client TypeScript SDK so we
# build that first.  The CP package's `build` script invokes `next build`
# then a `build:standalone` step that consolidates Next.js's nested
# standalone output into hindsight-control-plane/standalone/server.js.
{
  lib,
  buildNpmPackage,
  nodejs_20,
}:
buildNpmPackage {
  pname = "hindsight-control-plane";
  version = (lib.importJSON ../hindsight-control-plane/package.json).version or "0.0.0";

  src = ../.;

  nodejs = nodejs_20;

  # Placeholder — first `nix build` will print the actual hash to substitute.
  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  # The top-level package.json has only `prepare`, which runs git hooks;
  # skipping avoids a git-in-sandbox failure.
  npmFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild
    # Build the TypeScript SDK first (CP imports from it).
    npm run build -w @vectorize-io/hindsight-client
    # Build the CP — its `build` script runs `next build` then a custom
    # build:standalone step that flattens .next/standalone into
    # hindsight-control-plane/standalone/.
    npm run build -w hindsight-control-plane
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/hindsight-control-plane
    cp -r hindsight-control-plane/standalone/. $out/share/hindsight-control-plane/
    runHook postInstall
  '';

  passthru = {
    serverScript = "share/hindsight-control-plane/server.js";
  };

  meta = {
    description = "Hindsight Control Plane (Next.js admin UI)";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = lib.licenses.asl20;
    mainProgram = "node";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
