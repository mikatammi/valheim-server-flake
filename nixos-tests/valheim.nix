# Boots the server through the NixOS module, set up as in the README, and
# checks that it reports the version pinned in pkgs/valheim-server.
{self}: {config, ...}: {
  name = "valheim-server-boots";

  # The module adds overlays and the server is unfree, as in a real config.
  node.pkgsReadOnly = false;

  nodes.machine = {lib, ...}: {
    imports = [self.nixosModules.default];
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "valheim-server"
        "steamworks-sdk-redist"
      ];
    virtualisation.memorySize = 4096;
    services.valheim = {
      enable = true;
      serverName = "NixOS test";
      worldName = "Test";
      password = "secret";
      noGraphics = true;
    };
  };

  testScript = ''
    import re

    machine.wait_for_unit("valheim.service")
    # The version is only printed once the world is loaded, which takes about
    # 200 s even with KVM.
    line = machine.wait_until_succeeds(
        "journalctl -u valheim -o cat | grep -m1 'Valheim version: '", timeout=900
    )
    # The server prefixes the version with its platform, e.g. l-1.0.16.
    match = re.search(r"Valheim version: [a-z]+-(\S+)", line)
    assert match, line
    assert match.group(1) == "${config.hostPkgs.valheim-server-unwrapped.version}", line
  '';
}
