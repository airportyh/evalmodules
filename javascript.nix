# A hello world for evalModules
{ pkgs }:
let

nodeVersions = ["20" "18"];
nodejsModule = { lib, config, ... }: with lib;
let cfg = config.javascript.nodejs;
availableVersions = mapAttrsToList (key: _: key) versionMap;
nodejs = pkgs.${"nodejs_${cfg.version}"};
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
      description = "Version of Node.js. Available versions are ${strings.concatStringsSep ", " nodeVersions}";
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

typescriptLanguageServerModule = { lib, config, ... }: with lib;
let
cfg = config.typescript-language-server;
nodejsCfg = config.javascript.nodejs;
nodejs = pkgs.${"nodejs_${nodejsCfg.version}"};
nodepkgs = pkgs.nodePackages.override {
  inherit nodejs;
};
# if nodejs module is enabled, uses that version of node to run the language server
ts-lang-server =
  if nodejsCfg.enabled then
    nodepkgs.typescript-language-server
  else
    pkgs.nodePackages.typescript-language-server;
in
{
  options.typescript-language-server = {
    enabled = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enabled {
    exePath = ["${ts-lang-server}/bin"];
  };
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

languageServerModule = { lib, ... }: with lib;
{
  options = {
    name = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The name of the language server.
      '';
    };

    language = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The language this language server supports.
      '';
    };

    extensions = mkOption {
      type = types.listOf (types.str);
      default = [ ];
      description = lib.mdDoc ''
        A list of file extensions this language server supports.
      '';
    };

    start = mkOption {
      type = commandType;
      description = lib.mdDoc ''
        The command to start the language server.
      '';
    };
  };
};

nodejsToolsBundleModule = { lib, config, ... }: with lib; {
  options = {
    bundles.nodejsTools.enabled = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.bundles.nodejsTools.enabled {
    javascript.nodejs.enabled = true;
    typescript-language-server.enabled = true;
    # along with other tools you want to include in this bundle
    # but if you want to configure individual tools within the bundle
    # you still specify the options within the tool specific sections
  };
};

bunToolsBundleModule = { lib, config, ... }: with lib; {
  options = {
    bundles.bunTools.enabled = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.bundles.bunTools.enabled {
    javascript.bun.enabled = true;
    typescript-language-server.enabled = true;
  };
};

toplevelModule = { lib, ... }: with lib; {
  imports = [
    javaScriptModule
    typescriptLanguageServerModule
    nodejsToolsBundleModule
    bunToolsBundleModule
  ];
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
  options.languageServers = mkOption {
    type = types.attrsOf (types.submodule languageServerModule);
    default = { };
    description = lib.mdDoc ''
      A set language servers provided by the module.
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

myConfig5 = { lib, ... }: {
  config.javascript.bun.enabled = true;
  config.javascript.nodejs.enabled = true;
  # having both nodejs and bun enabled is disallowed!
};

myConfig6 = { lib, ... }: {
  config.typescript-language-server.enabled = true;
};

myConfig7 = { lib, ... }: {
  config.javascript.nodejs.enabled = true;
  config.typescript-language-server.enabled = true;
};

myConfig8 = { lib, ... }: {
  config.bundles.bunTools.enabled = true;
};

myConfig9 = { lib, ... }: {
  config.bundles.nodejsTools.enabled = true;
};

configOutput = (pkgs.lib.evalModules {
    modules = [
      toplevelModule
      myConfig9
    ];
  }).config;
in
assert !(configOutput.javascript.bun.enabled && configOutput.javascript.nodejs.enabled);
builtins.toJSON configOutput