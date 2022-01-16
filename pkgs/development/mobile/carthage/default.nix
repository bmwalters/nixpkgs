{ stdenv, lib, fetchFromGitHub, linkFarm, writeText }:

let

  # based on pkgs/development/compilers/crystal/build-package.nix
  # and https://euandreh.xyz/swift2nix.git/tree/default.nix?id=676e8e49db192635f980b8d6828ad5fb1b512574
  # and pkgs/development/tools/swiftformat
  buildSwiftPackage = { packagesFile, swiftExecutables, ... }@args:
    let

      mkDerivationArgs = builtins.removeAttrs args [
        "packagesFile"
        "swiftExecutables"
      ];

      defaultOptions = [
        "--configuration release"
        "--disable-sandbox" # we use our own sandbox
        "--skip-update" # do not update remote deps
        "--verbose"
      ];

      resolvedDeps =
        let
          json = builtins.fromJSON (builtins.readFile packagesFile);
        in
          assert (json.version == 1);
          json.object.pins;

      swiftCheckouts =
        linkFarm
          "swift2nix-checkouts"
          (map
            ({ package, repositoryURL, state, ... }: {
              name = package;
              path = builtins.fetchGit {
                url = repositoryURL;
                rev = state.revision;
                ref = "HEAD";
              };
            })
            resolvedDeps);

      workspaceStateJson =
        let
          depToObject = { package, repositoryURL, state, ... }: {
            basedOn = null;
            packageRef = {
              identity = lib.toLower package;
              kind = "remote";
              location = repositoryURL;
              name = package;
            };
            state = {
              checkoutState = state;
              name = "checkout";
            };
            subpath = package;
          };

          workspaceState = {
            object = {
              artifacts = [];
              dependencies = map depToObject resolvedDeps;
            };
            version = 4;
          };
        in
          writeText "workspace-state.json" (builtins.toJSON workspaceState);

    in
      stdenv.mkDerivation (mkDerivationArgs // {
        # TODO: Dependency on pkgs.swift or note as impure like swiftformat?
        # TODO: Provide swift options via defaultOptions / options arg
        # TODO: Hooks, allow overriding phases, etc.
        # TODO: Explore solution of modifying Package.swift to point to local
        # paths rather than relying on .build directory implementation details.
        buildPhase = ''
          # Setup dependencies path to satisfy SwiftPM
          mkdir .build
          install -D -m 0664 ${workspaceStateJson} .build/workspace-state.json
          ln -s ${swiftCheckouts} .build/checkouts

          /usr/bin/swift build --configuration release --disable-sandbox --skip-update
        '';

        # TODO: Retrieve from Package.swift or something in .build?
        installPhase = lib.concatMapStrings (x: ''
          install -D -m 0555 ".build/release/"${lib.escapeShellArg x} "$out/bin/"${lib.escapeShellArg x}
        '') swiftExecutables;

        # TODO: Document.
        sandboxProfile = ''
          (allow file-read* file-write* process-exec mach-lookup)
          ; block homebrew dependencies
          (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
        '';
      });

in

buildSwiftPackage rec {
  pname = "carthage";
  version = "0.38.0";

  src = fetchFromGitHub {
    owner = "Carthage";
    repo = "Carthage";
    rev = version;
    sha256 = "sha256-0+rMk+iAShbPHjaTKIYdK3J4PT80jrF19YJIf+O6b9g=";
  };

  # Update by retrieving Package.resolved from upstream
  packagesFile = ./Package.resolved;
  swiftExecutables = [ "carthage" ];

  meta = with lib; {
    description = "A simple, decentralized dependency manager for Cocoa";
    homepage = "https://github.com/Carthage/Carthage";
    license = licenses.mit;
    maintainers = with maintainers; [ bmwalters ];
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
