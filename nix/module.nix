# `programs.texturecraft` for NixOS and home-manager.
#
# The option set is shared; `kind` selects only the behaviour the target module system can express:
# home-manager sets the palette variable per user, NixOS installs the package and the MIME default
# for the whole system.
#
# There is deliberately no `settings` option in this branch. TextureCraft keeps its preferences in
# eframe's RON storage (`~/.local/share/texturecraft/app.ron`), not in a JSON file, so there is
# nothing the shared `craft-settings` overlay can merge. A declarative settings overlay needs a
# JSON preferences file in the application first; until then, configure TextureCraft in the app.
{ kind }:
{
  config,
  lib,
  pkgs,
  # The package of this flake; `flake.nix` passes it through `_module.args`, so importing the
  # module directly needs no overlay.
  texturecraftPackage ? pkgs.texturecraft,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.texturecraft;

  # The same list as `packaging/linux/ai.storyteller.texturecraft.desktop` (`MimeType=`).
  mimeTypes = [
    "application/x-texturecraft"
    "model/gltf-binary"
    "model/gltf+json"
    "model/x-fbx"
    "model/vnd.collada+xml"
    "model/x-usd"
    "model/vnd.usda"
    "model/vnd.usdz+zip"
    "model/x-alembic"
    "model/obj"
    "model/x-ply"
    "model/stl"
  ];

  desktopFile = "ai.storyteller.texturecraft.desktop";

  associations = lib.genAttrs mimeTypes (_: [ desktopFile ]);
in
{
  options.programs.texturecraft = {
    enable = mkEnableOption "TextureCraft";

    package = mkOption {
      type = types.package;
      default = texturecraftPackage;
      defaultText = lib.literalMD "the `texturecraft` package of this flake";
      description = "The TextureCraft package to install.";
    };

    setAsDefault = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open `.tcraft` projects and the mesh formats TextureCraft reads with TextureCraft by default
        (the MIME types of `packaging/linux/ai.storyteller.texturecraft.desktop`).
      '';
    };

    paletteFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional shared palette file, exported as `CRAFT_PALETTE_FILE`. Inert until theming support
        lands.
      '';
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.enable (
      if kind == "nixos" then
        {
          environment.systemPackages = [ cfg.package ];
          environment.sessionVariables = mkIf (cfg.paletteFile != null) {
            CRAFT_PALETTE_FILE = toString cfg.paletteFile;
          };
          xdg.mime.defaultApplications = mkIf cfg.setAsDefault associations;
        }
      else
        {
          home.packages = [ cfg.package ];
          home.sessionVariables = mkIf (cfg.paletteFile != null) {
            CRAFT_PALETTE_FILE = toString cfg.paletteFile;
          };
          xdg.mimeApps = mkIf cfg.setAsDefault {
            enable = true;
            defaultApplications = associations;
            # Associated even when another application stays the default.
            associations.added = associations;
          };
        }
    ))
  ];
}
