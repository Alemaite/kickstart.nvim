#!/usr/bin/env bash
# Repair nvim-treesitter query symlinks after moving ~/.local/share/nvim
# between machines. The links store absolute paths, so they dangle when the
# home directory name changes. Repoint every broken one at the bundled
# nvim-treesitter copy, which ships query sets for every language.
#
# Not needed if the bundle was built with `tar -h`. See OFFLINE.md.
set -u

Q="$HOME/.local/share/nvim/site/queries"
P="$HOME/.local/share/nvim/site/pack/core/opt/nvim-treesitter/runtime/queries"

[ -d "$Q" ] || { echo "no queries dir at $Q"; exit 1; }
[ -d "$P" ] || { echo "no plugin queries at $P"; exit 1; }

cd "$Q" || exit 1

for f in * angular html_tags; do
  [ -e "$f" ] && continue
  if [ -d "$P/$f" ]; then
    ln -sfn "$P/$f" "$f" && echo "linked  $f"
  else
    echo "NO SOURCE  $f"
  fi
done

echo "--- checking ---"
broken=0
for f in "$Q"/*; do
  [ -e "$f" ] || { echo "STILL BROKEN: $f"; broken=1; }
done
[ "$broken" -eq 0 ] && echo "all query links resolve"
