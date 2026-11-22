class_name Version
## Numero di questa versione del gioco, scritto in version.txt (lo alza tools/pubblica_aggiornamento.sh,
## non toccarlo a mano). Sta in un file di testo e non in una costante perché la scena di avvio (boot.gd)
## deve leggerlo senza caricare script: con un aggiornamento caricato, res://version.txt è il suo.

const REPO := "communicationbox/meditaly"
const FILE := "res://version.txt"


static func build() -> int:
	return FileAccess.get_file_as_string(FILE).strip_edges().to_int()
