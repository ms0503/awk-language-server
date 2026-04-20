{
  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems = {
      flake = false;
      url = "github:nix-systems/default";
    };
  };
  outputs =
    inputs@{ flake-parts, systems, ... }:
    let
      depsHash = "sha256-wyP/i5MhUshSCenolK787kQDcvRcL/oGf7EmOhdwDtE=";
      version = "2026-04-21";
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      perSystem =
        { pkgs, ... }:
        {
          packages.default =
            let
              inherit (pkgs)
                coreutils
                findutils
                jq
                nodejs-slim_latest
                nodejsInstallExecutables
                nodejsInstallManuals
                python3Packages
                stdenv
                yarn-berry
                ;
              inherit (python3Packages) python;
              inherit (yarn-berry) fetchYarnBerryDeps yarnBerryConfigHook;
            in
            stdenv.mkDerivation (finalAttrs: {
              inherit version;
              buildPhase = ''
                runHook preBuild
                yarn build
                runHook postBuild
              '';
              installPhase = ''
                yarnInstallHook() {
                  echo "Executing yarnInstallHook"
                  runHook preInstall
                  local -r packageOut="$out/lib/node_modules/$(jq --raw-output '.name' ./package.json)"
                  mkdir -p "$packageOut"
                  local -r tmpDir="$(mktemp -d)"
                  mv ./package.json "$tmpDir/package.json.orig"
                  jq 'del(.bundleDependencies) | del(.bundledDependencies)' "$tmpDir/package.json.orig" > ./package.json
                  yarn pack --filename "$tmpDir/yarn-pack.tgz"
                  tar xzf "$tmpDir/yarn-pack.tgz" \
                    -C "$packageOut" \
                    --strip-components 1 \
                    package/
                  mv "$tmpDir/package.json.orig" ./package.json
                  nodejsInstallExecutables ./package.json
                  nodejsInstallManuals ./package.json
                  local -r nodeModulesPath="$packageOut/node_modules"
                  if [[ ! -d "$nodeModulesPath" ]]; then
                    if [[ -z "''${yarnKeepDevDeps-}" ]]; then
                      if ! yarn install \
                        --immutable \
                        --immutable-cache
                      then
                        echo
                        echo
                        echo "ERROR: yarn prune step failed"
                        echo
                        echo 'If yarn tried to download additional dependencies above, try setting `yarnKeepDevDeps = true`.'
                        echo
                        exit 1
                      fi
                    fi
                    find node_modules -maxdepth 1 -type d -empty -delete
                    cp -r node_modules "$nodeModulesPath"
                  fi
                  runHook postInstall
                  echo "Finished yarnInstallHook"
                }
                yarnInstallHook
              '';
              nativeBuildInputs = [
                coreutils
                findutils
                jq
                nodejs-slim_latest
                nodejsInstallExecutables
                nodejsInstallManuals
                python
                yarn-berry
                yarnBerryConfigHook
              ];
              offlineCache = fetchYarnBerryDeps {
                inherit (finalAttrs) src;
                hash = depsHash;
              };
              pname = "awk-language-server";
              src = ./server;
            });
        };
      systems = import systems;
    };
}
# vim: et sw=2
