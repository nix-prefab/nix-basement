{ config, lib, pkgs, ... }:
with builtins; with lib; {

  options.basement.healthchecks.providers.prometheus = with types; {
    enable = mkEnableOption "prometheus healthcheck provider";

    stateDir = mkOption {
      type = str;
      default = "/var/lib/healthchecks/prometheus";
    };

    address = mkOption {
      type = str;
      description = "Address to serve the prometheus exporter on (go format)";
      default = "127.0.0.1:9000";
    };

  };

  config =
    let
      cfg = config.basement.healthchecks.providers.prometheus;
    in
    mkIf (config.basement.healthchecks.enable && cfg.enable) {

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0777 1 1"
      ];

      basement.healthchecks.providerFunctions = [
        (service: up:
          pkgs.writeShellScript "prometheus-${service}-${if up then "up" else "down"}" ''
            echo "healthcheck_${service} ${if up then "1" else "0"} $(date +%s%3N)" > ${cfg.stateDir}/${service}
          ''
        )
      ];

      systemd.services.healthchecks-prometheus-exporter = {
        enable = true;
        script = toString (
          pkgs.stdenv.mkDerivation
            {
              name = "healthchecks-prometheus-exporter";
              src = pkgs.writeText "prometheus-exporter.go" ''
                package main

                import (
                  "fmt"
                  "net/http"
                  "io/ioutil"
                )

                func main() {
                  http.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
                    err := func() error {
                      files, err := ioutil.ReadDir("${cfg.stateDir}")
                      if err != nil {
                        return err
                      }

                      for _, file := range files {
                        text, err := ioutil.ReadFile("${cfg.stateDir}/" + file.Name())
                        if err != nil {
                          return err
                        }
                        fmt.Fprintln(w, string(text))
                      }
                      return nil
                    }()
                    if err != nil {
                      w.WriteHeader(http.StatusInternalServerError)
                      fmt.Println(err)
                    }
                  })


                  fmt.Println("Starting server on ${cfg.address}")
                  if err := http.ListenAndServe("${cfg.address}", nil); err != nil {
                    panic(err)
                  }
                }
              '';
              buildCommand = ''
                export HOME=$PWD
                ${pkgs.go}/bin/go build -o $out $src
              '';
            }
        );
        wantedBy = [ "multi-user.target" ];
      };

    };

}
