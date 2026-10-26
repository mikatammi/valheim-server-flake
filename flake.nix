{
  description = "NixOS module for the Valheim dedicated server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    steam-fetcher = {
      url = "github:nix-community/steam-fetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    steam-fetcher,
  }: let
    # The Steam Nix fetcher only supports x86_64 Linux.
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    # Repository tooling (formatter, update script) runs on any host.
    hostSystems = supportedSystems ++ ["aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forHostSystems = nixpkgs.lib.genAttrs hostSystems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [
          steam-fetcher.overlay
          self.overlays.default
        ];
      };
    lintersFor = system: let
      pkgs = pkgsFor system;
    in
      with pkgs; [
        alejandra
      ];
  in {
    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs;
          [
            nil # Nix LS
          ]
          ++ lintersFor system;
      };
    });

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      fmt = pkgs.runCommandLocal "alejandra" {} ''
        ${pkgs.alejandra}/bin/alejandra --check ${./.} > "$out"
      '';
      # Run after updating valheim-server: the new build must boot and
      # report the pinned version.
      server-boots = pkgs.testers.runNixOSTest (import ./nixos-tests/valheim.nix {inherit self;});
    });

    formatter = forHostSystems (system: let
      pkgs = pkgsFor system;
    in
      # `nix fmt` passes no arguments by default, and alejandra would then read stdin.
      pkgs.writeShellScriptBin "alejandra" ''
        exec ${nixpkgs.lib.getExe pkgs.alejandra} "''${@:-.}"
      '');

    nixosModules = rec {
      valheim = import ./nixos-modules/valheim.nix {inherit self steam-fetcher;};
      default = valheim;
    };
    overlays.default = final: prev: {
      valheim-server-unwrapped = final.callPackage ./pkgs/valheim-server {};
      valheim-server = final.callPackage ./pkgs/valheim-server/fhsenv.nix {};
      valheim-bepinex-pack = final.callPackage ./pkgs/bepinex-pack {};
      fetchValheimThunderstoreMod = final.callPackage ./pkgs/build-support/fetch-thunderstore-mod {};
    };
    packages = forHostSystems (system: let
      pkgs = pkgsFor system;
    in
      {
        # The update script only talks to Steam and Nix, so it runs on any host.
        update-valheim-server = pkgs.valheim-server-unwrapped.updateScript;
      }
      // nixpkgs.lib.optionalAttrs (builtins.elem system supportedSystems) {
        inherit (pkgs) valheim-server valheim-server-unwrapped;
      });
  };
}
