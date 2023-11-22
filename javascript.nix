# A hello world for evalModules
{ pkgs }:
let

nodejsModule = { lib, config, ... }: with lib;
let cfg = config.javascript.nodejs;
versionMap = {
  "20" = pkgs.nodejs_20;
  "18" = pkgs.nodejs_18;
};
availableVersions = mapAttrsToList (key: _: key) versionMap;
nodejs = versionMap.${cfg.version};
nodepkgs = pkgs.nodePackages.override {
  inherit nodejs;
};
in
  {
  options.javascript.nodejs = {
    enabled = mkOption {
      type = types.bool;
      default = false;
    };

    version = mkOption {
      type = types.str;
      default = "20";
      description = "Version of Node.js. Available versions are ${strings.concatStringsSep ", " availableVersions}";
    };

    packager = mkOption {
      type = types.str;
      default = "npm";
      description = "Node package manager to use. Available options: npm, yarn, and pnpm";
    };
  };

  config = mkIf cfg.enabled {
    exePath = [
      "${nodejs}/bin"
    ]
    ++ (if cfg.packager == "yarn" then ["${nodepkgs.yarn}/bin"] else [])
    ++ (if cfg.packager == "pnpm" then ["${nodepkgs.pnpm}/bin"] else []);

    upm.nodejs = {
      language = "nodejs-${cfg.packager}";
    };
  };
};

bunModule = { lib, config, ... }: with lib; {
  options.javascript.bun = {
    enabled = mkOption {
      type = types.bool;
      default = false;
    };

    version = mkOption {
      type = types.str;
      default = "1";
      description = "Version of Bun. Available versions are 0.6 and 1";
    };
  };

  config = mkIf config.javascript.bun.enabled {
    exePath = ["${pkgs.bun}/bin"];

    upm.bun = {
      language = "nodejs-bun";
    };
  };
};

javaScriptModule = { lib, config, ... }: with lib; 
{
  imports = [nodejsModule bunModule];
};

upmModule = { lib, ... }: with lib; {
  options = {
    language = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The upm language ID.
      '';
    };
  };
};

toplevelModule = { lib, ... }: with lib; {
  imports = [javaScriptModule];
  options.env = mkOption {
    type = types.attrsOf types.str;
    default = {};
  };
  options.exePath = mkOption {
    type = types.listOf types.str;
    default = [];
  };
  options.upm = mkOption {
    type = types.attrsOf (types.submodule upmModule);
    default = { };
    description = lib.mdDoc ''
      A set of packager configuration settings for UPM.
    '';
  };
};

myConfig = { lib, ... }: {
  config.env = {
    FOO = "BAR";
  };
  config.javascript.nodejs = {
    enabled = true;
    version = "18";
  };
};

myConfig2 = { lib, ... }: {
  config.javascript.nodejs = {
    enabled = true;
    version = "20";
    packager = "pnpm";
  };
};

myConfig3 = { lib, ... }: {
  config.javascript.nodejs = {
    enabled = true;
    version = "20";
    packager = "yarn";
  };
};

myConfig4 = { lib, ... }: {
  config.javascript.bun = {
    enabled = true;
  };
};

myBadConfig = { lib, ... }: {
  config.javascript.bun.enabled = true;
  config.javascript.nodejs.enabled = true;
};

configOutput = (pkgs.lib.evalModules {
    modules = [
      toplevelModule
      myConfig
    ];
  }).config;
in
assert !(configOutput.javascript.bun.enabled && configOutput.javascript.nodejs.enabled);
builtins.toJSON configOutput