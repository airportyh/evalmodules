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

    disabled = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf (!cfg.disabled) {
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

bunModule = { lib, config, ... }: with lib; 
let cfg = config.bun;
in {
  options.bun = {
    version = mkOption {
      type = types.str;
      default = "1";
      description = "Version of Bun. Available versions are 0.6 and 1";
    };

    disabled = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf (!cfg.disabled) {
    exePath = ["${pkgs.bun}/bin"];

    upm.bun = {
      language = "nodejs-bun";
    };
  };
};

typescriptLanguageServerModule = { lib, config, ... }: with lib;
let
cfg = config.typescript-language-server;
defaultNodejsVersion = if builtins.hasAttr "nodejs" config then
  config.nodejs.version else "20";
nodejsVersion = cfg.nodejsVersion;
nodejs = pkgs.${"nodejs_${nodejsVersion}"};
nodepkgs = pkgs.nodePackages.override {
  inherit nodejs;
};
ts-lang-server = nodepkgs.typescript-language-server;
in
{
  options.typescript-language-server = {
    nodejsVersion = mkOption {
      type = types.str;
      default = defaultNodejsVersion;
    };

    disabled = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf (!cfg.disabled) {
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
  imports = [nodejsModule typescriptLanguageServerModule];
};

bunToolsBundleModule = { lib, config, ... }: with lib; {
  imports = [bunModule typescriptLanguageServerModule];
};

toplevelModule = { lib, ... }: with lib; {
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

  imports = [nodejsModule];

  config.nodejs.version = "18";
};

myConfig2 = { lib, ... }: {

  imports = [nodejsModule];

  config.nodejs = {
    version = "20";
    packager = "pnpm";
  };

};

myConfig3 = { lib, ... }: {
  imports = [nodejsModule];

  config.nodejs = {
    version = "20";
    packager = "yarn";
  };
};

myConfig4 = { lib, ... }: {
  imports = [bunModule];
};

myConfig5 = { lib, ... }: {
  imports = [nodejsModule bunModule];
  # having both nodejs and bun enabled is disallowed!
};

myConfig6 = { lib, ... }: {
  imports = [typescriptLanguageServerModule];
};

myConfig7 = { lib, ... }: {
  # typescript language server will use the version of node that matches
  # the one in nodejsModule
  imports = [nodejsModule typescriptLanguageServerModule];

  config.nodejs.version = "18";
};

myConfig8 = { lib, ... }: with lib; {
  # but you can specify the version for both
  imports = [nodejsModule typescriptLanguageServerModule];

  config.nodejs.version = "18";
  config.typescript-language-server.nodejsVersion = "20";
};

myConfig9 = { lib, ... }: {
  imports = [bunToolsBundleModule];
};

myConfig10 = { lib, ... }: {
  imports = [nodejsToolsBundleModule];
};

myConfig11 = { lib, ... }: {
  imports = [nodejsToolsBundleModule];

  # You configure the individual tools provided by
  # a bundle directly. The bundle is not a wrapper
  config.nodejs = {
    version = "18";
    packager = "yarn";
  };
};

myConfig12 = { lib, ... }: {
  # you can disable individual things if the bundle gave you too much
  imports = [nodejsToolsBundleModule];

  config.typescript-language-server.disabled = true;
  config.nodejs.disabled = true;
};

configOutput = (pkgs.lib.evalModules {
    modules = [
      toplevelModule
      myConfig12
    ];
  }).config;
in
# TODO: prefer to put asserts at module level
assert !(
  (builtins.hasAttr "bun" configOutput) && 
  (builtins.hasAttr "nodejs" configOutput)
);
builtins.toJSON configOutput