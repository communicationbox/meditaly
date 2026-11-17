class_name Campaign
extends RefCounted
## La storia: «L'ascesa del Conte di Borgo Spigolo», in 12 missioni raccontate dalla Gazzetta del Trecento.
## Solo dati. Ogni missione sblocca un pezzo di gioco; cosa non è sbloccato non si vede.
##
## Pagine del giornale: title (titolone), sub (sottotitolo), side (titoletti a lato), mini (miniatura).
## Castelli (indici di Defs.CASTLES): 1 Milano, 2 Venezia, 4 Bologna, 5 Firenze, 6 Ancona = Borgo Spigolo,
## 7 Roma, 8 Napoli, 9 Bari.

const HERO := "il Conte di Borgo Spigolo"
const HOME_CASTLE := 6
const HOME_NAME := "Borgo Spigolo"

const MISSIONS := [
	{ # 1
		"title": "Il vicino è in bagno",
		"minutes": "2-3",
		"setup": {"gold": 120, "guards": {4: [3, 0, 0]}, "hints": true},
		"goal": {"kind": "capture", "castles": [4]},
		"unlock": {"units": [Defs.FANTE]},
		"intro": {
			"title": "Conte senza terre dichiara guerra. Il vicino: «Chi?»",
			"sub": "Il Conte di Borgo Spigolo, un castello, una vacca e tre fanti, punta Bologna. La suocera: «Non combinerà mai niente»",
			"side": [
				"Borgo Spigolo compare per la prima volta su una mappa. A matita",
				"La vacca del Conte nominata capo di stato maggiore",
				"Il Podestà di Bologna: «Ora non posso, sono occupato»",
			],
		},
		"win": {
			"title": "Preso Bologna! Il Podestà sorpreso a metà della Gazzetta",
			"sub": "Il Conte festeggia con tortellini e un discorso di quaranta minuti. La suocera: «Fortuna»",
			"side": [
				"Il Podestà chiede almeno di finire l'articolo",
				"Tre fanti promossi a «tre fanti esperti»",
				"La vacca rilascia un'intervista: «Muu»",
			],
		},
		"lose": {
			"title": "Il Conte respinto. Il Podestà non si è neanche alzato",
			"sub": "«Riproviamo», dice il Conte. «Riproviamo», dice anche la suocera, ma con un altro tono",
		},
	},
	{ # 2
		"title": "La vendetta del vicino",
		"minutes": "3",
		"setup": {"gold": 250, "army": {Defs.FANTE: 6}, "owners": {4: 1}, "pnames": {1: "il Marchese di Bologna"}, "guards": {4: [6, 0, 0]}, "attack": {"house": 1, "units": {Defs.FANTE: 16}, "at": 8.0, "every": 60.0}},
		"goal": {"kind": "survive", "secs": 180},
		"unlock": {"defense": ["repair"]},
		"intro": {
			"title": "Il Marchese di Bologna vuole indietro il gabinetto",
			"sub": "Cugino del Podestà, arriva con un esercito e molta suscettibilità. Le mura di Borgo Spigolo sono di seconda mano",
			"side": [
				"Mura di Borgo Spigolo: «Reggono, se non piove»",
				"Previsioni: pioggia",
				"Il muratore del Conte offre lo sconto se si paga in fiorini",
			],
		},
		"win": {
			"title": "Le mura reggono! Il Marchese torna a casa a piedi",
			"sub": "Il Conte ripara tutto, anche un muro che non era mai esistito",
			"side": [
				"Il muratore chiede un ritocco del preventivo. Un ritocco grosso",
				"Il Marchese: «Era solo una passeggiata armata»",
				"Borgo Spigolo inaugura la Festa del Mattone",
			],
		},
		"lose": {
			"title": "Borgo Spigolo cade. Il Marchese si siede sul gabinetto",
			"sub": "Il Conte trasloca dalla suocera, che prepara il letto e un elenco di consigli",
		},
	},
	{ # 3
		"title": "Banditi sulle colline",
		"minutes": "4",
		"setup": {"gold": 250, "army": {Defs.FANTE: 4, Defs.BALESTRIERE: 4}, "pnames": {7: "i Banditi delle colline"}, "attack": {"house": 7, "units": {Defs.FANTE: 8, Defs.CAVALIERE: 2}, "at": 20.0, "every": 70.0, "times": 3}},
		"goal": {"kind": "waves"},
		"unlock": {"units": [Defs.BALESTRIERE], "defense": ["garrison"]},
		"intro": {
			"title": "Banditi sulle colline: rubano galline e certezze",
			"sub": "Il Conte assume i balestrieri. Dalle mura tirano più lontano, se trovano le scale",
			"side": [
				"I balestrieri chiedono una scala. Era la torre",
				"Le galline sporgono denuncia",
				"Il capo dei banditi giura: «Sono solo un appassionato di colline»",
			],
		},
		"win": {
			"title": "Banditi respinti! Le galline tornano a casa da sole",
			"sub": "Il capo dei banditi si ritira a vita privata. Apre una trattoria, sulle colline",
			"side": [
				"I balestrieri: «Da quassù si vede benissimo il pranzo»",
				"Una gallina chiede la cittadinanza onoraria",
				"Il Conte si fa fare un ritratto. Di profilo, il migliore",
			],
		},
		"lose": {
			"title": "I banditi si portano via le galline. E il castello",
			"sub": "Il Conte giura vendetta. Le galline, per ora, collaborano coi banditi",
		},
	},
	{ # 4
		"title": "Arriva la cavalleria",
		"minutes": "4-5",
		"setup": {"gold": 500, "army": {Defs.FANTE: 10, Defs.BALESTRIERE: 4}, "owners": {5: 4}, "pnames": {4: "il Signore di Firenze"}, "guards": {5: [5, 2, 0]}, "attack": {"house": 4, "units": {Defs.CAVALIERE: 6}, "at": 25.0}},
		"goal": {"kind": "capture", "castles": [5]},
		"unlock": {"units": [Defs.CAVALIERE]},
		"intro": {
			"title": "Il Signore di Firenze manda i cavalieri. Belli, lucidi, costosi",
			"sub": "Cavaliere batte fante. Fante con la picca batte cavallo. Il cavallo non è contento",
			"side": [
				"Firenze: il cavallo del capitano ha un sarto personale",
				"Il Conte compra i suoi primi cavalli. Uno è un asino, ma motivato",
				"Fabbri al lavoro: le picche vanno a ruba",
			],
		},
		"win": {
			"title": "La cavalleria fiorentina si ferma. Contro le picche",
			"sub": "Il Conte conquista il castello e un cavallo con il sarto",
			"side": [
				"I cavalli fiorentini chiedono asilo: «Qui si mangia meglio»",
				"L'asino del Conte promosso cavaliere ad honorem",
				"Il sarto si offre anche per le bandiere",
			],
		},
		"lose": {
			"title": "Carica fiorentina, il Conte si ritira con eleganza. E di corsa",
			"sub": "«Erano più cavalli di quanti ne avessi contati», spiega. Ne aveva contato uno",
		},
	},
	{ # 5
		"title": "Il portone",
		"minutes": "3",
		"setup": {"gold": 450, "army": {Defs.FANTE: 10, Defs.ARIETE: 2}, "owners": {4: 1}, "pnames": {1: "il Podestà di Bologna"}, "guards": {4: [5, 1, 0]}},
		"goal": {"kind": "capture", "castles": [4]},
		"unlock": {"units": [Defs.ARIETE]},
		"intro": {
			"title": "Il portone di Bologna resiste da tre secoli",
			"sub": "Il Conte ordina un ariete. Il falegname chiede: «Lo volete con la testa di montone o quella normale?»",
			"side": [
				"Il portone ha un suo fan club",
				"Il falegname consegna in ritardo: «Il montone non stava fermo»",
				"Bussare prima di entrare: il Conte ci pensa su",
			],
		},
		"win": {
			"title": "Il portone cede dopo tre secoli. Il fan club è in lutto",
			"sub": "Il Conte entra a Bologna per la seconda volta. Stavolta dalla porta",
			"side": [
				"Il fan club del portone si scioglie e fonda quello dell'ariete",
				"Il montone ritrovato: guardava tutto dalla collina",
				"Il Podestà cambia la serratura. Del gabinetto",
			],
		},
		"lose": {
			"title": "Il portone vince ancora. Il fan club festeggia",
			"sub": "L'ariete rimandato al falegname con un biglietto: «Più testa»",
		},
	},
	{ # 6
		"title": "Mura troppo alte",
		"minutes": "5-6",
		"setup": {"gold": 700, "army": {Defs.FANTE: 10, Defs.BALESTRIERE: 4, Defs.CATAPULTA: 1}, "owners": {5: 4}, "pnames": {4: "il Signore di Firenze"}, "guards": {5: [7, 3, 0]}},
		"goal": {"kind": "capture", "castles": [5]},
		"unlock": {"units": [Defs.CATAPULTA]},
		"intro": {
			"title": "Le mura di Firenze sono altissime. Il geometra ne va fiero",
			"sub": "Il Conte compra le catapulte. Clic destro su un muro nemico e si comincia a ragionare",
			"side": [
				"Il geometra di Firenze: «Calcoli fatti a occhio, ma un occhio bravo»",
				"Catapulte del Conte collaudate sul fienile della suocera",
				"La suocera sporge reclamo",
			],
		},
		"win": {
			"title": "Crollano le mura: il geometra era in ferie",
			"sub": "Breccia, assalto, re sorpreso sul trono. Il Conte prende Firenze e una cartolina del geometra",
			"side": [
				"Il geometra dalle ferie: «Non toccate niente, torno martedì»",
				"I massi delle mura venduti come souvenir",
				"La suocera: «Il fienile però lo ripari tu»",
			],
		},
		"lose": {
			"title": "Le mura reggono. Il geometra rientra dalle ferie per vantarsene",
			"sub": "Il Conte promette di tornare con più catapulte e meno ottimismo",
		},
	},
	{ # 7
		"title": "Due castelli, un Conte",
		"minutes": "7-8",
		"setup": {"gold": 500, "army": {Defs.FANTE: 6, Defs.BALESTRIERE: 4}, "owners": {4: 0, 5: 4, 2: 2}, "pnames": {4: "il Signore di Firenze", 2: "il Doge di Venezia"}, "ai": [4, 2], "aggr": 2.2},
		"goal": {"kind": "hold", "castles": [6, 4], "secs": 360},
		"unlock": {"defense": ["mangano", "oil"], "groups": true},
		"intro": {
			"title": "Il Conte ha due castelli e non sa dove ha lasciato il secondo",
			"sub": "Firenze e Venezia si alleano contro di lui. Ctrl+1 per fare un gruppo, Backspace per correre da un castello all'altro",
			"side": [
				"Il Conte si fa cucire un mantello con le tasche: «Per i castelli»",
				"Sul mastio arriva il mangano. E una pentola d'olio bollente",
				"Il cuoco protesta: «L'olio era per le frittelle»",
			],
		},
		"win": {
			"title": "Due castelli difesi! Il Conte ora sa dove sono",
			"sub": "Li ha segnati sulla mano. Firenze e Venezia firmano la pace e un buono per le frittelle",
			"side": [
				"Il cuoco recupera l'olio: le frittelle sanno di assedio",
				"Il mangano tira una pietra per festeggiare. Chiede scusa al vicino",
				"La suocera si complimenta. Poi si corregge",
			],
		},
		"lose": {
			"title": "Il Conte perde un castello. Non ricorda quale",
			"sub": "«Erano due, giuro», dice. Gli alleati annuiscono, con gentilezza",
		},
	},
	{ # 8
		"title": "Serve la Fede",
		"minutes": "4",
		"setup": {"gold": 450, "faith": 0},
		"goal": {"kind": "faith", "amount": 60},
		"unlock": {"build": [Defs.B_CHIESA], "units": [Defs.FRATE], "faith": true},
		"intro": {
			"title": "Il Conte scopre la Fede. Gliene serve parecchia",
			"sub": "Costruisci una chiesa fuori dalle mura e mandale i frati: pregando portano Fede, quando non dormono",
			"side": [
				"Frate assunto per pregare. Prima settimana: dormito",
				"Il campanaro chiede una campana più silenziosa",
				"Le offerte si accettano anche in galline",
			],
		},
		"win": {
			"title": "Borgo Spigolo trabocca di Fede. E di frati che russano",
			"sub": "Il vescovo in visita: «Mai vista una chiesa così devota e così addormentata»",
			"side": [
				"Fra' Sonnacchioso eletto frate del mese",
				"Il Conte fa voto di non dire più «tanto vinco io». Dura due giorni",
				"Le galline offerte formano un coro",
			],
		},
		"lose": {
			"title": "Niente Fede a Borgo Spigolo: i frati hanno sbagliato chiesa",
			"sub": "Sono andati a pregare dal vicino. Dicono che lì il pranzo è più puntuale",
		},
	},
	{ # 9
		"title": "Il Parmigiano",
		"minutes": "4-5",
		"setup": {"gold": 650, "faith": 80, "army": {Defs.FANTE: 8, Defs.BALESTRIERE: 3}, "owners": {4: 1}, "pnames": {1: "il Podestà di Bologna"}, "guards": {4: [6, 3, 0]}},
		"goal": {"kind": "capture", "castles": [4]},
		"unlock": {"build": [Defs.B_CASEIFICIO], "powers": [Defs.P_PARMIGIANO]},
		"intro": {
			"title": "Il Conte apre un caseificio. Obiettivo: militare",
			"sub": "Una forma stagionata 36 mesi rotola sui nemici e apre una breccia. Tasto Z, poi clic sul bersaglio",
			"side": [
				"Il casaro collauda le forme facendole rotolare. Cerca un altro casaro",
				"Il Consorzio del Parmigiano declina ogni responsabilità",
				"Le grattugie di Borgo Spigolo in allerta",
			],
		},
		"win": {
			"title": "Strike! La forma di Parmigiano apre la strada al Conte",
			"sub": "Il castello cade. I difensori: «Non piccava, ma pesava»",
			"side": [
				"Il Consorzio ripete: non siamo stati noi. Però è venuta bene",
				"La forma è stata ritrovata a valle. Intera",
				"I soldati chiedono il Parmigiano anche a pranzo",
			],
		},
		"lose": {
			"title": "La forma rotola, il castello resta in piedi",
			"sub": "Il casaro ammette: «Forse l'ho tirata dal lato sbagliato della collina»",
		},
	},
	{ # 10
		"title": "Assedio vero",
		"minutes": "8-10",
		"setup": {"gold": 1400, "faith": 150, "army": {Defs.FANTE: 16, Defs.BALESTRIERE: 6, Defs.CAVALIERE: 3, Defs.CATAPULTA: 1}, "owners": {7: 5}, "pnames": {5: "il Re di Roma"}, "guards": {7: [7, 3, 0]}},
		"goal": {"kind": "capture", "castles": [7]},
		"unlock": {
			"units": [Defs.BOMBARDA],
			"build": [Defs.B_STALLA, Defs.B_CANTINA, Defs.B_ASTROLOGO, Defs.B_SANTUARIO],
			"powers": [Defs.P_VINO, Defs.P_TERREMOTO, Defs.P_SCUDO, Defs.P_MUCCHE],
		},
		"intro": {
			"title": "Roma: mura di marmo, re abbronzato, nessuna fretta",
			"sub": "Il Conte arriva con le bombarde e quattro botteghe nuove: vino, terremoto, scudo benedetto e mucche dal cielo",
			"side": [
				"L'astrologo prevede un terremoto. Forse. O martedì",
				"Le mucche fanno addestramento al lancio. Il mandriano porta il casco",
				"L'oste assaggia ogni botte, per scrupolo",
			],
		},
		"win": {
			"title": "Piovono mucche su Roma: il Conte entra in città",
			"sub": "Il re sorpreso sul trono chiede almeno un'uscita di scena dignitosa. Gli danno quella che resta",
			"side": [
				"Le mucche chiedono il riposo del guerriero",
				"L'astrologo: «L'avevo previsto». Dopo",
				"Turisti a Roma: «Le rovine c'erano già»",
			],
		},
		"lose": {
			"title": "Roma resiste. Le mucche erano dirette altrove",
			"sub": "Il mandriano ammette un piccolo errore di mira: due regioni",
		},
	},
	{ # 11
		"title": "Le casate si svegliano",
		"minutes": "7-8",
		"setup": {"gold": 900, "faith": 100, "army": {Defs.FANTE: 16, Defs.BALESTRIERE: 6, Defs.CAVALIERE: 4}, "owners": {4: 1, 5: 4}, "pnames": {1: "il Marchese di Bologna", 4: "il Signore di Firenze"}, "ai": [1, 4], "aggr": 0.5, "cap": 0.3, "guards": {4: [5, 2, 0], 5: [5, 2, 0]}},
		"goal": {"kind": "capture", "castles": [4, 5]},
		"unlock": {"units": [Defs.NONNA, Defs.MENESTRELLO], "special": true, "events": true, "taunts": true},
		"intro": {
			"title": "Le grandi casate si accorgono del Conte. Gli mandano gli auguri. Armati",
			"sub": "Arrivano le nonne col mattarello, i menestrelli stonati e il potere della casata (tasto F). E la Sagra della Porchetta, quando meno te lo aspetti",
			"side": [
				"Le nonne chiedono se il Conte ha mangiato. Il Conte mente",
				"Il menestrello del Conte canta così male che i nemici combattono peggio",
				"Sfottò fra casate: il Conte prepara il primo. Ci lavora da una settimana",
			],
		},
		"win": {
			"title": "Due castelli in un pomeriggio, sagra compresa",
			"sub": "Il Conte giura che la porchetta non ha influito sull'esito della battaglia",
			"side": [
				"Le nonne ottengono un seggio nel consiglio di guerra",
				"Il menestrello invitato a non cantare più. Ovunque",
				"La suocera chiede la ricetta della porchetta",
			],
		},
		"lose": {
			"title": "Il Conte sconfitto alla sagra: era a tavola",
			"sub": "Chi è a tavola non si tocca. Ma chi si alza da tavola sì",
		},
	},
	{ # 12
		"title": "Re d'Italia",
		"minutes": "10",
		"setup": {"gold": 1500, "faith": 150, "army": {Defs.FANTE: 18, Defs.BALESTRIERE: 8, Defs.CAVALIERE: 4, Defs.CATAPULTA: 2}, "owners": {4: 1, 5: 4, 7: 5}, "pnames": {1: "il Marchese di Bologna", 4: "il Signore di Firenze", 5: "il Re di Roma"}, "ai": [1, 4, 5], "aggr": 0.6, "cap": 0.3, "guards": {4: [5, 2, 0], 5: [5, 2, 0], 7: [5, 2, 0]}},
		"goal": {"kind": "capture", "castles": [4, 5, 7], "finale": true},
		"unlock": {"all": true},
		"intro": {
			"title": "Ultimo atto: il Conte vuole l'Italia. Tutta, compresi i pezzi in mare",
			"sub": "Ogni castello della regione va preso. La suocera ha già prenotato un posto al banchetto, per sicurezza",
			"side": [
				"Il sarto prende le misure per la corona. Il Conte chiede una taglia in più",
				"Le casate firmano un'alleanza contro il Conte. Poi litigano su chi firma per primo",
				"La vacca del capitolo uno è ancora capo di stato maggiore",
			],
		},
		"win": {
			"title": "Il Conte è re d'Italia. La suocera: «Vedremo»",
			"sub": "Incoronato sullo scudo, banchetto sotto le stelle. Il Podestà di Bologna manda gli auguri, dal gabinetto",
			"side": [
				"La vacca nominata ministro di tutto",
				"Il geometra di Firenze progetta il nuovo palazzo reale. A occhio",
				"Prossima impresa del re: convincere la suocera",
			],
		},
		"lose": {
			"title": "L'Italia resiste al Conte. Per ora",
			"sub": "Il Conte torna a Borgo Spigolo, si siede sul gabinetto e medita il prossimo piano",
		},
	},
]


## setup: gold, faith (fiorini e Fede iniziali), army (soldati del Conte davanti al castello), owners (castello → casata;
## gli altri sono liberi), pnames (nomi buffi delle casate nemiche), guards (castello → [fanti, balestrieri, cavalieri]),
## ai (casate nemiche che giocano da sole), aggr (quanto attaccano), cap (quanto esercito possono avere, 1 = normale), attack (ondate mandate contro Borgo Spigolo:
## house, units, at = secondo della prima, every = ogni quanto, times = quante), hints (suggerimenti passo passo).
## goal: capture (castles), survive (secs), waves (respingi tutte le ondate), faith (amount), hold (castles, secs).
## La casata del Conte: blu, come i Savoia (i Savoia non giocano nella storia).
const HERO_HOUSE := 0


## Tutto ciò che è sbloccato fino alla missione n (1-12) compresa.
static func unlocked_at(n: int) -> Dictionary:
	var u := {"units": [], "defense": [], "build": [], "powers": [], "groups": false, "faith": false, "special": false, "events": false, "taunts": false, "all": false}
	for k in clampi(n, 0, MISSIONS.size()):
		var m: Dictionary = MISSIONS[k].unlock
		for key: String in m:
			if u[key] is Array:
				for x: Variant in m[key]:
					if not x in u[key]:
						(u[key] as Array).append(x)
			else:
				u[key] = m[key]
	return u
