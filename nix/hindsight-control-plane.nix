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
  nodejs_22,
  jq,
}:
buildNpmPackage {
  pname = "hindsight-control-plane";
  version = (lib.importJSON ../hindsight-control-plane/package.json).version or "0.0.0";

  src = ../.;

  nodejs = nodejs_22;

  nativeBuildInputs = [ jq ];

  # The lockfile has 2 entries that npm 11 lists without a `resolved` URL
  # because the *hoisted* top-level versions satisfy them:
  #   hindsight-docs/node_modules/typescript@5.6.3
  #   hindsight-control-plane/node_modules/@types/node@24.10.1
  # `npm install --offline` walks the whole lockfile to validate and tries
  # to resolve these stubs against the registry → ETARGET on typescript
  # 5.6.3.  Delete the stubs in prePatch so neither the prefetcher nor the
  # install ever sees them; the hoisted top-level versions (5.9.3 / 20.x)
  # do the right thing at module resolution time.
  # The lockfile has 2 entries that npm 11 lists *without* `resolved` URLs:
  #   hindsight-docs/node_modules/typescript@5.6.3
  #   hindsight-control-plane/node_modules/@types/node@24.10.1
  # These ARE load-bearing — the CP requires @types/node@^24.10.0 specifically
  # and the hoisted top-level versions (5.9.3 / 20.x) don't satisfy.  Populate
  # the missing resolved+integrity fields so prefetch can fetch them and the
  # `npm ci --offline` install in the build phase finds them in cache.
  #
  # Hashes obtained from `curl registry.npmjs.org/<pkg>/<version>`.
  # prePatch runs inside the npm-deps FOD too, which has a minimal build env
  # that does NOT inherit nativeBuildInputs. Reference jq by absolute store
  # path so the FOD can find it.
  prePatch = ''
    ${jq}/bin/jq '
      .packages["hindsight-docs/node_modules/typescript"] += {
        "resolved": "https://registry.npmjs.org/typescript/-/typescript-5.6.3.tgz",
        "integrity": "sha512-hjcS1mhfuyi4WW8IWtjP7brDrG2cuDZukyrYrSauoXGNgx0S7zceP07adYkJycEr56BOUTNPzbInooiN3fn1qw=="
      }
      | .packages["hindsight-control-plane/node_modules/@types/node"] += {
        "resolved": "https://registry.npmjs.org/@types/node/-/node-24.10.1.tgz",
        "integrity": "sha512-GNWcUTRBgIRJD5zj+Tq0fKOJ5XZajIiBroOF0yvj2bSU1WvNdYS/dn9UxwsujGW4JX06dnHyjV2y9rRaybH0iQ=="
      }
    ' package-lock.json > package-lock.json.patched
    mv package-lock.json.patched package-lock.json
  '';

  # Update when things change. First `nix build` will print the actual hash to substitute.
  npmDepsHash = "sha256-NR6oW5mtK9QbAcZGelDcecQeQen8ngKHJ+QOrx1lLXw=";
  #npmDepsHash = lib.fakeHash;

  # The top-level package.json has only `prepare`, which runs git hooks;
  # skipping avoids a git-in-sandbox failure.
  npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
  #npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" "--loglevel=verbose" ];

  # Requires cache update
  makeCacheWritable = true;

  # Use newer version for compatibility
  npmDepsFetcherVersion = 2;

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
