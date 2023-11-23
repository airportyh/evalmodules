# A hello world for evalModules
{ pkgs }:
let

nodeVersions = ["20" "18"];
nodejsModule = { lib, config, ... }: with lib;
let cfg = config.nodejs;
availableVersions = mapAttrsToList (key: _: key) versionMap;
nodejs = pkgs.${"nodejs_${cfg.version}"};
nodepkgs = pkgs.nodePackages.override {
  inherit nodejs;
};
in
  {
  options.nodejs = {
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

    # this is not really an option, but a way to tag that this thing supports these languages
    languages = mkOption {
      type = types.listOf types.str;
      default = ["javascript" "typescript"];
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
  options.bun = {
    enabled = mkOption {
      type = types.bool;
      default = false;
    };

    version = mkOption {
      type = types.str;
      default = "1";
      description = "Version of Bun. Available versions are 0.6 and 1";
    };

    # this is not really an option, but a way to tag that this thing supports these languages
    languages = mkOption {
      type = types.listOf types.str;
      default = ["javascript" "typescript"];
    };
  };

  config = mkIf config.bun.enabled {
    exePath = ["${pkgs.bun}/bin"];

    upm.bun = {
      language = "nodejs-bun";
    };
  };
};

typescriptLanguageServerModule = { lib, config, ... }: with lib;
let
cfg = config.typescript-language-server;
defaultNodejsVersion = if config.nodejs.enabled then
  config.nodejs.version else "20";
nodejsVersion = cfg.nodejsVersion;
nodejs = pkgs.${"nodejs_${nodejsVersion}"};
nodepkgs = pkgs.nodePackages.override {
  inherit nodejs;
};
# if nodejs module is enabled, uses that version of node to run the language server
ts-lang-server = nodepkgs.typescript-language-server;
in
{
  options.typescript-language-server = {
    enabled = mkOption {
      type = types.bool;
      default = false;
    };
    nodejsVersion = mkOption {
      type = types.str;
      default = defaultNodejsVersion;
    };
  };

  config = mkIf cfg.enabled {
    exePath = ["${ts-lang-server}/bin"];

    languageServers.typescript-language-server = {
      name = "TypeScript Language Server";
      start = "${ts-lang-server}/bin/typescript-language-server";
      languages = ["javascript" "typescript"];
    };
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

    extensions = mkOption {
      type = types.listOf (types.str);
      default = [ ];
      description = lib.mdDoc ''
        A list of file extensions this language server supports.
      '';
    };

    start = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The command to start the language server.
      '';
    };

    languages = mkOption {
      type = types.listOf types.str;
      description = lib.mdDoc ''
      A set of languages this LSP supports.
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
    nodejs.enabled = true;
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
    bun.enabled = true;
    typescript-language-server.enabled = true;
  };
};

toplevelModule = { lib, ... }: with lib; {
  imports = [
    nodejsModule
    bunModule
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
  config.nodejs = {
    enabled = true;
    version = "18";
  };
};

myConfig2 = { lib, ... }: {
  config.nodejs = {
    enabled = true;
    version = "20";
    packager = "pnpm";
  };
};

myConfig3 = { lib, ... }: {
  config.nodejs = {
    enabled = true;
    version = "20";
    packager = "yarn";
  };
};

myConfig4 = { lib, ... }: {
  config.bun = {
    enabled = true;
  };
};

myConfig5 = { lib, ... }: {
  config.bun.enabled = true;
  config.nodejs.enabled = true;
  # having both nodejs and bun enabled is disallowed!
};

myConfig6 = { lib, ... }: {
  config.typescript-language-server.enabled = true;
};

myConfig7 = { lib, ... }: {
  # typescript language server will use the version of node that matches
  # the one in nodejsModule
  config.nodejs.enabled = true;
  config.typescript-language-server.enabled = true;

  config.nodejs.version = "18";
};

myConfig8 = { lib, ... }: {
  # but you can specify the version for both
  config.nodejs.enabled = true;
  config.typescript-language-server.enabled = true;

  config.nodejs.version = "18";
  config.typescript-language-server.nodejsVersion = "20";
};

myConfig9 = { lib, ... }: {
  config.bundles.bunTools.enabled = true;
};

myConfig10 = { lib, ... }: {
  config.bundles.nodejsTools.enabled = true;
};

myConfig11 = { lib, ... }: {
  config.bundles.nodejsTools.enabled = true;

  # You configure the individual tools provided by
  # a bundle directly. The bundle is not a wrapper
  config.nodejs = {
    version = "18";
    packager = "yarn";
  };
};

configOutput = (pkgs.lib.evalModules {
    modules = [
      toplevelModule
      myConfig11
    ];
  }).config;
in
assert !(configOutput.bun.enabled && configOutput.nodejs.enabled);
builtins.toJSON configOutput