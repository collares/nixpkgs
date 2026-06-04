{
  lib,
  buildLakePackage,
  runCommand,
  leangz,
  fetchFromGitHub,
  batteries,
  aesop,
  Qq,
  proofwidgets,
  plausible,
  LeanSearchClient,
  importGraph,
  tests,
}:

let
  mathlib__archive = buildLakePackage (finalAttrs: {
    pname = "lean4-mathlib";
    # nixpkgs-update: no auto update
    version = "4.30.0";

    src = fetchFromGitHub {
      owner = "leanprover-community";
      repo = "mathlib4";
      tag = "v${finalAttrs.version}";
      hash = "sha256-RxOxdUiVUAxUbfVhxlkjmPX1V64EtmIIn1eW75TiJWA=";
    };

    leanPackageName = "mathlib";
    leanDeps = [
      batteries
      aesop
      Qq
      proofwidgets
      plausible
      LeanSearchClient
      importGraph
    ];

    nativeBuildInputs = [ leangz ];

    # Compress the installed output so the derivation fits Hydra's
    # max_output_size. Per-module leantar packs oleans with lgz
    # structural preprocessing and zstd compression.
    postInstall = ''
      local lib="$out/.lake/build/lib/lean"
      local ir="$out/.lake/build/ir"
      local base rel
      while IFS= read -r -d "" trace; do
        base="''${trace%.trace}"
        rel="''${base#"$lib"/}"
        leantar -C "$lib" -C "$ir" "$base.ltar" \
          "$rel".{trace,olean,olean.server,olean.private,ilean} \
          -i 1 "$rel.c"
        rm "$base".{olean,olean.server,olean.private,ilean}{,.hash}
        rm "$base".trace "$ir/$rel.c"
      done < <(find "$lib" -name '*.trace' -print0)
    '';

    meta = {
      description = "Mathematical library for Lean 4";
      homepage = "https://github.com/leanprover-community/mathlib4";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [ nadja-y ];
    };
  });
in

runCommand mathlib__archive.name
  {
    nativeBuildInputs = [ leangz ];
    passthru = {
      inherit mathlib__archive;
      inherit (mathlib__archive)
        src
        version
        lakePackageName
        lean4
        allLeanDeps
        computedLakeDeps
        overrideLakeDepsAttrs
        ;
      tests = {
        inherit (tests.lake) weak-minimax;
      };
    };
    meta = mathlib__archive.meta // {
      hydraPlatforms = [ ];
    };
  }
  ''
    cp -r ${mathlib__archive} $out
    chmod -R u+wX $out
    find $out/.lake/build/lib -name '*.ltar' \
      -exec leantar -C $out/.lake/build/lib/lean -C $out/.lake/build/ir -x {} +
    find $out/.lake/build/lib -name '*.ltar' -delete
  ''
