#!/bin/bash
# Pubblica un aggiornamento: chi ha già il gioco lo scarica da solo al prossimo avvio (vedi scripts/updater.gd).
#   tools/pubblica_aggiornamento.sh "Cosa cambia, in una riga"            solo i contenuti (.pck, pochi MB)
#   tools/pubblica_aggiornamento.sh --completa "Cosa cambia, in una riga"  anche le build intere Mac e Windows
# Serve --completa quando cambia la versione di Godot o le impostazioni di esportazione: i giocatori
# con un motore diverso vedono «Scarica» e prendono la build intera dal Release.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot 2.app/Contents/MacOS/Godot}"
FULL=0
if [ "${1:-}" = "--completa" ]; then FULL=1; shift; fi
NOTE="${1:-}"
[ -n "$NOTE" ] || { sed -n 2,6p "$0"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "Ci sono modifiche non salvate: fai prima il commit."; exit 1; }
REPO=$(sed -nE 's/^const REPO := "(.*)"/\1/p' scripts/version.gd)
OLD=$(tr -d '[:space:]' < version.txt)
NEW=$((OLD + 1))
TAG="b$NEW"
ENGINE=$("$GODOT" --version | python3 -c 'import sys,re; p=re.findall(r"\d+", sys.stdin.read().split(".stable")[0].split("-")[0]); print(".".join((p+["0","0"])[:3]))')
OUT="build/aggiornamento/$TAG"

echo "$NEW" > version.txt
trap 'git checkout -- version.txt; echo "Interrotto: versione riportata a $OLD."' ERR
rm -rf "$OUT" && mkdir -p "$OUT"

echo "== Versione $NEW (Godot $ENGINE): esporto i pacchetti"
for P in macOS Windows; do
	"$GODOT" --headless --path . --export-pack "$P" "$OUT/meditaly-$TAG-$P.pck" > "$OUT/export-$P.log" 2>&1
	[ -s "$OUT/meditaly-$TAG-$P.pck" ] || { echo "Esportazione $P fallita, vedi $OUT/export-$P.log"; false; }
done

ASSETS=("$OUT/meditaly-$TAG-macOS.pck" "$OUT/meditaly-$TAG-Windows.pck")
if [ $FULL = 1 ]; then
	echo "== Build intere"
	APP="$OUT/mac/Signori d'Italia.app"
	mkdir -p "$OUT/mac" "$OUT/windows"
	"$GODOT" --headless --path . --export-release "macOS" "$APP" > "$OUT/export-mac.log" 2>&1
	EXE=$(ls "$APP/Contents/MacOS/"* | head -1)
	lipo "$EXE" -thin arm64 -output "$EXE.arm64" && mv "$EXE.arm64" "$EXE" && chmod +x "$EXE"
	codesign --force --deep -s - "$APP"
	ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/Signori_d_Italia_Mac.zip"
	# Mac Intel: renderer Mobile (tag intel_mac nel preset) e grafica Leggera di partenza
	IAPP="$OUT/intel/Signori d'Italia.app"
	mkdir -p "$OUT/intel"
	"$GODOT" --headless --path . --export-release "macOS Intel" "$IAPP" > "$OUT/export-intel.log" 2>&1
	IEXE=$(ls "$IAPP/Contents/MacOS/"* | head -1)
	lipo "$IEXE" -thin x86_64 -output "$IEXE.x86" && mv "$IEXE.x86" "$IEXE" && chmod +x "$IEXE"
	codesign --force --deep -s - "$IAPP"
	ditto -c -k --sequesterRsrc --keepParent "$IAPP" "$OUT/Signori_d_Italia_Mac_Intel.zip"
	"$GODOT" --headless --path . --export-release "Windows" "$OUT/windows/Signori d'Italia.exe" > "$OUT/export-win.log" 2>&1
	(cd "$OUT/windows" && zip -qr ../Signori_d_Italia_Windows.zip .)
	ASSETS+=("$OUT/Signori_d_Italia_Mac.zip" "$OUT/Signori_d_Italia_Mac_Intel.zip" "$OUT/Signori_d_Italia_Windows.zip")
fi

python3 - "$OUT" "$TAG" "$NEW" "$ENGINE" "$REPO" "$NOTE" <<'PY'
import hashlib, json, sys
out, tag, build, engine, repo, note = sys.argv[1:]
pck = {}
for p in ("macOS", "Windows"):
    name = f"meditaly-{tag}-{p}.pck"
    sha = hashlib.sha256(open(f"{out}/{name}", "rb").read()).hexdigest()
    pck[p] = {"url": f"https://github.com/{repo}/releases/download/{tag}/{name}", "sha256": sha}
json.dump({"build": int(build), "engine": engine, "note": note, "pck": pck},
          open(f"{out}/aggiornamento.json", "w"), ensure_ascii=False, indent=1)
PY

echo "== Commit, tag e Release $TAG"
git commit -q -am "Versione $NEW: $NOTE"
trap - ERR
git tag "$TAG"
git push -q origin HEAD "$TAG"
gh release create "$TAG" "${ASSETS[@]}" "$OUT/aggiornamento.json" --repo "$REPO" --title "Versione $NEW" --notes "$NOTE" --latest
echo "Pubblicata la versione $NEW: i giocatori la ricevono al prossimo avvio."
