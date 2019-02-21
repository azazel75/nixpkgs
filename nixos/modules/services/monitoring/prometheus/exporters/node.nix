{ config, lib, pkgs }:

with lib;

baseCfg:
  let
    cfg = baseCfg.node;
  in
  {
    port = 9100;
    extraOpts = {
      enabledCollectors = mkOption {
        type = types.listOf types.string;
        default = [];
        example = ''[ "systemd" ]'';
        description = ''
          Collectors to enable. The collectors listed here are enabled in addition to the default ones.
        '';
      };
      disabledCollectors = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ''[ "timex" ]'';
        description = ''
          Collectors to disable which are enabled by default.
        '';
      };
    };
    serviceOpts = {
      serviceConfig = {
        RuntimeDirectory = "prometheus-node-exporter";
        ExecStart = ''
          ${pkgs.prometheus-node-exporter}/bin/node_exporter \
            ${concatMapStringsSep " " (x: "--collector." + x) cfg.enabledCollectors} \
            ${concatMapStringsSep " " (x: "--no-collector." + x) cfg.disabledCollectors} \
            --web.listen-address ${cfg.listenAddress}:${toString cfg.port} \
            ${concatStringsSep " \\\n  " cfg.extraFlags}
        '';
      };
    };
  }
