{ stdenv, fetchFromGitHub, autoreconfHook, pkgconfig, czmq }:

stdenv.mkDerivation rec {
  pname = "czmqpp";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "zeromq";
    repo = "czmqpp";
    rev = "v${version}";
    sha256 = "0z8lwq53yk4h7pgibicx3q9idz15qb95r0pjpz0j5vql6qh46rja";
  };

  nativeBuildInputs = [ autoreconfHook pkgconfig ];

  propagatedBuildInputs = [ czmq ];

  # https://github.com/zeromq/czmqpp/issues/42
  patches = [ ./socket.patch ];

  meta = with stdenv.lib; {
    inherit (src.meta) homepage;
    description = "C++ wrapper for czmq. Aims to be minimal, simple and consistent";
    license = licenses.lgpl3;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = with maintainers; [ chris-martin ];
  };
}
