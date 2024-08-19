{
  description = "WordPress FrankenPHP NixOS containers with multiple PHP versions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        mkWordPressImage = phpVersion: 
          import ./wordpress.nix { 
            inherit pkgs; 
            php = pkgs.${phpVersion};
            imageName = "wordpress-${phpVersion}";
          };
      in {
        packages = {
          wordpress-php81 = mkWordPressImage "php81";
          wordpress-php82 = mkWordPressImage "php82";
          wordpress-php83 = mkWordPressImage "php83";
          default = self.packages.${system}.wordpress-php82;
        };
      }
    );
}