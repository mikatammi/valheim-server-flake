# Update valheim-server to the newest public manifest of its Steam depot.
#
# Run from the root of this flake. The manifest ID comes from Steam, the hash
# from building the fetcher, and the version from the game itself, which only
# stores it as ints in assembly_valheim.dll.
#
# Only the current public manifest can be fetched: Steam refuses anonymous
# accounts the request codes for older ones.

appId=896660
depotId=896661
pkg=pkgs/valheim-server/default.nix

fail() {
  echo "update-valheim-server: $*" >&2
  exit 1
}

get() {
  sed -nE "s/^ *$1 = \"(.*)\";$/\1/p" "$pkg"
}

put() {
  sed -i -E "s|^( *$1 = \")[^\"]*|\1$2|" "$pkg"
}

# Build the depot fetcher for manifest $1, expecting hash $2.
fetchDepot() {
  nix build --no-link --print-out-paths --impure --expr "
    (builtins.getFlake \"git+file://$PWD\").packages.x86_64-linux.valheim-server-unwrapped.src.overrideAttrs {
      manifestId = \"$1\";
      outputHash = \"$2\";
    }"
}

[[ -f $pkg ]] || fail "run me from the root of valheim-server-flake"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

oldVersion=$(get version)
oldManifest=$(get manifestId)

HOME=$tmp DepotDownloader -app "$appId" -depot "$depotId" -manifest-only -dir "$tmp" >&2
manifest=$(basename "$tmp"/manifest_"$depotId"_*.txt .txt)
manifest=${manifest##*_}
[[ $manifest =~ ^[0-9]+$ ]] || fail "no manifest ID found for depot $depotId"

if [[ $manifest == "$oldManifest" ]]; then
  echo "valheim-server $oldVersion is already up to date (manifest $manifest)"
  exit 0
fi

echo "Fetching manifest $manifest to compute its hash..." >&2
fetchDepot "$manifest" "" 2>&1 | tee "$tmp/fetch.log" >&2 || true
hash=$(sed -nE 's/^ *got: *(sha256-[^ ]+)$/\1/p' "$tmp/fetch.log")
[[ -n $hash ]] || fail "fetching manifest $manifest failed, see the log above"

out=$(fetchDepot "$manifest" "$hash")
version=$(ilspycmd -t Version "$out/valheim_server_Data/Managed/assembly_valheim.dll" |
  sed -nE 's/.*CurrentVersion .*new GameVersion\(([0-9]+), ([0-9]+), ([0-9]+)\).*/\1.\2.\3/p')
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "no CurrentVersion in assembly_valheim.dll"

put manifestId "$manifest"
put hash "$hash"
put version "$version"
echo "valheim-server: $oldVersion -> $version (manifest $oldManifest -> $manifest)"
