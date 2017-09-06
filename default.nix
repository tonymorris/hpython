{ nixpkgs ? import <nixpkgs> { }, compiler ? "default" }:
let
  inherit (nixpkgs) pkgs;
  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  drv = haskellPackages.callPackage
    ./hpython.nix
    { tasty-hedgehog =
        import ./tasty-hedgehog.nix { inherit pkgs haskellPackages; };
    };

in

  drv.overrideAttrs (oldAttrs: oldAttrs // {
    buildInputs = oldAttrs.buildInputs ++ [ pkgs.python3 ];
  })
