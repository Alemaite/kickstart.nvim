# Moving this config to the offline machine

This config is developed on an online VM and carried to an air-gapped WSL
machine on a USB stick. Neovim itself is installed separately on both (release
tarball into `/opt`, symlinked from `/usr/local/bin`); the versions must match,
or compiled treesitter parsers will not load.

## What has to travel

| Path | Contents |
| --- | --- |
| `~/.config/nvim` | this repo |
| `~/.local/share/nvim/site` | plugins (`vim.pack`), treesitter parsers and queries |
| `~/.local/share/nvim/mason` | language servers, plus Mason's package registry |
| `~/lsp/angular-ls` | the Angular 9 language server (see below) |

## Building the bundle, on the online machine

    cd ~
    tar czhf /mnt/x/nvim-bundle.tar.gz \
      .config/nvim .local/share/nvim/site .local/share/nvim/mason lsp/angular-ls

`-h` is not optional. `site/queries/*` are symlinks holding absolute paths into
the source machine's home directory. Copied as links they dangle on the target,
and treesitter silently stops highlighting while still reporting an active
highlighter. `-h` stores the real files instead.

## Unpacking, on the offline machine

    cd ~
    mv .config/nvim .config/nvim.old
    mv .local/share/nvim/site .local/share/nvim/site.old
    mv .local/share/nvim/mason .local/share/nvim/mason.old
    rm -rf ~/.cache/nvim
    tar xzf /mnt/x/nvim-bundle.tar.gz

Mason writes launcher scripts with the source machine's home path baked in.
Two need rewriting:

    sed -i 's|/home/<source-user>|'"$HOME"'|g' \
      ~/.local/share/nvim/mason/packages/lua-language-server/lua-language-server \
      ~/.local/share/nvim/mason/packages/jdtls/jdtls

If the bundle was built without `-h`, repair the query links:

    bash ~/.config/nvim/scripts/fix-queries.sh

Then check `java`, `node`, and `nvim --version`. Mason ships the servers but
not the runtimes they need, and Node usually comes from nvm, whose PATH is set
by your shell startup file.

## Once offline

- Plugin updates: `:lua vim.pack.update(nil, { offline = true })`
- Do not run `:MasonInstall`, `:MasonUpdate`, or a plain `vim.pack.update()`
- New servers and treesitter parsers must be installed on the online machine
  first, then re-transferred. Parsers compile from grammar sources fetched over
  the network and cannot be built offline.

## The Angular language server

Angular 9 needs `@angular/language-server@0.901.11`, which Mason cannot install
correctly: npm resolves its caret ranges to a modern `vscode-jsonrpc`, and the
2020 server dies on startup with `messageReader.onClose is not a function`.
`~/lsp/angular-ls` pins the transitive versions instead; its `package.json`
records which ones and why. `init.lua` points `angularls` at that folder with an
explicit `cmd`, and filters it out of Mason's `ensure_installed`.

Angular templates are filetype `htmlangular`, whose treesitter parser is named
`angular`. Its highlight query inherits from `html_tags`, so both must be
present or templates render unhighlighted.

## Java: jdtls and Gradle

jdtls resolves a Gradle project's classpath through Buildship, which by default
runs the project's Gradle **wrapper**. The wrapper downloads its distribution on
first use, so on an air-gapped machine the import never finishes: jdtls attaches
and answers within a single file, but every cross-file lookup returns nothing.
The symptom in `~/.local/state/nvim/lsp.log` is

    Could not load Gradle version information
    Cannot download published Gradle versions

followed by no import ever completing.

`init.lua` therefore turns the wrapper off and points Buildship at a local
Gradle install, taken from `$GRADLE_HOME` or `~/tools/gradle-8.10.1`. Keep that
install on the Linux filesystem, not under `/mnt/c` - Gradle reads thousands of
files from its distribution, and every one of them crosses the WSL boundary.

    cp -r "/mnt/c/Users/<user>/build tools/gradle-8.10.1" ~/tools/

Turning the wrapper off is only half of it. `nvim-lspconfig` ships
`init_options = {}`, so anything under `settings` reaches jdtls as a
`workspace/didChangeConfiguration` notification - which arrives *after* the
project import has already begun, with defaults. `java.import.*` must therefore
go out in `initializationOptions` as well, the way vscode-java sends it. The
config builds one `java_settings` table and passes it both ways.

The "Could not load Gradle version information / Cannot download published
Gradle versions" warning appears on every air-gapped start. It is Buildship
fetching a list of downloadable Gradle releases for a version picker, and it
blocks nothing - do not chase it.

After changing any of this, wipe the jdtls workspace so it re-imports:

    rm -rf ~/.cache/nvim/jdtls

Eclipse keeps the real import errors in its own log, which is far more useful
than nvim's when something goes wrong:

    ~/.cache/nvim/jdtls/workspace/<project>/.metadata/.log
