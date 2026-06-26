{
  description = "Hindsight — agent memory system (nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        { pkgs, lib, ... }:
        let
          hindsightApi = pkgs.callPackage ./nix/hindsight-api.nix {
            inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
          };
          hindsightControlPlane = pkgs.callPackage ./nix/hindsight-control-plane.nix { };
          hindsightCli = pkgs.callPackage ./nix/hindsight-cli.nix { };
        in
        {
          packages = {
            default = hindsightApi;
            hindsight-api = hindsightApi;
            hindsight-control-plane = hindsightControlPlane;
            hindsight-cli = hindsightCli;
          };
        };
    };
}
