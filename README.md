# Signori d'Italia

RTS multiplayer in tempo reale in Godot 4.7: Italia medievale in voxel, castelli distruttibili con crolli fisici, superpoteri assurdi. Mondo e soldati sono generati da codice. I suoni sono file CC0 (Kenney e OpenGameArt) in `assets/sfx`, con origine e licenza di ognuno in `assets/sfx/CREDITS.md`. Se ne manca uno, resta quello sintetizzato.

## Come si gioca

Apri la cartella con Godot 4.7 e premi Play, oppure:

```bash
GODOT="/Applications/Godot 2.app/Contents/MacOS/Godot"
"$GODOT" --path .                                # menu
"$GODOT" --path . -- --tutorial --house 1        # partita guidata passo passo
"$GODOT" --path . -- --solo --house 1            # subito contro l'IA
"$GODOT" --headless --path . -- --server         # server dedicato
"$GODOT" --path . -- --connect 192.168.1.10      # entra in una partita
"$GODOT" --path . -- --scena-re                 # solo la scena del re sul gabinetto, a ripetizione
```

Casate (`--house`): 0 Savoia, 1 Visconti, 2 Serenissima, 3 Doria, 4 Medici, 5 Papato, 6 Angioini, 7 Normanni.

**Online:** chi ospita apre la porta UDP 27015 sul router. Sulla stessa rete locale basta l'IP. Si può entrare a partita iniziata: si prende il posto dell'IA di una casata; chi esce viene rimpiazzato dall'IA.

### Comandi

| Tasto | Azione |
|---|---|
| WASD / frecce, mouse sul bordo, rotella | Muovi la vista, zoom |
| Q / E, tasto centrale | Ruota la vista |
| Clic sinistro (anche trascinando) | Seleziona truppe o castello |
| Clic destro | Muovi e attacca. Su un muro nemico, catapulte e bombarde lo bersagliano |
| T / Spazio | Tutta l'armata, frati esclusi / torna al castello |
| 1-5 | Poteri, poi clic sul bersaglio |
| 6-0 | Sfottò agli avversari |
| G, R, M, O | Sul castello: balestrieri sulle mura, ripara, mangano, olio bollente |
| Esc | Annulla, poi pausa: salva, impostazioni, esci |
| F1 | Guida ed esci al menu |

### Regole

Recluta dal castello con i fiorini, porta l'armata al nemico ed entra nel cortile: il castello è tuo quando uccidi il re, che sta nel mastio seduto sul gabinetto. Se nessuno lo colpisce per qualche secondo si riprende. Vince chi prende tutti i 12 castelli. Le truppe attraversano il mare in barca.

**Assedio.** Le mura hanno un vero supporto strutturale: ciò che si stacca dal terreno cade come corpo rigido e schiaccia ciò che colpisce. La fanteria cerca la strada più breve, passa dalle brecce appena si aprono e altrimenti abbatte la porta.

**Difesa.** Torri e mastio tirano da soli (prima alle macchine d'assedio) finché reggono; il mangano del mastio tira da solo dove i nemici sono ammassati e l'olio bollente cade da solo su chi si accalca sotto le mura; balestrieri sulle mura con +35% di gittata; riparazione a 0,5 fiorini per blocco; mangano sul mastio; olio bollente.

**Nessuno è al sicuro.** L'IA sceglie il bersaglio più vicino, ma un castello che nessuno disturba da più di 2 minuti le sembra via via più vicino (fino a un terzo della distanza dopo 8 minuti). Così anche Palermo, sola sull'isola, prima o poi riceve visite.

**Tregua.** Nei primi minuti le casate non si combattono fra loro: niente scontri fra soldati, le torri non sparano, niente poteri né mangano sulle altre casate, e i loro castelli e botteghe non si attaccano. Le IA in tregua non attaccano nessuno; chi gioca può già prendersi i castelli liberi.

**Si deve ridere.** Ogni tre-quattro minuti, dopo la tregua, arriva un evento a sorpresa con titolone e squillo: la *Sagra della Porchetta* (un banco con il maiale allo spiedo spunta dove c'è più gente in campo e tutti, di ogni casata, mollano la battaglia per mangiare: chi è a tavola non si tocca), lo *Sciopero* (il tipo di soldato più numeroso della casata in testa si siede e non obbedisce), *È pronto in tavola!* (metà armata in campo della casata in testa corre a casa dalla mamma) la *Processione del Patrono* (25 secondi senza poteri per nessuno), il *Palio* (tutti i cavalieri in campo corrono a un traguardo lontano: il primo vince 200 fiorini) e la *Scomunica* (la casata in testa resta senza Fede per 40 secondi). Davanti a una forma di Parmigiano i soldati scappano urlando, dritti davanti alla forma come nei cartoni; chi prende un castello balla. I soldati parlano con i fumetti quando caricano, quando sono feriti, quando sono ubriachi o alla sagra; i frati russano. Con i tasti 6-0 (o i pulsanti sopra la minimappa) si mandano sfottò a tutti, uno ogni 15 secondi; anche l'IA sfotte quando conquista.

**Botteghe e Fede.** Si parte senza niente: chiese e botteghe si costruiscono fuori dalle mura, vicino a un proprio castello (pannello del castello → scheda «Costruzioni», poi clic sul terreno: verde si può, rosso no). Il cantiere cresce strato dopo strato, dalle fondamenta al tetto, come una riparazione. Davanti alle porte e attorno alle mura resta sempre spazio per passare. Ogni potere funziona solo se hai la sua bottega in piedi: Caseificio → Parmigiano, Cantina → Vino, Torre dell'Astrologo → Terremoto, Santuario → Scudo, Stalla → Mucche. Gli edifici restano di chi li ha costruiti e si abbattono: clic destro con i soldati sopra un edificio nemico (fanti e nonne lo prendono a colpi, catapulte e bombarde lo bersagliano), e chi lo perde perde il vantaggio. La Fede arriva solo dalle chiese: ognuna ne dà un po', e ogni frate che le prega davanti (fino a 6) ne aggiunge. Più chiese, più Fede. Sopra ogni edificio c'è la sua insegna col colore del padrone.

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
"$GODOT" --path . -s tests/ui_flow.gd -- CARTELLA     # end-to-end con mouse e tastiera sintetici
"$GODOT" --path . -s tests/tutorial_flow.gd -- CARTELLA  # il tutorial giocato dall'inizio alla fine
"$GODOT" --path . -- --demo --shots CARTELLA          # assedio con screenshot e FPS
tests/net_test.sh                                     # server + 2 client: mondi identici byte per byte
"$GODOT" --headless --path . -s tests/stuck.gd -- --seed 1   # truppe incastrate in una partita tra IA (limite 1%)
"$GODOT" --headless --path . -s tests/pressure.gd -- --seeds 3 --min 30   # quanto è attaccato ogni castello (nessuno deve restare a zero)
"$GODOT" --path . -s tests/save_flow.gd -- CARTELLA      # pausa, salva, torna al menu, continua: mondo identico
"$GODOT" --path . -s tests/menu_shots.gd -- CARTELLA      # il menu principale sull'Italia in voxel
"$GODOT" --path . -s tests/shops_shots.gd -- CARTELLA     # le sei botteghe, i loro personaggi e il menu
"$GODOT" --path . -s tests/fun_shots.gd -- CARTELLA       # sagra, fumetti, sciopero, sfottò
"$GODOT" --path . -s tests/menu_panels.gd -- CARTELLA     # caricamento, menu, impostazioni, pausa
"$GODOT" --headless --path . -s tests/castle_map.gd -- Roma 313,397   # mappa percorribile di un castello, X = punti
```
