{ lib
, stdenv
, fetchFromGitLab
, pkg-config
, libusb1
}:

stdenv.mkDerivation rec {
  pname = "minipro";
  version = "0.5";

  src = fetchFromGitLab {
    owner = "DavidGriffith";
    repo = "minipro";
    rev = version;
    sha256 = "sha256-Hyj2LyY7W8opjigH+QLHHbDyelC0LMgGgdN+u3nNoJc=";
  };

  nativeBuildInputs = [ pkg-config which ];
  buildInputs = [ libusb ];
  makeFlags = [ "DESTDIR=$(out)" "PREFIX=" "CC=cc" ];

  meta = with lib; {
    homepage = "https://gitlab.com/DavidGriffith/minipro";
    description = "An open source program for controlling the MiniPRO TL866xx series of chip programmers";
    license = licenses.gpl3;
    maintainers = [ maintainers.bmwalters ];
    platforms = platforms.all;
  };
}
