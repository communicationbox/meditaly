class_name Defs
extends RefCounted
## Costanti di gioco condivise: mondo, materiali, unità, casate, castelli, poteri.

## Scala della penisola: 2 = ogni lato doppio rispetto alla prima versione. Castelli, borghi e
## soldati restano della stessa grandezza: cresce solo la strada tra un castello e l'altro.
const MAP_SCALE := 2.0
const WX := 1376
const WZ := 1616
const WY := 60
const SEA := 10
const CHUNK := 32
const PORT := 27015
const SIM_HZ := 15.0
## Casate giocabili; i Comuni liberi (neutrali) vengono subito dopo in HOUSES.
const HOUSE_COUNT := 9
const NEUTRAL := 9
## Una modifica è (indice << EDIT_SHIFT) | materiale in un int64 (PackedInt64Array):
## l'indice arriva a WX * WZ * WY (circa 133 milioni, 28 bit) e il materiale usa 6 bit.
const EDIT_SHIFT := 6
const EDIT_MASK := 63

# ---------------------------------------------------------------- materiali
enum { AIR, GRASS, GRASS2, DIRT, ROCK, SAND, SNOW, FARM, VINE, ROAD, LAVA,
	STONE = 16, STONE2, BRICK, MARBLE, WOOD, ROOF, PLASTER, GATE, TRUNK, LEAF, CYPRESS, OLIVE, DOME,
	CHEESE, GILT, AZURE,
	TEAM0 = 32 }
const STRUCT_MIN := 16

const PALETTE: Array[Color] = [
	Color(0, 0, 0), Color(0.36, 0.56, 0.22), Color(0.45, 0.60, 0.25), Color(0.46, 0.33, 0.22),
	Color(0.47, 0.45, 0.43), Color(0.90, 0.82, 0.58), Color(0.95, 0.97, 1.0), Color(0.86, 0.72, 0.30),
	Color(0.33, 0.43, 0.18), Color(0.72, 0.62, 0.44), Color(1.6, 0.55, 0.08), Color(1, 0, 1),
	Color(1, 0, 1), Color(1, 0, 1), Color(1, 0, 1), Color(1, 0, 1),
	Color(0.62, 0.60, 0.56), Color(0.52, 0.50, 0.47), Color(0.70, 0.34, 0.22), Color(0.92, 0.90, 0.84),
	Color(0.45, 0.30, 0.16), Color(0.78, 0.33, 0.17), Color(0.93, 0.80, 0.58), Color(0.34, 0.20, 0.10),
	Color(0.36, 0.25, 0.15), Color(0.25, 0.47, 0.17), Color(0.12, 0.28, 0.14), Color(0.46, 0.54, 0.30),
	Color(0.72, 0.30, 0.18), Color(0.98, 0.80, 0.30), Color(0.95, 0.72, 0.18), Color(0.20, 0.32, 0.70),
]

## Quanto è difficile distruggere il materiale (più alto = più resistente).
static func hardness(m: int) -> float:
	match m:
		STONE, STONE2: return 1.0
		BRICK: return 0.8
		MARBLE: return 1.2
		WOOD, GATE, TRUNK: return 0.5
		ROOF, PLASTER, DOME: return 0.45
		CHEESE: return 0.6
		GILT, AZURE: return 0.7
		LEAF, CYPRESS, OLIVE: return 0.15
		ROCK, SNOW: return 2.6
		DIRT, GRASS, GRASS2, FARM, VINE, ROAD, SAND: return 1.8
	return 0.8

static func mat_color(m: int) -> Color:
	if m >= TEAM0:
		return HOUSES[m - TEAM0].color
	return PALETTE[m]

## Le unità attraversano la vegetazione.
static func blocks_walk(m: int) -> bool:
	return m != AIR and m != TRUNK and m != LEAF and m != CYPRESS and m != OLIVE

# ---------------------------------------------------------------- geografia
static func geo(lon: float, lat: float) -> Vector2:
	return Vector2((lon - 6.2) * 52.65, (47.4 - lat) * 71.175) * MAP_SCALE

const POLY_MAINLAND := [
	[7.5,43.8],[6.9,44.4],[7.0,45.0],[6.8,45.7],[7.1,45.95],[8.4,46.4],[9.0,46.1],[10.2,46.6],[10.5,46.95],
	[12.2,47.05],[13.7,46.5],[13.8,45.6],[13.0,45.65],[12.4,45.4],[12.5,44.9],[12.3,44.4],[12.65,44.0],
	[13.6,43.6],[14.2,42.5],[15.2,41.95],[16.2,41.85],[15.95,41.5],[16.9,41.1],[18.0,40.6],[18.5,40.1],
	[18.35,39.8],[18.0,40.0],[17.2,40.5],[16.6,39.8],[17.2,39.0],[16.6,38.6],[16.0,37.9],[15.65,38.05],
	[15.85,38.45],[16.2,38.9],[15.6,40.0],[14.8,40.6],[14.2,40.8],[13.6,41.2],[12.6,41.45],[11.8,42.1],
	[10.5,42.9],[10.3,43.5],[9.8,44.05],[8.9,44.4],[8.4,44.3],[8.0,43.9],
]
const POLY_SICILY := [[12.45,38.0],[13.35,38.2],[15.6,38.3],[15.1,37.5],[15.3,37.0],[15.1,36.65],[14.2,37.05],[13.5,37.25],[12.45,37.65]]
const POLY_SARDINIA := [[8.2,40.95],[9.2,41.25],[9.7,40.9],[9.75,39.9],[9.55,39.1],[9.1,39.15],[8.4,38.95],[8.45,39.9],[8.3,40.55]]
const POLY_CORSICA := [[8.6,42.4],[9.4,43.0],[9.55,42.1],[9.2,41.4],[8.7,41.7]]

const ALPS := [[6.9,44.2],[7.0,45.3],[7.6,46.0],[8.6,46.3],[10.0,46.6],[11.5,46.8],[12.8,46.7],[13.5,46.4]]
const APENNINES := [[8.5,44.45],[9.6,44.35],[10.8,44.1],[12.0,43.7],[12.9,43.1],[13.6,42.4],[14.4,41.6],[15.3,40.9],[15.8,40.2],[16.1,39.4],[16.2,38.5]]
const PO := [[7.7,45.05],[8.6,45.1],[9.7,45.05],[10.8,45.0],[11.7,45.0],[12.45,44.95]]

# ---------------------------------------------------------------- casate e castelli
const HOUSES := [
	{"name": "Savoia", "stats": [3, 3, 3, 3], "city": "Torino", "motto": "La croce bianca delle Alpi", "color": Color(0.13, 0.28, 0.72)},
	{"name": "Visconti", "stats": [3, 4, 3, 2], "city": "Milano", "motto": "Il biscione che non perdona", "color": Color(0.14, 0.58, 0.30)},
	{"name": "Serenissima", "stats": [5, 2, 3, 2], "city": "Venezia", "motto": "Il leone di San Marco", "color": Color(0.72, 0.09, 0.14)},
	{"name": "Doria", "stats": [5, 3, 2, 2], "city": "Genova", "motto": "Signori del mare", "color": Color(0.94, 0.94, 0.90)},
	{"name": "Medici", "stats": [5, 2, 2, 3], "city": "Firenze", "motto": "Banchieri, mecenati e intrighi", "color": Color(0.48, 0.20, 0.72)},
	{"name": "Papato", "stats": [2, 3, 2, 5], "city": "Roma", "motto": "Le chiavi del cielo, e di molti tesori", "color": Color(0.96, 0.76, 0.10)},
	{"name": "Angioini", "stats": [2, 3, 4, 3], "city": "Napoli", "motto": "I gigli di Francia sotto il Vesuvio", "color": Color(0.25, 0.65, 0.92)},
	{"name": "Normanni", "stats": [2, 4, 3, 3], "city": "Palermo", "motto": "Venuti dal nord, rimasti per il sole", "color": Color(0.94, 0.45, 0.08)},
	{"name": "Ruffo", "stats": [3, 2, 4, 3], "city": "Cosenza", "motto": "Tra due mari e parecchi bergamotti", "color": Color(0.93, 0.35, 0.62)},
	{"name": "Comuni liberi", "stats": [3, 3, 3, 3], "city": "", "color": Color(0.42, 0.42, 0.42)},
]

## gate: 0=+Z 1=-Z 2=+X 3=-X (sud, nord, est, ovest)
const CASTLES := [
	{"name": "Torino", "lon": 7.35, "lat": 45.15, "house": 0, "wall": STONE, "gate": 2},
	{"name": "Milano", "lon": 9.6, "lat": 45.75, "house": 1, "wall": BRICK, "gate": 0, "guard": 4},
	{"name": "Venezia", "lon": 12.2, "lat": 45.55, "house": 2, "wall": MARBLE, "gate": 3},
	{"name": "Genova", "lon": 8.85, "lat": 44.55, "house": 3, "wall": STONE2, "gate": 1, "guard": 9},
	{"name": "Bologna", "lon": 11.3, "lat": 44.55, "house": NEUTRAL, "wall": BRICK, "gate": 1},
	{"name": "Firenze", "lon": 11.3, "lat": 43.35, "house": 4, "wall": STONE, "gate": 1, "guard": 3},
	{"name": "Ancona", "lon": 13.2, "lat": 43.45, "house": NEUTRAL, "wall": BRICK, "gate": 3},
	{"name": "Roma", "lon": 12.75, "lat": 41.85, "house": 5, "wall": MARBLE, "gate": 1, "guard": 7},
	{"name": "Napoli", "lon": 14.3, "lat": 41.15, "house": 6, "wall": STONE2, "gate": 1},
	{"name": "Bari", "lon": 16.55, "lat": 41.0, "house": NEUTRAL, "wall": STONE, "gate": 3, "guard": 6},
	{"name": "Palermo", "lon": 13.5, "lat": 37.85, "house": 7, "wall": BRICK, "gate": 0},
	{"name": "Cagliari", "lon": 9.15, "lat": 39.5, "house": NEUTRAL, "wall": STONE2, "gate": 1, "guard": 6},
	{"name": "Cosenza", "lon": 16.45, "lat": 39.3, "house": 8, "wall": STONE, "gate": 1},
]

## Il potere scemo di ogni casata (tasto X), stesso ordine di HOUSES. Niente Fede: solo l'attesa.
## «self» parte subito, senza scegliere un punto sulla mappa.
const HOUSE_POWERS := [
	{"name": "Burocrazia sabauda", "short": "Burocrazia", "icon": "sp_modulo", "self": false, "desc": "Prima di proseguire, i nemici nella zona devono compilare un modulo in triplice copia", "quip": "manca il timbro, ripassate martedì"},
	{"name": "Apericena", "short": "Apericena", "icon": "sp_apericena", "self": false, "desc": "I nemici nella zona mollano la guerra per uno spritz. Pagano loro, a te", "quip": "la guerra riprende dopo il tagliere"},
	{"name": "Tassa di soggiorno", "short": "Tassa", "icon": "sp_tassa", "self": false, "desc": "Ogni nemico nella zona ti versa dei fiorini. Con ricevuta", "quip": "marca da bollo per tutti"},
	{"name": "Prendi 2 paghi 1", "short": "2 per 1", "icon": "sp_sconto", "self": true, "desc": "Per 25 secondi i soldati costano la metà. Offerta valida fino a esaurimento dignità", "quip": "saldi di fine guerra"},
	{"name": "La mazzetta", "short": "Mazzetta", "icon": "sp_mazzetta", "self": false, "desc": "Fino a 4 nemici nella zona cambiano bandiera. Si fattura a parte", "quip": "una busta, e l'onore si trova sempre"},
	{"name": "Scomunica Express", "short": "Scomunica", "icon": "sp_scomunica", "self": false, "desc": "Chi è più presente nella zona resta senza Fede per 30 secondi, e i suoi soldati in ginocchio", "quip": "consegna in giornata"},
	{"name": "Caffè sospeso", "short": "Caffè", "icon": "sp_caffe", "self": false, "desc": "I tuoi soldati nella zona corrono, picchiano e guariscono. Poi non dormono per tre giorni", "quip": "e ne ha pagato uno anche per voi"},
	{"name": "Arrivano i cugini", "short": "Cugini", "icon": "sp_cugini", "self": true, "desc": "Cinque parenti dal Nord si presentano gratis al tuo castello più vicino. Restano a cena", "quip": "hanno portato anche le valigie"},
	{"name": "Il peperoncino", "short": "Piccante", "icon": "sp_peperoncino", "self": false, "desc": "I nemici nella zona scappano urlando in cerca d'acqua", "quip": "«non piccava per niente», dicevano"},
]

## I poteri che fermano, distraggono, spaventano o comprano i soldati: chi difende il proprio re
## in pericolo non ci casca (Burocrazia, Apericena, Mazzetta, Scomunica, Peperoncino).
const DUTY_POWERS := [0, 1, 4, 5, 8]

## Didascalie delle uscite di scena del re, nello stesso ordine di UnitModels.re_scena (0 è il gabinetto).
const KING_DEATHS := [
	"%s di %s, sorpreso sul trono. Quello piccolo.",
	"%s di %s, scoperto nella botte del vino. Era quasi vuota.",
	"%s di %s, tradito dal trono a molla. Il collaudo era previsto per martedì.",
	"%s di %s: arriva la moglie, e la guerra finisce lì.",
	"%s di %s tenta la fuga via acqua. In una tinozza.",
	"%s di %s, sorpreso in camicia da notte. Il cane di corte non l'ha riconosciuto.",
	"%s di %s: la mamma ha detto basta guerre per oggi.",
	"%s di %s, travestito da armatura vuota. Reggeva bene, fino allo starnuto.",
	"%s di %s consegna la corona. È di cartone: quella vera è al banco dei pegni.",
	"%s di %s riceve il conto della guerra. Il rotolo è ancora al primo anno.",
]

## Caratteri delle casate: cubetti da 1 a 5, lo stesso totale per tutte (3 = nella media).
enum { STAT_SOLDI, STAT_FORZA, STAT_VELOCITA, STAT_FEDE }
const STAT_NAMES := ["Soldi", "Forza", "Velocità", "Fede"]
const STAT_TOTAL := 12
## Quanto vale un cubetto sopra o sotto la media. La Forza conta due volte: danni fatti e subiti.
const STAT_STEP := [0.10, 0.05, 0.07, 0.20]

static func stat_mult(team: int, stat: int) -> float:
	return 1.0 + float(int(HOUSES[team].stats[stat]) - 3) * float(STAT_STEP[stat])

## Colore delle frasi nei fumetti, per categoria: scuri quanto basta per leggerli sul crema.
const SAY_COLORS := [Color("b71c1c"), Color("6a1b9a"), Color("37474f"), Color("ad1457"), Color("a84300"), Color("1565c0"), Color("c2185b"), Color("1b6e20"), Color("5e35b1"), Color("5d4037"), Color("c62828"), Color("00695c"), Color("0277bd"), Color("b71c1c"), Color("1b6e20"), Color("37474f"), Color("1565c0")]

## Coppie di castelli collegate da strade.
const ROADS := [[0,1],[0,3],[1,3],[1,2],[1,4],[2,4],[4,5],[3,5],[4,6],[5,6],[5,7],[6,7],[7,8],[8,9],[6,8],[8,12],[9,12]]

# ---------------------------------------------------------------- unità
enum { FANTE, BALESTRIERE, CAVALIERE, ARIETE, CATAPULTA, BOMBARDA, FRATE, NONNA, MENESTRELLO, UNIT_TYPES }

const UNITS := [
	{"name": "Fante", "hp": 45, "dmg": 8, "range": 1.8, "speed": 9.0, "cd": 0.8, "cost": 20, "time": 2.5, "aggro": 16.0, "desc": "Economico, si butta nella mischia. Con la picca ferma i cavalieri"},
	{"name": "Balestriere", "hp": 28, "dmg": 6, "range": 20.0, "speed": 8.5, "cd": 1.5, "cost": 35, "time": 3.5, "aggro": 24.0, "desc": "Tira da lontano, ottimo sulle mura"},
	{"name": "Cavaliere", "hp": 95, "dmg": 16, "range": 2.2, "speed": 16.0, "cd": 1.0, "cost": 45, "time": 5.0, "aggro": 20.0, "desc": "Veloce e letale in campo aperto. Teme le picche e le balestre, e nei cortili combina poco"},
	{"name": "Ariete", "hp": 220, "dmg": 4, "range": 2.5, "speed": 6.5, "cd": 1.6, "cost": 90, "time": 6.0, "aggro": 0.0, "desc": "Sfonda porte e mura da vicino"},
	{"name": "Catapulta", "hp": 110, "dmg": 30, "range": 45.0, "speed": 6.0, "cd": 5.0, "cost": 120, "time": 8.0, "aggro": 45.0, "desc": "Scaglia massi: le mura crollano"},
	{"name": "Bombarda", "hp": 85, "dmg": 45, "range": 42.0, "speed": 5.5, "cd": 7.0, "cost": 170, "time": 10.0, "aggro": 42.0, "desc": "Palla di tiro teso, perfora tutto"},
	{"name": "Frate", "hp": 30, "dmg": 3, "range": 1.8, "speed": 6.0, "cd": 1.2, "cost": 25, "time": 3.0, "aggro": 5.0, "desc": "Prega accanto a una tua chiesa e porta Fede. Ogni tanto si addormenta"},
	{"name": "Nonna", "hp": 140, "dmg": 22, "range": 1.8, "speed": 4.5, "cd": 1.3, "cost": 45, "time": 5.0, "aggro": 14.0, "desc": "Lenta, ma col mattarello non perdona. «Hai mangiato?»"},
	{"name": "Menestrello", "hp": 30, "dmg": 3, "range": 1.8, "speed": 8.0, "cd": 1.0, "cost": 35, "time": 4.0, "aggro": 8.0, "desc": "Canta malissimo: i nemici vicini combattono peggio"},
]
## Le picche dei fanti fermano la carica: contro i cavalieri fanno tanto di più.
const PIKE_VS_HORSE := 2.2
## I dardi delle balestre passano l'armatura: contro i cavalieri fanno di più.
const BOLT_VS_HORSE := 1.8
## A cavallo, dentro un cortile, si combina poco: i cavalieri fanno meno danno al re e alle botteghe.
const HORSE_VS_KING := 0.4
## Fede: senza chiesa non arriva. La chiesa dà poco da sola, i frati che le pregano accanto il resto.
const FAITH_CHURCH := 0.25
const FAITH_FRIAR := 0.45
const FAITH_MAX_FRIARS := 6
const FAITH_CAP := 150.0
## Il menestrello stona: i nemici entro questo raggio fanno meno danni.
const BARD_RADIUS := 10.0
const BARD_FACTOR := 0.7

# ---------------------------------------------------------------- edifici
## Ogni castello ha due spazi nel cortile. Ogni potere funziona solo se la casata ha la bottega giusta,
## in piedi e in un castello suo: chi la distrugge o prende il castello si porta via il potere.
enum { B_CHIESA, B_CASEIFICIO, B_STALLA, B_CANTINA, B_ASTROLOGO, B_SANTUARIO, BUILDING_COUNT }
## Icona di ogni edificio (vedi Glyph): la stessa del potere che sblocca, la chiesa ha la sua.
const BUILDING_GLYPHS := ["chiesa", "parmigiano", "mucche", "vino", "stella", "scudo"]
const BUILDINGS := [
	{"short": "Chiesa", "name": "Chiesa", "cost": 120, "time": 18.0, "worker": "il frate", "desc": "Porta Fede, che serve a tutti i poteri. I frati le pregano accanto e ne portano di più"},
	{"short": "Caseificio", "name": "Caseificio", "cost": 150, "time": 20.0, "worker": "il casaro", "desc": "Sblocca la Forma di Parmigiano. Il casaro collauda le forme facendole rotolare"},
	{"short": "Stalla", "name": "Stalla", "cost": 140, "time": 20.0, "worker": "il mandriano", "desc": "Sblocca le Mucche Kamikaze. Il mandriano porta il casco, per sicurezza"},
	{"short": "Cantina", "name": "Cantina", "cost": 110, "time": 16.0, "worker": "l'oste", "desc": "Sblocca il Vino della Vittoria. L'oste assaggia ogni botte, per scrupolo"},
	{"short": "Astrologo", "name": "Torre dell'Astrologo", "cost": 190, "time": 24.0, "worker": "l'astrologo", "desc": "Sblocca il Terremoto. L'astrologo l'aveva previsto, dice. Dopo"},
	{"short": "Santuario", "name": "Santuario", "cost": 150, "time": 20.0, "worker": "le suore", "desc": "Sblocca lo Scudo Benedetto. Le suore difendono l'altare col mestolo"},
]
## Quale edificio serve a ciascun potere (indice = potere).
const POWER_BUILDING := [B_CASEIFICIO, B_CANTINA, B_ASTROLOGO, B_SANTUARIO, B_STALLA]
## Edificio finito: {c} casata, {t} castello.
const BUILD_DONE := [
	["A {t} suonano le campane: la chiesa è pronta. Il frate ha già trovato un angolo per dormire", "Chiesa nuova a {t}. Le offerte si accettano in fiorini"],
	["Caseificio aperto a {t}. Il casaro ha già perso una forma giù per la collina", "A {t} si stagiona il Parmigiano. Trentasei mesi, o finché serve"],
	["Stalla pronta a {t}. Le mucche fanno addestramento al lancio", "A {t} il mandriano allaccia il casco. Le mucche no, purtroppo"],
	["Cantina aperta a {t}. L'oste ha assaggiato la prima botte. E la seconda", "A {t} il vino è pronto. L'oste giura che il calo è evaporazione"],
	["Torre dell'Astrologo finita a {t}. Prima previsione: bel tempo. Sta grandinando", "L'astrologo di {t} ha letto le stelle: domani terremoto. Forse. O martedì"],
	["Santuario consacrato a {t}. Le suore lucidano i mestoli", "A {t} le suore benedicono tutto, anche le catapulte"],
]
const FRIARS := ["Fra' Cipolla", "Fra' Galdino", "Fra' Martino", "Fra' Ginepro", "Fra' Mortadella", "Fra' Pacioccone", "Fra' Tortellino", "Fra' Sonnacchioso"]
const FRIAR_SLEEP := [
	"{n} si è addormentato durante il vespro a {t}",
	"A {t} {n} russa più forte delle campane",
	"«Fra' Martino, campanaro, dormi tu?» A {t}, sì",
	"{n} a {t} dice che non dorme: medita a occhi chiusi",
]

const HOUSE_UNIT_CAP := 120
## L'esercito dell'IA cresce con i castelli: chi è in testa può davvero chiudere la partita.
const AI_UNIT_CAP := 34
const AI_UNIT_CAP_PER_CASTLE := 6
## Fiorini per ogni castello conquistato.
const CAPTURE_REWARD := 150.0

# ---------------------------------------------------------------- poteri (costo in Fede)
enum { P_PARMIGIANO, P_VINO, P_TERREMOTO, P_SCUDO, P_MUCCHE, POWER_COUNT }

const POWERS := [
	{"name": "Forma di Parmigiano", "short": "Parmigiano", "cost": 60, "cd": 32.0, "key": "1", "desc": "Una forma stagionata 36 mesi rotola sui nemici e apre una breccia"},
	{"name": "Vino della Vittoria", "short": "Vino", "cost": 25, "cd": 18.0, "key": "2", "desc": "L'armata ubriaca è veloce, furiosa e stonata"},
	{"name": "Terremoto", "short": "Terremoto", "cost": 70, "cd": 35.0, "key": "3", "desc": "Le mura tremano e crollano. Gli architetti giurano che erano a norma"},
	{"name": "Scudo Benedetto", "short": "Scudo", "cost": 40, "cd": 25.0, "key": "4", "desc": "Cupola d'oro che ferma i proiettili. Benedetta, con garanzia"},
	{"name": "Mucche Kamikaze", "short": "Mucche", "cost": 35, "cd": 20.0, "key": "5", "desc": "Mucche dal cielo. Muuu. BOOM."},
]

## Battute che annunciano i poteri: {c} è la casata che lo lancia, {t} la città colpita.
const QUIPS := [
	[ # Parmigiano
		"Un casaro di {c} ha perso la presa: una forma da trenta metri rotola verso {t}",
		"{c} spedisce a {t} un Parmigiano stagionato 36 mesi. Consegna a domicilio, nel senso di dentro casa",
		"Il Consorzio del Parmigiano declina ogni responsabilità per quanto sta per succedere a {t}",
		"A {t} avevano chiesto \"una grattugiata abbondante\". {c} ha esagerato",
		"Attenzione {t}: forma in discesa, crosta compresa",
	],
	[ # Vino
		"{c} offre da bere: l'armata vede i nemici doppi e li carica tutti e due",
		"Brindisi! I soldati di {c} giurano di poter guidare l'assedio benissimo",
		"Vino della casa per tutti: {c} marcia cantando, e stonando, verso la battaglia",
	],
	[ # Terremoto
		"{c} batte i piedi per terra. {t} trema",
		"A {t} gli architetti giurano che le mura erano a norma",
		"Scossa su {t}: il geometra di {c} aveva fatto i calcoli \"a occhio\"",
	],
	[ # Scudo
		"{c} fa benedire {t}: cupola d'oro, garanzia due anni",
		"Il parroco di {c} ha fatto gli straordinari: cupola su {t}",
		"{t} sotto la cupola: i proiettili rimbalzano, il prete sorride",
	],
	[ # Mucche
		"Le mucche di {c} hanno scelto la carriera militare. Destinazione: {t}",
		"Piovono mucche su {t}. Oggi il latte è esplosivo",
		"{c}: \"Non chiedete come le abbiamo addestrate\". Mucche in volo verso {t}",
		"Muuu... BOOM. {t} non dimenticherà questo pascolo",
	],
]

## Bilancio della forma di Parmigiano a fine corsa: {n} soldati travolti.
const WHEEL_REPORTS := [
	"La forma di {c} ha travolto {n} soldati a {t}. Ora sono grattugiati",
	"{n} soldati di {t} schiacciati dal Parmigiano. Il medico consiglia meno latticini",
	"Strike! {n} soldati abbattuti dalla forma di {c}",
	"A {t} {n} soldati sono diventati condimento",
]

## Il re di ogni castello siede sul gabinetto al pianterreno del mastio: si conquista solo
## uccidendolo. {K} è "il Re" o "il Podestà" (castelli liberi), {t} il castello, {c} chi attacca.
const KING_HIT := [
	"{K} di {t} dal gabinetto: «Occupato!»",
	"{K} di {t}: «Un attimo, sto leggendo la Gazzetta!»",
	"{K} di {t} sventola la bandierina bianca. Senza alzarsi",
	"{K} di {t}: «Villani! Non si bussa più, in questo regno?»",
	"{K} di {t}: «Guardie! Le guardie! E chiudete quella porta!»",
	"{K} di {t}: «È questo il rispetto per la Corona? Proprio adesso?»",
	"{K} di {t}: «Ancora cinque minuti!»",
]
const KING_DEAD := [
	"{K} di {t} è stato sorpreso nel momento più delicato del suo regno",
	"{K} di {t} è caduto con dignità. Più o meno",
	"«Morì come visse: seduto». Addio, {k} di {t}",
	"{K} di {t} vola via dal mastio. Il trono è libero, chi lo vuole?",
	"Il regno di {t} è finito come era cominciato: tra le carte",
]

## Fiorini al secondo di una casata umana con n castelli (l'IA ne prende l'80%).
static func income(castles_owned: int) -> float:
	return 4.0 + 3.0 * castles_owned if castles_owned > 0 else 0.0

# ---------------------------------------------------------------- proiettili
enum { SHOT_STONE, SHOT_BALL, SHOT_METEOR, SHOT_COW }


# ---------------------------------------------------------------- si deve ridere
## Fumetti dei soldati, per categoria. Si vedono sopra la testa di chi parla.
enum { SAY_CARICA, SAY_FERITO, SAY_MORTE, SAY_UBRIACO, SAY_SAGRA, SAY_SCIOPERO, SAY_MAMMA, SAY_SFOTTO, SAY_NONNA, SAY_FRATE, SAY_PANICO, SAY_VITTORIA, SAY_PALIO, SAY_CONTRO, SAY_PER_CAPO, SAY_MODULO, SAY_LEALE }
const SAY := [
	["All'attaccoooo!", "Per la mamma!", "Ma chi me l'ha fatto fare", "Io vado, eh. Voi venite?", "Dai che è venerdì!", "Ci pensa la fanteria!", "Avanti, Savoia! Ah no, sbagliato", "Prima i balestrieri!", "Tenetemi, che lo meno!"],
	["Ahia!", "Mamma mia!", "Un medicoooo", "Era solo un graffio. Ora no", "Ho finito i cerotti", "Mi gira la testa", "Questo lo dico al sindacato"],
	["Salutatemi la nonna", "Il mio pranzo…", "Che figura", "Ditelo al Papa", "Torno subito"],
	["♪ Volareee ♪", "Vi voglio bene a tutti", "Ma quanti siete? Il doppio!", "♪ Oh mia bella Madunina ♪", "Chi ha spostato il castello?", "Hic!"],
	["PORCHETTAAA!", "Un panino, uno solo", "Guerra? Dopo il caffè", "Con la crosticina!", "Chi paga? Il re", "Tregua, si mangia"],
	["SCIOPERO!", "Diritti per i balestrieri!", "Non si tira oggi", "Pausa sindacale", "Più polenta, meno guerra!", "Il contratto è scaduto"],
	["Arrivo mammaaa!", "È pronto in tavola!", "Se si fredda mi uccide lei", "Scusate, c'è il ragù", "Torno dopo, eh"],
	["Cucù!", "Ci vediamo al mercato", "Mia nonna tira meglio", "Che castello brutto", "Andate a zappare!"],
	["Hai mangiato?", "Sei sciupato", "Ti ammazzo col mattarello", "Mettiti la maglia!", "Ai miei tempi le guerre erano serie"],
	["Pace e bene", "Zzz…", "Prego per voi. Più o meno", "Amen e via"],
	["AAAAAH!", "IL FORMAGGIO!", "Si salvi chi può!", "Mamma, la forma!", "Non di qua, non di qua!", "È stagionato 36 mesi!"],
	["Abbiamo vintooo!", "Il mastio è nostro!", "Olè olè olè!", "Offro io! Ah no", "Campioni d'Italia!", "Chi è il re adesso?"],
	["Hiiii!", "Largo, largo!", "Il drappo è mio!", "Dai Morello, dai!", "Chi arriva ultimo paga"],
	["{n}, apri: è la consegna!", "Dov'è {n}? Gli dobbiamo due parole", "{n}, metti su l'acqua: siamo in cinquanta", "Salutatemi {n}!", "{n}, hai lasciato il portone aperto?", "Ci manda tua zia, {n}", "{n}, si può? Permesso!", "Chi ha votato {n}?", "{n}, conta i merli finché puoi", "Questo è per {n}, con affetto"],
	["Per {n}! E per la paga!", "{n} ha detto di correre", "Viva {n}, finché paga", "Se perdiamo è colpa di {n}", "{n}, guarda come picchio!", "Lo faccio per {n}. E per il pranzo", "{n} ci guarda: fingete di sapere cosa fate", "Avanti, {n} ha un piano. Forse", "{n} ci ha promesso le ferie", "Agli ordini di {n}, più o meno"],
	["Manca il timbro", "Serve la marca da bollo", "Dove firmo?", "È il modulo sbagliato", "Torni martedì", "Qui ci vuole la copia rosa"],
	["Lo spritz dopo, c'è il re da salvare", "Grazie, sono in servizio", "Il re prima di tutto. Poi il tagliere", "Non ora, stiamo difendendo", "Tenetemelo in fresco"],
]
## Sfottò fra giocatori: tasti 6-0. Il server li manda a tutti.
const TAUNTS := [
	"Cucù!",
	"Tutto qui?",
	"Mia nonna assedia meglio",
	"Arrendetevi, c'è il buffet",
	"Che castello brutto",
]
## Eventi a sorpresa: titolo, sottotitolo ({c} casata in testa).
const EVENTS := [
	["Sagra della Porchetta!", "Tutti a mangiare: la guerra può aspettare"],
	["Sciopero!", "I {u} di {c} incrociano le braccia"],
	["È pronto in tavola!", "La mamma chiama: metà armata di {c} corre a casa"],
	["Processione del Patrono", "Tregua santa: nessun potere per 25 secondi"],
	["Il Palio!", "Tutti i cavalieri in campo corrono al traguardo: chi arriva primo vince 200 fiorini"],
	["Scomunica!", "Il Papa scomunica {c}: niente Fede per 40 secondi"],
]
const PALIO_PRIZE := 200.0
