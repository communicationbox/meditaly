# Signori d'Italia

RTS multiplayer in tempo reale in Godot 4.7: Italia medievale in voxel, castelli distruttibili con crolli fisici, superpoteri assurdi. Mondo e soldati sono generati da codice. I suoni sono file CC0 (Kenney e OpenGameArt) in `assets/sfx`, con origine e licenza di ognuno in `assets/sfx/CREDITS.md`. Se ne manca uno, resta quello sintetizzato.

## Come si gioca

Apri la cartella con Godot 4.7 e premi Play, oppure:

```bash
GODOT="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT" --path .                                # menu
"$GODOT" --path . -- --missione 1                # la storia, dalla missione indicata (1-12)
"$GODOT" --path . -- --tutorial --house 1        # partita guidata passo passo
"$GODOT" --path . -- --solo --house 1            # subito contro l'IA
"$GODOT" --headless --path . -- --server         # server dedicato
"$GODOT" --path . -- --ospita --house 1          # ospita: sala d'attesa, poi «Avvia la partita»
"$GODOT" --path . -- --connect 192.168.1.10      # entra in una partita
"$GODOT" --path . -- --scena-re                 # solo la scena del re sul gabinetto, a ripetizione
"$GODOT" --path . -- --finale --house 4          # solo il finale di chi vince, a ripetizione
```

Casate (`--house`): 0 Savoia (Torino), 1 Visconti (Milano), 2 Serenissima (Venezia), 3 Superba (Repubblica di Genova), 4 Fiorentini (Repubblica di Firenze), 5 Papato (Roma), 6 Angioini (Napoli), 7 Aragonesi (Palermo), 8 Ruffo (Cosenza).

L'Italia è quella del 1350, l'anno della Gazzetta. Oltre alle casate ci sono le signorie minori che contano, che non giocano ma tengono i loro castelli finché qualcuno non li prende: gli Este a Ferrara, i Malatesta ad Ancona, il Giudicato d'Arborea a Oristano e la Corona d'Aragona a Cagliari. Bari resta un Comune libero. Ogni signoria ha il suo carattere: gli **Este** vendono Ferrara (400 fiorini, pulsante «Compra» nel pannello del castello: si entra senza combattere, e l'IA ogni tanto ci prova), i **Malatesta** sono voltagabbana (Ancona si arrende a chi arriva con un'armata di almeno 15 soldati e tre volte la guarnigione), il **Giudice d'Arborea** manda 40 fiorini ogni 2 minuti a chi lascia in pace la Sardegna da almeno 5 minuti. Le posizioni sono vicine al vero ma non esatte: la pianura non deve diventare troppo fitta, quindi al nord fra due castelli restano almeno 139 voxel, e Bologna, Modena, Verona, Mantova, Padova e Rimini non ci sono.

**Modalità** (menu, sotto «Casate uguali»): *Conquista* (tutti i castelli), *A tempo* (45 minuti: vince chi ha più castelli, a parità l'esercito più grande) e *Palio* (il Drappo sta su un castello e ogni 4 minuti si sposta lontano dagli ultimi posti dove è stato, così passa vicino a tutti: chi tiene quel castello fa un punto al secondo e vince il primo a 600). Storia e tutorial sono sempre Conquista.

**Musica:** taverna tranquilla nel menu, tre brani allegri a rotazione in partita, fanfara di tuba e banchetto per chi vince. Brani CC0 in `assets/music` (crediti in `assets/music/CREDITS.md`); si spegne dalle impostazioni.

**Online:** chi ospita apre la porta UDP 27015 sul router. Sulla stessa rete locale basta l'IP. Chi ospita entra in una sala d'attesa: la mappa c'è ma il tempo è fermo, e una scheda mostra chi è collegato e chi è pronto. Chi entra preme «Sono pronto»; quando lo sono tutti, chi ospita preme «Avvia la partita» e si parte insieme. In sala d'attesa si cambia casata cliccando uno stemma libero. In partita Invio apre la chat. Chi cade e rientra con lo stesso nome riprende la sua casata. Chi ospita può salvare dalla pausa: dal menu, «Riprendi la partita in rete» riapre la sala d'attesa e ognuno, rientrando con il suo nome, ritrova la sua casata. Si può entrare a partita iniziata: si prende il posto dell'IA di una casata; chi esce viene rimpiazzato dall'IA.

### Comandi

| Tasto | Azione |
|---|---|
| WASD / frecce, mouse sul bordo, rotella | Muovi la vista, zoom |
| Q / E, tasto centrale | Ruota la vista |
| Clic sinistro (anche trascinando) | Seleziona truppe o castello |
| Doppio clic / Ctrl+clic su un soldato | Tutti i soldati di quel tipo sullo schermo |
| Clic destro | Muovi e attacca. Su un muro nemico, catapulte e bombarde lo bersagliano |
| T o F2 / Spazio | Tutta l'armata, frati esclusi / torna al castello |
| Ctrl+1-0 / Maiusc+1-0 / 1-0 | Crea un gruppo (soldati o castello) / aggiungi / riprendilo; due volte porta la vista lì |
| Tab (Maiusc: indietro; va anche Backspace) | Il prossimo tuo castello, selezionato e inquadrato |
| Clic destro con un tuo castello selezionato | Punto di raduno: la nonna mette su il pentolone e le reclute di quel castello vanno lì. Clic destro sul castello stesso lo spegne |
| P | Spegni il pentolone di raduno del castello selezionato |
| Z X C V B | Poteri (Parmigiano, Vino, Terremoto, Scudo, Mucche), poi clic sul bersaglio |
| F | Potere della casata |
| G, R, M, O | Difesa del castello selezionato: balestrieri sulle mura, ripara tutto, mangano, olio bollente |
| Esc | Annulla, poi pausa: salva, impostazioni, esci |
| F1 | Guida ed esci al menu |

### Storia

*L'ascesa del Conte di Borgo Spigolo*: 12 missioni brevi (da 2 a 10 minuti) raccontate dalla Gazzetta del Trecento, che apre e chiude ogni missione. Il Conte (casata blu) parte da Borgo Spigolo, cioè Ancona, con i soli fanti. Ogni missione sblocca un pezzo di gioco e l'interfaccia cresce con lei: ciò che non è ancora sbloccato non si vede e non si comanda. La prima missione insegna a giocare passo passo. Le missioni si aprono una dopo l'altra e restano salvate (`impostazioni.cfg`, sezione `storia`). Testi, sblocchi, preparazione e obiettivi sono in `scripts/campaign.gd`, la logica in `scripts/mission.gd`.

### Regole

Recluta dal castello con i fiorini, porta l'armata al nemico ed entra nel cortile: il castello è tuo quando uccidi il re, che sta nel mastio seduto sul gabinetto. Se nessuno lo colpisce per qualche secondo si riprende. Vince chi prende tutti i castelli: chi vince si guarda il finale, con il re portato in trionfo sullo scudo e il banchetto sotto le stelle. Le truppe attraversano il mare in barca.

**Limite di truppe.** Si possono avere 40 soldati più 20 per ogni castello tenuto, fino a 240; contano anche quelli in coda. Il limite vale per tutto: reclute, milizia, cugini e soldati comprati con la mazzetta. Chi perde castelli tiene i soldati che ha, ma non ne recluta altri finché non torna sotto il limite.

**Assedio.** Le mura hanno un vero supporto strutturale: ciò che si stacca dal terreno cade come corpo rigido e schiaccia ciò che colpisce. La fanteria cerca la strada più breve, passa dalle brecce appena si aprono e altrimenti abbatte la porta.

**Difesa.** Torri e mastio tirano da soli (prima alle macchine d'assedio) finché reggono; il mangano del mastio tira da solo dove i nemici sono ammassati e l'olio bollente cade da solo su chi si accalca sotto le mura; balestrieri sulle mura con +35% di gittata; «Ripara tutto»: si paga subito 0,5 fiorini per blocco mancante e i muratori ricostruiscono 40 blocchi al secondo (10 sotto attacco), con l'avanzamento sul pulsante; finché non hanno finito non si riclicca; mangano sul mastio; olio bollente.

**Nessuno è al sicuro.** L'IA sceglie il bersaglio più vicino, ma un castello che nessuno disturba da più di 2 minuti le sembra via via più vicino (fino a un terzo della distanza dopo 8 minuti). Così anche Palermo, sola sull'isola, prima o poi riceve visite.

**Tregua.** Nei primi minuti le casate non si combattono fra loro: niente scontri fra soldati, le torri non sparano, niente poteri né mangano sulle altre casate, e i loro castelli e botteghe non si attaccano. Le IA in tregua non attaccano nessuno; chi gioca può già prendersi i castelli liberi.

**Si deve ridere.** Ogni tre-quattro minuti, dopo la tregua, arriva un evento a sorpresa con titolone e squillo: la *Sagra della Porchetta* (un banco con il maiale allo spiedo spunta dove c'è più gente in campo e tutti, di ogni casata, mollano la battaglia per mangiare: chi è a tavola non si tocca), lo *Sciopero* (il tipo di soldato più numeroso della casata in testa si siede e non obbedisce), *È pronto in tavola!* (metà armata in campo della casata in testa corre a casa dalla mamma) la *Processione del Patrono* (25 secondi senza poteri per nessuno), il *Palio* (tutti i cavalieri in campo corrono a un traguardo lontano: il primo vince 200 fiorini) e la *Scomunica* (la casata in testa resta senza Fede per 40 secondi). Davanti a una forma di Parmigiano i soldati scappano urlando, dritti davanti alla forma come nei cartoni; chi prende un castello balla. I soldati parlano con i fumetti quando caricano, quando sono feriti, quando sono ubriachi o alla sagra; i frati russano. Con i pulsanti sopra la minimappa si mandano sfottò a tutti, uno ogni 15 secondi; anche l'IA sfotte quando conquista.

**Botteghe e Fede.** Si parte senza niente: chiese e botteghe si costruiscono fuori dalle mura, vicino a un proprio castello (pannello del castello → scheda «Costruzioni», poi clic sul terreno: verde si può, rosso no). Il cantiere cresce strato dopo strato, dalle fondamenta al tetto, come una riparazione. Davanti alle porte e attorno alle mura resta sempre spazio per passare. Ogni potere funziona solo se hai la sua bottega in piedi: Caseificio → Parmigiano, Cantina → Vino, Torre dell'Astrologo → Terremoto, Santuario → Scudo, Stalla → Mucche. Gli edifici restano di chi li ha costruiti e si abbattono: clic destro con i soldati sopra un edificio nemico (fanti e nonne lo prendono a colpi, catapulte e bombarde lo bersagliano), e chi lo perde perde il vantaggio. La Fede arriva solo dalle chiese: ognuna ne dà un po', e ogni frate che le prega davanti (fino a 6) ne aggiunge. Più chiese, più Fede. Sopra ogni edificio c'è la sua insegna col colore del padrone.

**Squadre.** Fanti e balestrieri si vedono in tre, i cavalieri in due: è solo grafica, per vita, danni, costo e rete resta un'unità sola, e i compagni cadono man mano che la vita scende.

**Unità buffe.** Frate (prega, si recluta solo dove c'è la chiesa), Nonna (lenta, col mattarello fortissima), Menestrello (canta così male che i nemici vicini fanno il 30% di danni in meno).

## Struttura

| File | Ruolo |
|---|---|
| `scripts/defs.gd` | **Bilanciamento**: unità, poteri, casate, castelli, coste dell'Italia |
| `scripts/voxel_world.gd` | Griglia voxel, meshing su thread, supporto strutturale, collisioni pigre |
| `scripts/world_gen.gd` | Generazione deterministica: Italia, castelli, borghi, monumenti |
| `scripts/sim.gd` | Simulazione autoritativa (solo server): unità, assedi, poteri, economia, IA |
| `scripts/game.gd` | Rete (ENet) e flusso di partita |
| `scripts/unit_models.gd`, `unit_renderer.gd` | Modelli voxel e rendering a MultiMesh con animazione nello shader |
| `scripts/buildings.gd`, `king_stage.gd` | Botteghe in voxel; set della scena del re |
| `scripts/fx.gd`, `sfx.gd`, `fragment.gd` | Detriti e proiettili, audio (file CC0 con varianti a caso, sintetizzato di riserva), corpi rigidi dei crolli |
| `scripts/controller.gd`, `hud.gd`, `menu.gd` | Input e telecamera, interfaccia, menu |

Il server è autoritativo: i client inviano comandi validati e ricevono snapshot delle unità (10 Hz) e le modifiche esplicite ai voxel su canale affidabile. I detriti e la caduta dei frammenti sui client sono solo estetici; gli effetti sul gioco li decide il server.

## Test

```bash
"$GODOT" --headless --path . -s tests/rules.gd        # regole: conquista, vittoria, crateri, riparazioni
"$GODOT" --headless --path . -s tests/campaign.gd     # storia: elenco, giornali, sblocchi missione per missione, vittorie e progressi
"$GODOT" --headless --path . -s tests/news_skip.gd     # contro l'IA il giornale si chiude subito (pulsante, Spazio, Esc, Invio)
"$GODOT" --headless --path . -s tests/controls.gd     # gruppi, Tab, tasti dei poteri, squadre, pannello difesa (senza finestra)
"$GODOT" --headless --path . -s tests/campaign_bot.gd -- 10   # un bot gioca la missione (1-12) a 6x: raduno, arieti, poteri
"$GODOT" --headless --path . -s tests/ui_flow.gd -- CARTELLA   # end-to-end con mouse e tastiera sintetici (senza finestra niente foto)
"$GODOT" --path . -s tests/tutorial_flow.gd -- CARTELLA  # il tutorial giocato dall'inizio alla fine
"$GODOT" --path . -- --demo --shots CARTELLA          # assedio con screenshot e FPS
tests/net_test.sh                                     # server + 2 client: mondi identici byte per byte
tests/lobby_net.sh                                    # chi ospita aspetta, l'amico dice «pronto», si parte
"$GODOT" --headless --path . -s tests/lobby.gd        # sala d'attesa: tempo fermo, Avvia solo con tutti pronti, casate, chat, rientro
"$GODOT" --headless --path . -s tests/net_resume.gd   # partita in rete salvata e ripresa: ognuno ritrova la sua casata
"$GODOT" --headless --path . -s tests/stuck.gd -- --seed 1   # truppe incastrate in una partita tra IA (limite 1%)
"$GODOT" --headless --path . -s tests/pressure.gd -- --seeds 3 --min 30   # quanto è attaccato ogni castello (nessuno deve restare a zero)
"$GODOT" --headless --path . -s tests/matchups.gd     # scontri a parità di fiorini: le picche fermano i cavalieri, l'IA risponde
"$GODOT" --headless --path . -s tests/knight_rush.gd -- --games 9 --min 20   # una casata fa solo cavalieri: non deve vincere sempre
"$GODOT" --path . -s tests/save_flow.gd -- CARTELLA      # pausa, salva, torna al menu, continua: mondo identico
"$GODOT" --path . -s tests/menu_shots.gd -- CARTELLA      # il menu principale sull'Italia in voxel
"$GODOT" --path . -s tests/finale_shots.gd -- CARTELLA    # il finale di chi vince, inquadratura per inquadratura
"$GODOT" --path . -s tests/shops_shots.gd -- CARTELLA     # le sei botteghe, i loro personaggi e il menu
"$GODOT" --path . -s tests/rally_shots.gd -- CARTELLA     # pentolone di raduno, reclute che ci vanno, signorie minori
"$GODOT" --path . -s tests/fun_shots.gd -- CARTELLA       # sagra, fumetti, sciopero, sfottò
"$GODOT" --path . -s tests/menu_panels.gd -- CARTELLA     # caricamento, menu, impostazioni, pausa
"$GODOT" --headless --path . -s tests/castle_layout.gd  # castelli sulla terraferma, distanziati, signorie minori
"$GODOT" --headless --path . -s tests/castle_map.gd -- Roma 313,397   # mappa percorribile di un castello, X = punti
```

## Debug

In una partita lanciata dall'editor o da una versione di debug, il tasto `-` apre il pannello per far partire gli eventi e le uscite di scena del re. Nelle versioni finite non si apre.
