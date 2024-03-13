{ config, options, lib, diskoLib, rootMountPoint, parent, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the dataset";
    };

    _name = lib.mkOption {
      type = lib.types.str;
      default = "${config._parent.name}/${config.name}";
      internal = true;
      description = "Fully quantified name for dataset";
    };

    type = lib.mkOption {
      type = lib.types.enum [ "zfs_fs" ];
      default = "zfs_fs";
      internal = true;
      description = "Type";
    };

    options = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Options to set for the dataset";
    };

    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Mount options";
    };

    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to mount the dataset to";
    };

    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };

    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = _dev: { };
      description = "Metadata";
    };

    _create = diskoLib.mkCreateOption {
      inherit config options;
      # -u prevents mounting newly created datasets, which is
      # important to prevent accidental shadowing of mount points
      # since (create order != mount order)
      # -p creates parents automatically
      default = ''
        if ! zfs get type ${config._name} >/dev/null 2>&1; then
          zfs create -up ${config._name} \
            ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)}
        fi
      '';
    } // { readOnly = false; };

    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        lib.optionalAttrs (config.options.mountpoint or "" != "none" && config.options.canmount or "" != "off") {
          fs.${config.mountpoint} = ''
            if ! findmnt ${config._name} "${rootMountPoint}${config.mountpoint}" >/dev/null 2>&1; then
              mount ${config._name} "${rootMountPoint}${config.mountpoint}" \
                -o X-mount.mkdir \
                ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
                ${lib.optionalString ((config.options.mountpoint or "") != "legacy") "-o zfsutil"} \
                -t zfs
            fi
          '';
        };
    };

    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        lib.optional (config.options.mountpoint or "" != "none" && config.options.canmount or "" != "off") {
          fileSystems.${config.mountpoint} = {
            device = "${config._name}";
            fsType = "zfs";
            options = config.mountOptions ++ lib.optional ((config.options.mountpoint or "") != "legacy") "zfsutil";
          };
        };
      description = "NixOS configuration";
    };

    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.util-linux ];
      description = "Packages";
    };
  };
}

