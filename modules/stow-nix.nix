{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = lib.filterAttrs (n: v: v.enable) config.programs.stow.users;

  userOptions =
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "Enable stow for ${name}";

        dotPath = lib.mkOption {
          type = lib.types.str;
          description = ''
            Path to the stow directory, e.g., "~/.dotfiles".
            "~/" will be expanded to the user's home directory.
          '';
          example = "~/.dotfiles";
        };

        backupSuffix = lib.mkOption {
          type = lib.types.str;
          default = "bak";
          description = "Suffix for backup files created by stow.";
        };

        group = lib.mkOption {
          default = { };
          description = ''
            Attribute set of packages to stow, where the value is a boolean.
            Example: { nvim = true; git = false; }
          '';
          example = "{ nvim = true; }";
          type = lib.types.attrsOf (lib.types.submodule (
            { name, ... }:
            {
              options = {
                enable = lib.mkEnableOption "${name} package to stow";
              };
            }
          ));
        };
      };
    };
in
{
  options.programs.stow = {
    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule userOptions);
      default = { };
      description = "Configure stow for each user.";
    };
  };

  config =
    lib.mergeAttrsList (
      lib.mapAttrsToList (
        userName: userCfg:
        let
          userHome = config.users.users.${userName}.home;
          enabledPackages = lib.attrNames (lib.filterAttrs (_: v: v) userCfg.group);
          resolvedDotPath =
            if lib.strings.hasPrefix "~/" userCfg.dotPath then
              userHome + (lib.strings.removePrefix "~/" userCfg.dotPath)
            else
              userCfg.dotPath;
          stowScript = pkgs.writeShellScript "apply-dotfiles-${userName}.sh" (
            builtins.readFile ./scripts/apply-dotfiles.sh
          );
        in
        {
          systemd.services."stow-nix-${userName}" = {
            description = "Apply stow dotfiles for user ${userName}";
            serviceConfig = {
              Type = "oneshot";
              User = userName;
              Group = config.users.users.${userName}.group;
              ExecStart = "${stowScript} ${userName} ${resolvedDotPath} ${userHome} ${userCfg.backupSuffix} ${lib.concatStringsSep " " enabledPackages}";
            };
          };

          system.activationScripts."stow-nix-trigger-${userName}" = {
            deps = [ "systemd-units" ];
            text = ''
              ${pkgs.systemd}/bin/systemctl start stow-nix-${userName}.service
            '';
          };
        }
      ) cfg
    )
    // {
      environment.systemPackages = lib.mkIf ((lib.length cfg) != 0) [ pkgs.stow ];
    };
}
