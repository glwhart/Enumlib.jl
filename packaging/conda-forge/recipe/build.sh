#!/bin/bash
set -euxo pipefail

# DRAFT — not submitted. See ../README.md.
#
# The source tarball is a PackageCompiler app: bin/ holds enum.x and polya.x, and
# lib/ holds the bundled Julia runtime and shared libraries. The executables
# resolve their libraries relative to their own location, so the tree must be
# installed intact and the launchers must stay next to it.
#
# Layout in $PREFIX:
#   libexec/enumlib-jl/{bin,lib,share}   <- the app, unmodified
#   bin/enum.x, bin/polya.x              <- thin launchers on PATH

APPDIR="${PREFIX}/libexec/enumlib-jl"
mkdir -p "${APPDIR}" "${PREFIX}/bin"

# The tarball unpacks to a single versioned directory; copy its contents.
SRC="$(find . -maxdepth 1 -type d -name 'enumlib-jl-*' | head -n 1)"
if [ -z "${SRC}" ]; then
  # Some conda source handling strips the leading directory.
  SRC="."
fi
cp -R "${SRC}/." "${APPDIR}/"

test -x "${APPDIR}/bin/enum.x"
test -x "${APPDIR}/bin/polya.x"

for exe in enum.x polya.x; do
  cat > "${PREFIX}/bin/${exe}" <<EOF
#!/bin/bash
# Launcher for the bundled Enumlib.jl app. exec keeps argv and the exit code
# intact, which matters: callers such as pymatgen's EnumlibAdaptor rely on the
# exit status, and the input filename arrives as a positional argument.
exec "\${CONDA_PREFIX:-${PREFIX}}/libexec/enumlib-jl/bin/${exe}" "\$@"
EOF
  chmod +x "${PREFIX}/bin/${exe}"
done
