{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.phpfpm;

  stateDir = "/run/phpfpm";

  fpmCfgFile = pool: poolOpts: pkgs.writeText "phpfpm-${pool}.conf" ''
    [global]
    error_log = syslog
    daemonize = no
    ${cfg.extraConfig}

    [${pool}]
    listen = ${poolOpts.socket}
    ${poolOpts.extraConfig}
  '';

  phpIni = poolOpts: pkgs.runCommand "php.ini" {
    inherit (poolOpts) phpPackage phpOptions;
    preferLocalBuild = true;
    nixDefaults = ''
      sendmail_path = "/run/wrappers/bin/sendmail -t -i"
    '';
    passAsFile = [ "nixDefaults" "phpOptions" ];
  } ''
    cat $phpPackage/etc/php.ini $nixDefaultsPath $phpOptionsPath > $out
  '';

  poolOpts = { lib, name, ... }:
    let
      poolOpts = cfg.pools."${name}";
    in
    {
      options = {
        socket = mkOption {
          type = types.str;
          readOnly = true;
          description = ''
            Path to the unix socket file on which to accept FastCGI requests.
            <note><para>This option is read-only and managed by NixOS.</para></note>
          '';
        };

        listen = mkOption {
          type = types.str;
          default = "";
          example = "/path/to/unix/socket";
          description = ''
            The address on which to accept FastCGI requests.
          '';
        };

        phpPackage = mkOption {
          type = types.package;
          default = cfg.phpPackage;
          defaultText = "config.services.phpfpm.phpPackage";
          description = ''
            The PHP package to use for running this PHP-FPM pool.
          '';
        };

        phpOptions = mkOption {
          type = types.lines;
          default = cfg.phpOptions;
          defaultText = "config.services.phpfpm.phpOptions";
          description = ''
            "Options appended to the PHP configuration file <filename>php.ini</filename> used for this PHP-FPM pool."
          '';
        };

        extraConfig = mkOption {
          type = types.lines;
          example = ''
            user = nobody
            pm = dynamic
            pm.max_children = 75
            pm.start_servers = 10
            pm.min_spare_servers = 5
            pm.max_spare_servers = 20
            pm.max_requests = 500
          '';

          description = ''
            Extra lines that go into the pool configuration.
            See the documentation on <literal>php-fpm.conf</literal> for
            details on configuration directives.
          '';
        };
      };

      config = {
        socket = if poolOpts.listen == "" then "${stateDir}/${name}.sock" else poolOpts.listen;
      };
    };

in {

  options = {
    services.phpfpm = {
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra configuration that should be put in the global section of
          the PHP-FPM configuration file. Do not specify the options
          <literal>error_log</literal> or
          <literal>daemonize</literal> here, since they are generated by
          NixOS.
        '';
      };

      phpPackage = mkOption {
        type = types.package;
        default = pkgs.php;
        defaultText = "pkgs.php";
        description = ''
          The PHP package to use for running the PHP-FPM service.
        '';
      };

      phpOptions = mkOption {
        type = types.lines;
        default = "";
        example =
          ''
            date.timezone = "CET"
          '';
        description =
          "Options appended to the PHP configuration file <filename>php.ini</filename>.";
      };

      pools = mkOption {
        type = types.attrsOf (types.submodule poolOpts);
        default = {};
        example = literalExample ''
         {
           mypool = {
             phpPackage = pkgs.php;
             extraConfig = '''
               user = nobody
               pm = dynamic
               pm.max_children = 75
               pm.start_servers = 10
               pm.min_spare_servers = 5
               pm.max_spare_servers = 20
               pm.max_requests = 500
             ''';
           }
         }'';
        description = ''
          PHP-FPM pools. If no pools are defined, the PHP-FPM
          service is disabled.
        '';
      };
    };
  };

  config = mkIf (cfg.pools != {}) {

    warnings =
      mapAttrsToList (pool: poolOpts: ''
        Using config.services.phpfpm.pools.${pool}.listen is deprecated and will become unsupported. Please reference the read-only option config.services.phpfpm.pools.${pool}.socket to access the path of your socket.
      '') (filterAttrs (pool: poolOpts: poolOpts.listen != "") cfg.pools)
    ;

    systemd.slices.phpfpm = {
      description = "PHP FastCGI Process manager pools slice";
    };

    systemd.targets.phpfpm = {
      description = "PHP FastCGI Process manager pools target";
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services = mapAttrs' (pool: poolOpts:
      nameValuePair "phpfpm-${pool}" {
        description = "PHP FastCGI Process Manager service for pool ${pool}";
        after = [ "network.target" ];
        wantedBy = [ "phpfpm.target" ];
        partOf = [ "phpfpm.target" ];
        preStart = ''
          mkdir -p ${stateDir}
        '';
        serviceConfig = let
          cfgFile = fpmCfgFile pool poolOpts;
          iniFile = phpIni poolOpts;
        in {
          Slice = "phpfpm.slice";
          PrivateDevices = true;
          ProtectSystem = "full";
          ProtectHome = true;
          # XXX: We need AF_NETLINK to make the sendmail SUID binary from postfix work
          RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
          Type = "notify";
          ExecStart = "${poolOpts.phpPackage}/bin/php-fpm -y ${cfgFile} -c ${iniFile}";
          ExecReload = "${pkgs.coreutils}/bin/kill -USR2 $MAINPID";
        };
      }
    ) cfg.pools;
  };
}
