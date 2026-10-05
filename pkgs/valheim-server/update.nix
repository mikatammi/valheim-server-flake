{
  writeShellApplication,
  coreutils,
  depotdownloader,
  gnused,
  ilspycmd,
}:
writeShellApplication {
  name = "update-valheim-server";
  # nix itself comes from the caller's PATH, so builds use the host's daemon
  # and its remote builders (e.g. a Linux builder on macOS).
  runtimeInputs = [
    coreutils
    depotdownloader
    gnused
    ilspycmd
  ];
  text = builtins.readFile ./update.sh;
}
