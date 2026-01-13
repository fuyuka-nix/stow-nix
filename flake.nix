{
  description = "stow-nix: Declarative dotfiles management using GNU Stow in NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = {
    nixpkgs,
    ...
  }:
  {
    inherit nixpkgs;

    withSystem = system: (import nixpkgs { inherit system; });

    nixosModules.default = ./modules/stow-nix.nix;
    # devShells.default = ./devShell.nix;
  };
}
