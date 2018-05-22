{ stdenv, lib, libpcap, buildGoPackage, fetchFromGitHub }:

with lib;

buildGoPackage rec {
  name = "etcd-${version}";
  version = "3.3.4"; # After updating check that nixos tests pass
  rev = "v${version}";

  goPackagePath = "github.com/coreos/etcd";

  src = fetchFromGitHub {
    inherit rev;
    owner = "coreos";
    repo = "etcd";
    sha256 = "17bv3im0p69c1z9flyz5fhk61qcc84mizvcb7zib3k13csm7vdib";
  };

  subPackages = [
    "cmd/etcd"
    "cmd/etcdctl"
#    "cmd/tools/benchmark"
#    "cmd/tools/etcd-dump-db"
#    "cmd/tools/etcd-dump-logs"
  ];

  buildInputs = [ libpcap ];

  meta = {
    description = "Distributed reliable key-value store for the most critical data of a distributed system";
    license = licenses.asl20;
    homepage = https://coreos.com/etcd/;
    maintainers = with maintainers; [offline];
    platforms = with platforms; linux;
  };
}
