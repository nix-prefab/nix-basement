{ config, pkgs, lib, ... }:
with builtins; with lib; {

  options.basement.services.k3s = with types; {
    enable = mkEnableOption "customized k3s module";
    nodeIp = mkOption {
      type = str;
      description = "IP that this machine can be reached on by other nodes";
    };
    dns = {
      nameservers = mkOption {
        type = listOf str;
        description = "IPs of the upstream DNS server for CoreDNS";
        default = [ "8.8.8.8" "8.8.4.4" ];
      };
      searchPath = mkOption {
        type = str;
        description = "Upstream DNS search path";
        default = "";
      };
    };
    maxPods = mkOption {
      type = int;
      description = "Maximum number of pods that can be run on this node";
      default = 110;
    };
    role = mkOption {
      type = enum [ "server" "agent" ];
      default = "server";
      description = "Role of this node. Either server or agent";
    };
    docker = mkOption {
      type = bool;
      description = "Whether to use docker instead of containerd";
      default = false;
    };
    serverAddr = mkOption {
      type = str;
      description = "IP of the k3s server to connect to (agent only)";
    };
    extraFlags = mkOption {
      type = listOf str;
      description = "Additional flags to pass to k3s";
      default = [ ];
    };
    clusterCIDR = mkOption {
      type = str;
      description = "IP range for pods in the cluster";
      default = "10.12.0.0/16";
    };
    serviceCIDR = mkOption {
      type = str;
      description = "IP range for services in the cluster";
      default = "10.13.0.0/16";
    };
    clusterDNS = mkOption {
      type = str;
      description = "IP of the CoreDNS service (must be within serviceCIDR)";
      default = "10.13.0.10";
    };
  };

  config =
    let
      cfg = config.services.k3s // config.basement.services.k3s;
      resolvConf = pkgs.writeText " resolv.conf " ''
        ${optionalString (cfg.dns.searchPath != "") "search ${cfg.dns.searchPath}"}
        ${concatStringsSep "\n"
          (map (ip: "nameserver ${ip}") cfg.dns.nameservers)
        }
      '';
    in
    mkIf cfg.enable {

      services.k3s = {
        enable = true;
        inherit (cfg) role docker;
      };

      systemd.services.k3s.serviceConfig.ExecStart =
        let
          options = concatStringsSep " " (
            (optional cfg.docker "--docker ")
            ++
            [
              "--node-ip=${cfg.nodeIp}"
              "--node-external-ip=${cfg.nodeIp}"
              "--snapshotter=fuse-overlayfs" # overlay snapshotter does not work on NixOS, native produces large amount of data
              "--resolv-conf=${resolvConf}"
              "--kubelet-arg=--max-pods=${toString cfg.maxPods}"
            ]
            ++
            (if cfg.role == "server" then [
              "--disable=traefik"
              "--cluster-cidr=${cfg.clusterCIDR}"
              "--service-cidr=${cfg.serviceCIDR}"
              "--cluster-dns=${cfg.clusterDNS}"
              "--flannel-backend=vxlan"
              "--disable-network-policy"
              "--write-kubeconfig /run/kubeconfig"
            ] else [
              "--server https://${cfg.serverAddr}:6443"
            ])
            ++
            cfg.extraFlags
          );
        in
        mkForce ("${pkgs.busybox}/bin/sh -c '"
          + " export PATH=$PATH:${pkgs.fuse-overlayfs}/bin:${pkgs.fuse3}/bin" # PATH is set with ENVIRONMENT= and not Path=, so it can't be easily overwritten - add fuse-overlayfs to path
          + " && exec ${pkgs.k3s}/bin/k3s ${cfg.role} ${options}"
          + "'");

      environment.systemPackages = with pkgs; [
        (mkIf cfg.docker docker)
        k3s
        kubectl
        kubernetes-helm
      ];

      environment.extraInit = ''
        export KUBECONFIG=/run/kubeconfig
      '';

      networking.firewall.trustedInterfaces = [ "tunl0" "cni0" "flannel.1" ];

      boot = {
        kernelParams = [ "cgroup_enable=cpuset" "cgroup_enable=memory" "cgroup_memory=1" ];
      };

    };

}

