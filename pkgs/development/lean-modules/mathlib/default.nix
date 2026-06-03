{
  lib,
  buildLakePackage,
  runCommand,
  xz,
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
  leangz-raw = leangz.overrideAttrs { cargoBuildNoDefaultFeatures = true; };

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

    nativeBuildInputs = [
      leangz-raw
      xz
    ];

    # Compress the installed output so the derivation fits Hydra's
    # max_output_size. Per-module leantar packs oleans with lgz
    # structural preprocessing; xz compresses the entire output.
    # The user-facing mathlib derivation decompresses transparently,
    # at the de minimis compliance cost of nested compression.
    postInstall = ''
      local lib="$out/.lake/build/lib/lean"
      local ir="$out/.lake/build/ir"
      local base rel
      while IFS= read -r -d "" trace; do
        base="''${trace%.trace}"
        rel="''${base#"$lib"/}"
        leantar -C "$lib" -C "$ir" "$base.ltar" \
          "$rel.trace" "$rel.olean" "$rel.olean.server" "$rel.olean.private" \
          "$rel.ilean" -i 1 "$rel.c"
        rm "$base".{trace,olean,olean.server,olean.private,ilean} "$ir/$rel.c"
      done < <(find "$lib" -name '*.trace' -print0)
      tar cf - -C "$out" . | xz -9e -T1 > "$TMPDIR/archive.tar.xz"
      rm -rf "$out" && mkdir -p "$out"
      mv "$TMPDIR/archive.tar.xz" "$out/"
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
    nativeBuildInputs = [
      leangz-raw
      xz
    ];
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
    mkdir -p $out
    xz -dT0 < ${mathlib__archive}/archive.tar.xz | tar xf - -C $out
    find $out/.lake/build/lib -name '*.ltar' \
      -exec leantar -C $out/.lake/build/lib/lean -C $out/.lake/build/ir -x {} +
    find $out/.lake/build/lib -name '*.ltar' -delete
  ''
