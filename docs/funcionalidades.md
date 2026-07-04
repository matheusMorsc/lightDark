# Funcionalidades — Light in the Dark

> Catálogo completo do que já está **implementado e jogável**, organizado por
> sistema. Não é roadmap nem estado de tarefas — pra isso, ver
> `PROJECT_STATUS.md` (handoff rápido) e `docs/plano-2-anos.md` (roadmap +
> decisões de design). **Regra: sempre que uma funcionalidade nova entrar no
> jogo, atualizar este arquivo na mesma sessão.**

Última atualização: 2026-07-04 (interação por E nas estações — craft filtrado por estação).

---

## Movimento e combate

- Movimento 8-direcional (WASD ou setas), perspectiva pseudo-isométrica
  estilo Don't Starve: 2D puro, achatamento vertical (passo pra cima/baixo
  cobre menos tela que um passo lateral).
- Ataque de alvo único (Espaço ou clique esquerdo): entre tudo que está na
  área de ataque, escolhe o melhor por distância + alinhamento com a
  direção encarada, com leve prioridade a inimigos sobre coleta. Acerta
  qualquer coisa com método `hit()` — inimigos, boss, nós de recurso, props
  quebráveis do dungeon. Esse é o moveset padrão (sem arma, com ferramenta
  de coleta, ou com a Espada da Forja) — Lança e Martelo mudam o golpe
  inteiro, ver "Armas com moveset próprio" abaixo.
- Hit-stop de 50ms no acerto + fagulhas de partícula — dá peso ao golpe.
- Knockback nos inimigos comuns ao levarem dano.
- **Barra de vida flutuante + número de dano (registrado jul/2026, pedido
  do usuário)**: todo inimigo comum (`entities/enemy.gd`) ganhou uma barra
  de vida fininha acima da cabeça (`_draw()`, redesenhada via
  `queue_redraw()` a cada mudança de `health` — hit, regen do afixo
  "regenerating", cura do afixo "vampiric"), mesma receita que o Boss já
  usava sozinho (`boss.gd::_draw()`, só maior). Todo golpe (jogador
  acertando inimigo/boss) também mostra um número vermelho "-N" subindo e
  sumindo no ponto do acerto — `entities/damage_numbers.gd`
  (`class_name DamageNumbers`), função estática sem estado (mesmo padrão do
  `PlaceholderIcons`) chamada de dentro de `enemy.gd::hit()` e
  `boss.gd::hit()`, então reduções de dano (afixo "shielded") já aparecem
  com o valor CERTO (pós-redução), não o bruto.
- **Dash (Shift)**: impulso instantâneo, sem telegraph, ~0.16s de duração,
  cooldown de 0.7s, sem custo de recurso. Direção = movimento que estiver
  segurando, ou o último facing se estiver parado. Concede invencibilidade
  (`GameState.invulnerable`, flag genérica) durante o impulso. Sem animação
  própria (reaproveita a animação de walk + rajada de partículas na saída).
- **"Ataque rápido"** (registrado jul/2026): o ataque normal (Espaço/clique)
  já NÃO é mais bloqueado durante o dash — dá pra atacar no meio do impulso,
  ou numa janela curta (`DASH_ATTACK_GRACE = 0.15s`) logo depois dele.
  Nessa janela o alcance do golpe cresce bastante (`QUICK_ATTACK_MAX_DIST =
  110`, contra `ATTACK_MAX_DIST = 64` normal — a `CollisionShape2D` da
  `AttackArea` já é fisicamente maior pra suportar isso, ver `player.tscn`);
  continua sendo alvo único, só fica bem mais fácil de conectar num inimigo
  que você acabou de passar correndo.
- **Ataque especial em área (Q)** (registrado jul/2026, roteado por arma
  desde jul/2026 — antes era genérico igual pra qualquer arma): dano é
  sempre instantâneo (aplicado no frame em que Q é apertado) e sempre
  acerta TODOS os alvos, ao contrário do ataque normal (alvo único). Só
  funciona com uma arma equipada (`ItemDef.weapon_damage_bonus > 0` — ver
  abaixo); com machado/picareta equipados não faz nada. Cooldown de 2.5s
  (`SPECIAL_ATTACK_COOLDOWN`) pra não virar o ataque padrão — é um "nuke"
  ocasional. Não funciona durante o dash (diferente do ataque normal, que
  agora funciona). Versão por arma (`player.gd::_special_attack`, ver
  `ItemDef.weapon_type`):
  - **Espada**: giro em círculo ao redor do jogador
    (`SPECIAL_ATTACK_RADIUS = 100`); visual — anel se expandindo — é o
    mesmo do ataque "Pancada" do Boss da dungeon
    (`boss.gd::_do_slam`/`_draw`), só que aqui é puramente cosmético e toca
    DEPOIS do dano, não antes.
  - **Lança**: em vez do círculo, vira um cone/linha bem mais longo que o
    golpe normal dela (`SPECIAL_LANCE_RANGE = 220` contra
    `LANCE_RANGE = 130`) — o "nuke" dela é alcance absurdo numa linha, não
    área ao redor do jogador. Flash retangular maior e com o tom
    avermelhado do especial (diferente do branco neutro do golpe normal).
  - **Martelo**: mantém o mesmo círculo da Espada, mas SEMPRE atordoa quem
    for atingido (`SPECIAL_HAMMER_STUN_DURATION = 1.6s`) — reforça a
    identidade dele (controle) em vez de introduzir mecânica nova, já que
    o golpe normal do martelo também atordoa.
- Facing de 4 direções com animações idle/walk/attack/death próprias por
  direção.
- Cursor do mouse troca sozinho conforme o que está embaixo dele: espada
  sobre inimigo, picareta sobre recurso, seta normal no resto (só visual —
  o jogo é 100% controlado por teclado).
- **Dano do ataque é fixo por padrão** (`player.attack_damage`, 10 hoje) —
  machado e picareta NÃO davam bônus de dano até agora. **Armas puras**
  (registrado jul/2026, `ItemDef.weapon_damage_bonus`) mudam isso: um item
  categoria TOOL sem `tool_type` (não serve pra colher nada) que soma dano
  fixo enquanto equipado — reaproveita a seleção por hotbar de "uma
  ferramenta ativa por vez" (ver "Coleta e ferramentas" acima), então lutar
  com a arma custa não poder colher ao mesmo tempo. Primeira arma: **Espada
  da Forja** (+15 de dano — mais que dobra o ataque base de 10, e libera o
  ataque especial em área), craftada só perto da Forja.
- **Armas com moveset próprio** (registrado jul/2026, `ItemDef.weapon_type`,
  ver `player.gd::_attack`): Espada continua alvo único; duas armas novas
  mudam o golpe inteiro, não só o número de dano — todas craftadas só perto
  da Forja, mesmo custo em minério/madeira que a Espada:
  - **Lança da Forja** (+10 de dano por alvo, `weapon_type = "lanca"`):
    PERFURA — acerta TODOS os alvos numa linha reta na frente (retângulo
    130×26), não só o mais próximo. Sem stun, sem cooldown extra: a força
    dela é acertar uma fileira inteira de inimigos alinhados, não o dano
    isolado.
  - **Martelo da Forja** (+25 de dano por alvo, `weapon_type = "martelo"`):
    hitbox larga (raio 75) centrada na AttackArea — acerta todos ali, não
    só um — e ATORDOA cada alvo por 1.2s (`Enemy.stun()`, novo método:
    inimigo atordoado não persegue, não ataca, só sofre knockback). Em
    troca, o golpe seguinte demora `HAMMER_EXTRA_COOLDOWN = 0.35s` a mais
    — menos dano por segundo que a Espada, mas controla a luta. Boss e nós
    de recurso não têm `stun()`, então são imunes de graça (sem gambiarra
    de exceção no código — só não respondem à chamada).
  - As duas também podem ser usadas durante o dash (a restrição foi
    removida pro "ataque rápido" — ver acima), mas não ganham o alcance
    extra desse recurso: só a Espada tem esse modo "rápido"; Lança e
    Martelo sempre usam seu próprio golpe fixo, goste ou não do alcance
    normal.
  - **Ícones geométricos próprios** (registrado jul/2026, `items/
    placeholder_icons.gd`): as 3 armas reaproveitavam o mesmo
    `recipe_tool.png` genérico e ficavam idênticas no inventário — bem
    ruim justo quando o moveset de cada uma é diferente. Agora cada uma
    gera seu próprio ícone 32×32 em runtime (retângulos coloridos: Espada
    = lâmina fina + guarda larga, Lança = cabo comprido + ponta triangular
    fina, Martelo = cabeça grande e pesada + cabo curto) via
    `PlaceholderIcons.weapon_icon()`, chamado por `ItemDB._ready()` só
    quando o `.tres` do item deixa `icon` vazio. Sem depender de arquivo
    `.png` novo (escrever binário no projeto não é confiável neste
    ambiente) — quando a arte de verdade chegar, basta setar `icon` no
    `.tres` que o placeholder para de ser usado sozinho.
  - **Flash geométrico no golpe** (registrado jul/2026, `player.gd::_draw`):
    o `AnimatedSprite2D` do jogador é sempre o mesmo swing do "Swordsman",
    não importa a arma equipada (sem frames próprios pra Lança/Martelo
    ainda) — sem isso, lançar ou martelar "parecia" sempre um golpe de
    espada. Agora cada uma soma um efeito visual rápido no momento do golpe,
    desenhado por cima do sprite, com formato igual à própria hitbox: Lança
    = retângulo comprido na frente (130×26, some em 0.15s), Martelo = anel
    largo se expandindo na AttackArea (raio 75, some em 0.2s) — bem mais
    rápido que o anel do especial (Q), que é 0.35s: aqui é feedback de golpe
    normal, não telegraph. A Espada continua só com a animação de swing, sem
    efeito extra (não precisa — é a única com sprite de golpe próprio).

## Vida, fome e morte

- Vida e fome, ambas com máximo de 100. Fome drena 0.3/s; fome zerada causa
  3 de dano/s (fome é sobrevivência, não HP extra).
- **Morte unificada**: em qualquer lugar (base ou run), toast + 2s de
  espera → acorda em casa com 50% de vida e fome reposta a pelo menos 50%.
  O save nunca é apagado por morte — nem na base, nem numa run.
- Invulnerabilidade genérica (`GameState.invulnerable`) — hoje só o dash
  liga/desliga, mas qualquer sistema futuro pode usar o mesmo flag.

## Inventário e itens

- Hotbar de 10 slots — é uma grade real (não contador), empilha
  automaticamente até o máximo de cada item. Seleção por tecla 1..0,
  scroll do mouse ou clique no slot; selecionar uma ferramenta/arma já
  equipa, selecionar qualquer outra coisa desequipa (slot vazio, recurso
  ou comida — ver `GameState.select_slot`). **Comer mudou (jul/2026)**:
  não é mais automático no E; agora é clique direito do mouse, e só come
  o que estiver no slot selecionado no momento (nada de escanear o
  inventário atrás da primeira comida) — mesma lógica de "selecionar pra
  usar" que já valia pra ferramentas.
- **Contador de itens sem cortar (corrigido jul/2026)**: a caixinha "x99" no
  canto do slot (`ui/inventory_slot.tscn::CountLabel`) estava um pouco
  apertada — números de 2-3 dígitos (x75, x100...) cortavam a borda.
  Aumentada a área do label e reduzida a fonte 1pt de folga.
- Drag-and-drop entre slots: solta sobre outro item igual empilha (até o
  máximo, sobra fica no slot de origem), solta sobre item diferente troca
  de posição. O mesmo sistema funciona entre a hotbar e o baú (ver abaixo).
- Itens data-driven (`ItemDef` .tres em `items/defs/`) — 13 hoje:
  madeira, pedra, fibra, minério, essência (sem uso de coleta direta, só
  drop de boss), Cogumelo/comida (+25 fome), Refeição Reforçada (craftada,
  +60 fome / +30 vida), Machado I, Picareta I, Picareta II, Lanterna,
  Amuleto Vital (+25 vida máxima), Amuleto Vital II (+40 vida máxima).
- **Comer restaura o valor do PRÓPRIO item** (`ItemDef.hunger_restore`/
  `heal_amount`, cada comida com seu valor — Cogumelo só fome, Refeição
  Reforçada bem mais fome + cura). Uma tentativa anterior (jul/2026) de
  igualar tudo num valor fixo foi revertida a pedido do usuário — a
  variação entre comidas é querida; o que de fato incomodava era a ESCALA
  da barra de vida mudando (ver Amuleto Vital / item PASSIVO abaixo), não
  a comida.
- **Fome desce mais devagar (registrado jul/2026)**:
  `GameState.hunger_drain_per_second` reduzido de 0.3 pra 0.15 — de
  ~5.5min até zerar (fome cheia) pra ~11min.
- **Categoria PASSIVE + Amuleto Vital como item de verdade (registrado
  jul/2026)**: antes craftar Amuleto Vital era um efeito instantâneo sem
  item (somava direto em `GameState.max_health`, permanente, sem ligação
  com o inventário — se esquecesse o motivo, a vida máxima só crescia e
  nunca dava pra "ver" de onde vinha o bônus). Virou item físico
  (`ItemDef.category = PASSIVE`, `passive_bonus_max_health`): o bônus só
  vale enquanto o item existir em QUALQUER slot do inventário principal
  (não precisa estar selecionado, diferente de ferramenta/arma — só não
  pode estar guardado num baú). `GameState._recompute_passive_bonuses()`
  roda toda vez que o inventário muda e recalcula `max_health =
  BASE_MAX_HEALTH (100) + soma dos bônus ativos` — ganhar mostra um toast
  "Vida máxima aumentada em X" (mesmo padrão do toast de poção) e cura o
  mesmo tanto na hora; perder (dropar, guardar no baú) reduz o teto de
  volta e mostra "Vida máxima reduzida em X", sem dano extra. Resultado: a
  barra de vida sempre reflete o que você está carregando de verdade, sem
  crescer escondido.
- Categorias: recurso, ferramenta, comida, estrutura, passivo.

## Coleta e ferramentas

- Gating em cadeia: fibra e pedra são coletáveis à mão (arbustos e pedras
  soltas) → Machado I (4 fibra + 3 pedra) libera cortar árvores → madeira
  → Picareta I (2 madeira + 4 pedra) libera minerar minério.
- **Tier II é upgrade, não item solto** (registrado jul/2026): Machado II e
  Picareta II agora CONSOMEM a ferramenta Tier I correspondente + madeira +
  minério — craftar não deixa as duas versões ocupando espaço, troca uma
  pela outra. Só craftáveis perto da Forja (ver "Estações com função"
  abaixo). Ainda não existe nenhum nó de recurso que EXIJA tier 2 pra
  colher — o upgrade hoje é só sobre a arma equivalente ficar mais forte
  em combate (nenhuma, já que machado/picareta não causam dano — ver
  "Combate" abaixo); a gente que colhe com tier 2 é idêntica à tier 1.
- Nós de recurso exigem ferramenta EQUIPADA (tipo + tier mínimo) pra
  ceder loot; sem ela, escurecem e mostram aviso flutuante "Requer X".
- Drop tables por nó (chance/min/max independentes por entrada) — ex:
  arbusto sempre dropa 1–2 fibra e tem 35% de chance de dropar comida
  junto.
- **Equipar é selecionar na hotbar** (mudou jul/2026 — antes existia Q pra
  ciclar; removido): escolher um slot com uma ferramenta/arma (1..0, scroll
  ou clique no slot) equipa na hora, junto com virar o slot selecionado
  (`GameState.select_slot`, já fazia isso — Q era só um atalho redundante
  em cima do mesmo mecanismo). Armas puras (ver abaixo) entram no mesmo
  ciclo de seleção que machado/picareta, já que compartilham a categoria
  TOOL; equipar uma arma pra lutar melhor custa não poder colher ao mesmo
  tempo (decisão de design, não bug). Clique no slot é feito em
  `inventory_slot.gd::_gui_input`, só ativo quando `container == null` (a
  hotbar do jogador — no baú clicar não seleciona nada, não existe
  "selecionado" lá). Isso expôs uma pegadinha: o ataque do player lê estado
  bruto do mouse (`Input.is_mouse_button_pressed`), que não é filtrado por
  cima de UI — clicar num slot também "atacaria" se não fosse por um guard
  novo em `player.gd` (`get_viewport().gui_get_hovered_control() != null`
  cancela o clique de ataque quando o mouse está sobre qualquer Control).

## Crafting

- Painel de craft (C abre/fecha) se monta sozinho a partir das receitas
  cadastradas — nenhuma linha de UI hardcoded. **Clicável** (registrado
  jul/2026, mesmo motivo do painel de construção — ver "Construção"
  abaixo): cada linha virou um botão que crafta na hora, dentro de um
  `ScrollContainer` sem limite de altura. Antes, cada linha era só
  texto/ícone (sem clique) e a lista cortava nas primeiras 10 receitas
  (`RECIPE_KEYS.size()`) — ia sumir 2 receitas de verdade (Lanterna
  Avançada e Amuleto Vital II, ver "Estações com função") assim que
  passassem de 10 no total. Tecla 1..0 continua funcionando pras 10
  primeiras; a partir da 11ª só dá pra craftar clicando.
- Receitas hoje: Machado I, Machado II, Picareta I, Picareta II, Espada da
  Forja, Lança, Martelo, Lanterna (2 fibra + 2 madeira — luz pessoal bem
  mais forte enquanto no inventário), Lanterna Avançada (perto da Mesa de
  Pesquisa — consome 1 Lanterna, luz ainda mais forte), Refeição Reforçada
  (5 comida → 1 refeição), Amuleto Vital (perto da Mesa de Alquimia — 3
  essências → item real, +25 vida máxima enquanto estiver no inventário),
  Amuleto Vital II (perto da Mesa de Pesquisa — 6 essências → item real,
  +40 vida máxima), 3 poções (perto da Mesa de Alquimia — ver "Estações
  com função") e **Portal de Atalho** (8 essência — construído direto pelo C,
  sem passar pelo modo B).
- **Craft geral (C) só mostra o básico** (registrado jul/2026, a pedido do
  usuário): sem estação por perto (`required_station == ""`), o painel só
  lista Machado I, Picareta I, Lanterna e Refeição Reforçada — ferramentas
  Tier I + comida básica. Tier II (Machado/Picareta II, Espada/Lança/
  Martelo) e itens de efeito (Amuleto Vital, poções) sempre exigiram uma
  estação; **Amuleto Vital especificamente foi movido da lista geral pra
  Mesa de Alquimia** nesse mesmo pedido (antes craftava em qualquer lugar,
  ficando fora do padrão "nível 2 só nas mesas").
  **Bug real encontrado logo depois (mesmo dia, print do usuário)**: mover
  o Amuleto Vital pra `required_station` não tirou ele do painel geral —
  `_build_recipe_rows` só escondia receita de OUTRA estação quando a visão
  já estava FILTRADA (E numa estação); a visão geral (C) nunca filtrava
  nada, só acrescentava o texto "(perto de X)" e deixava craftar clicando
  mesmo longe (barrado só na hora, em `_try_craft`). Toda receita com
  estação — Amuleto Vital, Lanterna Avançada, Amuleto Vital II, as 3
  poções, até Lança/Martelo da Forja — continuava aparecendo no C geral.
  Corrigido trocando a condição por uma comparação direta
  (`r.required_station != _crafting_station_filter`): geral (filter == "")
  só mostra receita sem estação nenhuma; filtrado só mostra a da própria
  estação. O hint "(perto de X)" foi removido junto — ficou impossível de
  acontecer depois do fix.
- **Receitas com estação exigida** (`RecipeDef.required_station`, "" = em
  qualquer lugar): Machado II, Picareta II e Espada da Forja só craftam com
  uma Forja construída a ~200px (`hud.gd::_near_station`, mesmo raio e
  mesma ideia do `BuildMode._workbench_nearby`, mas medido a partir do
  jogador em vez do ghost). Sem a estação por perto, o painel mostra
  "Precisa estar perto da Forja" em vez de craftar. O painel de craft já
  lista isso na linha da receita (`"... (perto da Forja)"`).
- **Interação por E direto na estação** (registrado jul/2026, a pedido do
  usuário): chegar perto de uma Forja/Mesa de Pesquisa/Mesa de Alquimia e
  apertar E abre o painel de craft já FILTRADO só pelas receitas daquela
  estação — não precisa mais abrir o craft geral (C, mostra tudo) e caçar
  pelo texto "(perto de X)". E (não F) de propósito: F já é usado por
  baú/talismã/portais — usar a mesma tecla arriscaria entrar numa run sem
  querer se a estação estiver perto do Talismã. Mesmo padrão "só a mais
  próxima responde" do baú (`entities/structures/station_interact.gd`,
  reusado pelas 4 estações via `@export station_group/
  station_display_name` — Forja, Mesa de Pesquisa, Mesa de Alquimia E
  Workbench). Fechar é E de novo (ou C/ESC, que fecham qualquer variante
  do painel). **Workbench (ajuste jul/2026)**: o E nela lista **Baú Grande**
  e **Poste de Luz** como ações de **construção** (`[construir]`) e, ao
  clicar, já inicia o `BuildMode` focado nessas duas estruturas; o fluxo
  geral do B não mostra mais essas duas opções. O painel da Workbench
  também força refresh ao abrir, então upgrades recém-comprados já refletem
  imediatamente na lista. Achado no processo:
  `alchemy_table.tscn` também não tinha grupo nenhum atribuído (mesmo bug
  do `research_table.tscn`, ver "Estações com função" abaixo) — corrigido
  junto.

## Estações com função (registrado jul/2026)

- Antes, as 4 estações da branch Construção (Workbench, Forja, Mesa de
  Alquimia, Mesa de Pesquisa) só existiam como marco de progressão — nada
  de verdade exigia estar perto delas. Primeiro passo pra mudar isso:
  **Forja** dá acesso a receitas próprias (`RecipeDef.
  required_station = "forja"`, ver "Crafting" acima): Machado II, Picareta
  II e a Espada da Forja. **Workbench** (ajuste jul/2026) segue um padrão
  diferente — o E nela abre uma lista de construção de DUAS estruturas
  (`StructureDef.requires_workbench_nearby`,
  `required_upgrade_id = "constr_workbench"`): **Baú Grande** (40 slots) e
  **Poste de Luz** (alcance de luz bem maior que a Tocha). Essas duas ficam
  fora da lista geral do B e são iniciadas pela própria interação da
  Workbench — ver detalhes nas seções
  próprias abaixo. **Mesa de Pesquisa** (registrado jul/2026) volta ao
  padrão da Forja — receitas próprias (`required_station =
  "mesa_pesquisa"`): **Lanterna Avançada** (consome 1 Lanterna + 2
  essência + 4 fibra, alcance/energia de luz maiores — `player.gd::
  _update_lantern` agora checa os dois tiers) e **Amuleto Vital II**
  (6 essência, +40 HP permanente — igual ao Amuleto Vital original, só
  mais caro e mais forte, para quando a essência já não tem mais onde
  gastar). A cena `research_table.tscn` não tinha nenhum grupo atribuído
  até agora — sem isso `_near_station("mesa_pesquisa")` nunca teria
  encontrado a estrutura, mesmo com a receita certa (mesmo bug encontrado
  em `alchemy_table.tscn` logo depois). **Mesa de Alquimia** (registrado
  jul/2026): 3 poções (`required_station = "mesa_alquimia"`) que aplicam
  um multiplicador TEMPORÁRIO em vez de permanente — **Poção de
  Velocidade** (5 fibra + 2 comida, +35% velocidade, 60s), **Poção de
  Força** (4 minério + 2 comida, +30% dano, 60s) e **Poção de Proteção**
  (5 pedra + 3 fibra, -30% dano recebido, 60s). Craftar já é "beber" —
  efeito instantâneo, sem item passando pelo inventário, mesmo padrão do
  Amuleto Vital (`RecipeDef.potion_channel/potion_mult/potion_duration`,
  ver `hud.gd::_try_craft` → `GameState.apply_potion`). Beber a mesma
  poção de novo RENOVA os 60s, não empilha o multiplicador. Custos usam só
  recursos base (fibra/comida/minério/pedra) de propósito — essência fica
  reservada pra upgrades permanentes e Amuleto Vital/II, mantendo a
  separação temático entre moeda "permanente" e "consumível". `GameState`
  ganhou 3 canais fixos (`potion_speed_mult`/`potion_attack_mult`/
  `potion_defense_mult`) com timer próprio cada um (`_process` conta
  regressivamente, expira sozinho e emite `potion_expired` — o HUD mostra
  um toast tanto ao aplicar quanto ao expirar). Ordem de multiplicação
  confirmada: `base * mult_PERMANENTE (upgrade) * mult_POÇÃO (temporário)
  * mult_RUN (modificador de run)` — ver `player.gd::
  _current_attack_damage()`/velocidade. Sem ícone de frasco na arte do
  projeto ainda: as 3 poções usam um placeholder gerado em código
  (`PlaceholderIcons.potion_icon`, mesmo frasco, cor do líquido por canal)
  em vez de reaproveitar um ícone existente — ao contrário do Amuleto
  Vital (item único, sem ambiguidade), aqui são 3 itens que precisam ser
  diferenciáveis entre si no painel.
- Padrão pra estação nova ter função: um `.tscn` de estrutura recebe um
  grupo (`groups=["nome_da_estacao"]`, mesmo padrão já usado por
  `workbench.tscn`/`forge.tscn`); receitas ganham `RecipeDef.
  required_station` + `required_station_name` apontando pro mesmo grupo;
  `hud.gd::_near_station` checa a distância até a estrutura mais próxima
  desse grupo a partir do jogador. Nenhuma estrutura nova de código, só
  dado.

## Construção (base)

- B abre o modo construção: ghost segue o mouse com snap de 8px, fica
  verde/vermelho conforme validade (custo pago + dentro do alcance +
  espaço livre de colisão); clique esquerdo constrói e desconta os
  recursos na hora.
- Estruturas hoje no **modo B geral** (`items/structures/*.tres`, tecla 1..N
  escolhe no modo B):
  Cerca de Madeira (2 madeira), Fogueira (4 madeira + 2 pedra, ilumina),
  Tocha (1 madeira + 2 fibra, ilumina), **Baú** (6 madeira + 3 pedra,
  armazenamento), **Talismã** (8 madeira + 4 pedra, acesso à run),
  **Workbench** (8 madeira + 4 pedra), **Forja** (6 pedra + 4 minério),
  **Mesa de Alquimia** (6 madeira + 4 fibra), **Mesa de Pesquisa**
  (8 madeira + 6 pedra).
- Estruturas da **Workbench (E)**: **Baú Grande** (12 madeira + 8 pedra + 3
  minério) e **Poste de Luz** (4 madeira + 4 pedra + 2 fibra). Elas exigem
  `required_upgrade_id = "constr_workbench"` + Workbench por perto e são
  abertas/construídas pela interação E da Workbench (não entram na lista
  geral do B).
- Estrutura nova = só criar um `.tres` + uma cena — nenhum código muda.
- **Estruturas desbloqueáveis**: `StructureDef.required_upgrade_id` (opcional)
  só deixa a estrutura aparecer no modo B depois de comprado o upgrade
  correspondente na árvore de progressão (ver "Progressão permanente"
  abaixo) — é o caso da Workbench e das 3 estações seguintes. A lista
  numerada (1..N) é recalculada toda vez que o modo B abre e sempre que um
  upgrade é comprado.
- **Estações avançadas perto da Workbench**: Forja, Mesa de Alquimia, Mesa
  de Pesquisa, Baú Grande e Poste de Luz só podem ser erguidas dentro de
  ~200px de uma Workbench já construída (`StructureDef.
  requires_workbench_nearby`, checado no `BuildMode` junto com custo/alcance/
  espaço — o ghost fica vermelho e o texto explica o motivo). Ferramentas
  (Machado, Picareta) continuam craftáveis de qualquer lugar pelo painel de
  craft (C) — só a CONSTRUÇÃO das estações avançadas exige a Workbench por
  perto, não o craft de itens.
- **Baú Grande/Poste de Luz exigem o upgrade da Workbench e saíram do B
  geral** (ajuste jul/2026): os dois usam
  `required_upgrade_id = "constr_workbench"` (mesmo upgrade da Workbench),
  aparecem na interação E da Workbench e continuam exigindo a Workbench
  física por perto pra ficar verde/construível.
- **Seleção por clique, tecla 1..0 OU scroll do mouse** (registrado
  jul/2026): o painel do modo B virou clicável e scrollável, no mesmo
  estilo do painel de progressão (tecla U) — cada linha é um botão
  (`hud.gd::_build_row`) que chama `BuildMode.select_index(i)` direto,
  sem precisar saber qual tecla ou fazer scroll. Motivo: teclas físicas só
  cobrem até 10 (`BuildMode.BUILD_KEYS`, array explícito — antes o código
  somava `KEY_1 + i` direto, que quebrava a partir do 10º item), e quando a
  lista passar de 10 sempre vai sobrar pelo menos uma sem tecla. Tecla 1..0
  e scroll (`BuildMode._unhandled_input`, mesmo
  padrão da hotbar) continuam funcionando também — o clique é só mais uma
  forma, não substitui as outras. O painel fica na borda esquerda (não
  centralizado como o de progressão) de propósito: o jogador precisa
  continuar vendo o ghost seguindo o mouse no resto da tela pra
  posicionar a construção depois de escolher. `BuildMode._process()`
  ganhou o mesmo guard de UI-hover já usado no ataque do player, pra
  clicar num botão do painel não tentar construir embaixo dele ao mesmo
  tempo.
- **Só funciona na região 1 (base)**: `BuildMode` sai sozinho do modo
  construção (e recusa abrir) se o jogador estiver numa região 2+ ou numa
  run — ver "Regiões da superfície" abaixo.
- **Lista visível de opções (HUD, centro-esquerda)**: enquanto o modo B está
  aberto, um painel lista TODAS as estruturas disponíveis agora, numeradas
  (`[1] Cerca — 2 madeira`, etc.), com a linha selecionada destacada — antes
  só existia o hint flutuante preso no ghost (que só muda de texto quando
  você já aperta um número), o que tornava fácil não perceber que havia mais
  opções além das primeiras quando a lista cresceu pra 9 com a branch
  Construção. Ver `hud.gd::_refresh_build_panel` / `BuildMode.get_available()`.

## Mapa simples (M)

- Painel centralizado (`ui/map_view.gd`, um `Control` com `_draw()` — sem
  tiles, sem fog of war) mostrando um esquema de cima pra baixo só da
  REGIÃO ATIVA agora: jogador (ponto branco), bordas de região (ponto
  roxo + nome do destino, ex. "→ Terras Corrompidas") e estruturas construídas
  (ponto laranja). Não tenta juntar regiões diferentes na mesma escala —
  elas vivem em offsets espaciais gigantes só pra colisão/luz nunca se
  misturarem (ver "Regiões da superfície" abaixo), então não faria sentido
  cartográfico mostrar tudo junto.
- Resolve o problema de "não sei onde fica a borda pra outra região": a
  borda aparece marcada no mapa mesmo de longe, coisa que o marcador
  translúcido no chão sozinho não deixava óbvio.
- `WorldLayers.active_root()` e `WorldLayers.get_region_name(id)` (getters
  públicos novos) expõem o que o mapa precisa sem duplicar a lógica interna
  de regiões.

## Regiões da superfície (multi-região)

- `WorldLayers` generalizado de "1 superfície fixa" pra N regiões
  exploráveis, todas partindo da mesma base persistente (pilar: mundo
  único — ver "Decisões de design" abaixo). Região nova = um `RegionDef`
  (.tres em `world/regions/`) + uma cena, nenhum código muda (mesmo padrão
  de StructureDef/UpgradeDef/ItemDef).
- **Região 1 é sempre a base**: é a cena principal do jogo
  (`world/biome_1.tscn`), viva desde o boot, nunca destruída. Construção
  (B) e o talismã (acesso à run) só funcionam nela.
- **Regiões 2+ são instanciadas sob demanda**: na primeira vez que o
  jogador cruza uma borda (`entities/region_edge.gd`, um Area2D sem tecla
  — encostar já troca), a região nasce e fica viva escondida pelo resto da
  sessão (não é regenerada a cada visita, ao contrário das runs). Cada
  região vive num offset espacial fixo e enorme (`RegionDef.offset`) —
  mesmo truque de separação física que as runs já usavam
  (`WorldLayers.RUN_OFFSET`), agora generalizado.
- **Borda de região** (`entities/region_edge.gd` + `.tscn`): Area2D
  invisível-quase (só uma faixa translúcida marcando o limite), dispara
  `WorldLayers.goto_region(id, pos_local)` ao encostar. Toda borda precisa
  da borda espelhada do outro lado pra poder voltar. Trava 1.5s depois de
  qualquer troca pra não pingar ida-e-volta se o ponto de chegada nascer
  perto demais dela.
- **Gate de progressão na borda** (`RegionDef.required_biome_unlock`, 0 =
  sem gate): se a região de destino exigir um bioma desbloqueado
  (`ObjectiveTracker.is_biome_unlocked`) e ele ainda não estiver, a borda
  não deixa passar — mostra um aviso flutuante "Ainda não desbloqueado"
  (mesmo padrão visual do "Requer X" de `resource_node.gd`) e não entra em
  cooldown, então o jogador pode tentar de novo assim que desbloquear sem
  precisar esperar. Região 2 (Terras Corrompidas) exige bioma 2.
- **Região 2 = "Terras Corrompidas"** (`world/region_2.tscn`,
  `world/regions/2_test.tres`, tema registrado jul/2026 — nome de trabalho,
  troca fácil): identidade oposta à base (que é mais verde/viva) — ambiente
  mais escuro e arroxeado (`LitCanvasModulate` acinzentado), manchas de
  neblina reaproveitando `assets/fx/shadow_blob.png` tingido e ampliado
  (`Fog/FogPatch1..4`, decorativo, sem colisão), inimigos reaproveitados
  (`entities/enemy.gd`, sem script novo) com tint arroxeado via `modulate`
  na raiz da instância (cascata de `CanvasItem` — mais simples que usar
  `base_modulate`, que só pinta o sprite depois do primeiro hit) e stats de
  "morto-vivo lento": velocidade menor, vida maior, dano de contato um
  pouco maior. Recurso próprio da região: **Resíduo Sombrio**
  (`items/defs/residuo_sombrio.tres`, ainda sem ícone — placeholder
  deliberado até ter arte de verdade) coletado dos `resource_node`
  reaproveitados (`resource_id` sobrescrito na instância). Gancho pra
  branch Magia (hoje vazia): dá pra usar Resíduo Sombrio como custo dos
  primeiros upgrades de Magia quando ela for desenhada.
- **Limitação de v1 (registrada jul/2026)**: só a posição na BASE persiste
  entre sessões. Se o jogador salvar (ou fechar o jogo) numa região 2+,
  ele acorda na base ao recarregar — mesma lógica já usada pra morte
  ("ainda não voltou" em vez de "perdeu o lugar"). Dentro da sessão atual,
  a região 2+ continua funcionando normalmente (estado não se perde só de
  ir e voltar); só não sobrevive a um save/reload.
- Morrer numa região 2+ (fora de run) leva de volta à base igual a
  qualquer outra morte — antes disso não acontecia (bug latente corrigido
  junto com esta feature: o teleporte pós-morte não levava em conta a
  região ativa).
- **Sprint 1 do ciclo de dia/noite** (registrado jul/2026): `WorldLayers`
  agora roda um relógio global só na superfície (runs congelam o horário).
  O ciclo completo está configurado em **2 minutos para teste** e passa por
  **dia → entardecer → noite → amanhecer**. O horário atual persiste no save
  (`SaveManager` grava `time_of_day_ratio`).
- **Ambiente da superfície responde ao horário**: o `LitCanvasModulate` da
  região ativa usa a cor-base da cena como referência e aplica um fator de
  brilho conforme a fase do ciclo (dia fica levemente mais claro que o
  padrão da cena, entardecer cai forte, noite escurece bastante e
  amanhecer clareia de volta). Isso vale pra base e também pra região 2,
  sem apagar a identidade visual própria de cada cena.
- **Pressão noturna v1**: durante a noite, a superfície começa a gerar
  inimigos extras em lotes ao redor do jogador (`night_surface_enemy`) com
  aumento perceptível de velocidade, vida, dano e raio de detecção.
  Perto da base existe uma zona segura (`BASE_SAFE_RADIUS`) que barra novos
  spawns, reforçando a ideia de voltar antes de escurecer. Ao sair da
  noite, esses inimigos extras somem.
- **Marcador da zona segura da base** (registrado jul/2026, foco em teste):
  a base agora mostra um círculo pulsante fraco no chão indicando até onde
  vai o raio seguro contra spawn noturno. Serve para calibrar o sistema de
  pressão antes de decidir se esse indicador fica permanente ou vira debug.

## Baú de armazenamento

- 20 slots próprios, independentes da hotbar do jogador (o dobro da
  hotbar — dá fôlego real numa run).
- F abre/fecha a UI de transferência — só o baú mais próximo ao jogador
  responde (label acima da cabeça avisa qual). Arrastar um item entre baú
  e hotbar transfere de verdade (empilha se bater o item, troca de posição
  senão).
- Conteúdo persiste no save junto com a posição da estrutura.
- **Baú Grande** (registrado jul/2026, função da Workbench — ver "Estações
  com função"): mesma estrutura/script (`entities/structures/chest.gd`),
  agora com `slot_count` virado `@export` (antes era uma constante fixa em
  20) — o Baú Grande é só uma segunda cena (`chest_grande.tscn`) com
  `slot_count = 40`, sprite maior/tingido de escuro pra diferenciar do baú
  normal sem depender de arte nova. Só pode ser construído perto de uma
  Workbench (`required_upgrade_id = "constr_workbench"` +
  `requires_workbench_nearby`, 12 madeira + 8 pedra + 3 minério). O painel
  da Workbench (E) lista essa construção diretamente; o B geral não lista.
  O painel do baú no HUD ganhou 40 slots fixos (antes 20) pra
  caber os dois tamanhos — um baú normal só usa os primeiros 20 e os
  demais ficam escondidos (`hud.gd::_update_chest_panel`, agora esconde
  slots além da capacidade do baú aberto em vez de só "não atualizar").

## Poste de Luz (registrado jul/2026, função da Workbench)

- Segunda estrutura desbloqueada pela Workbench (`requires_workbench_nearby`,
  `required_upgrade_id = "constr_workbench"`, 4 madeira + 4 pedra + 2
  fibra): mesma luz por ponto (`LitPointLight2D`) da
  Tocha, mas alcance/energia maiores (raio 175 contra 110, energia 1.3) —
  cobre uma área boa da base sem precisar espalhar várias tochas. Reaproveita
  a mesma textura da Tocha (`floor_torch.png`) com escala maior e tingida
  num branco mais frio, pra ficar visualmente distinto sem precisar de
  sprite novo (mesmo truque de tint usado no reskin dos inimigos da região
  2).

## Talismã e runs (lado roguelite)

- O talismã é uma **estrutura construível** na base (não mais tecla
  global) — F nele leva o jogador pra dentro de uma run gerada na hora.
- **Dentro da run não existe saída voluntária**: só se sai ganhando
  (derrotar o boss abre um portal de saída) ou morrendo (morte continua
  leve — ver acima).
- **Portal de Atalho (superfície, protótipo)**: receita no C (8 essência)
  que constrói um portal perto do jogador na base (`RecipeDef.
  build_structure_id = "portal_atalho"`). Dois portais formam um par de
  teleporte curto via F (só o mais próximo responde, mesmo padrão de
  interação das outras estruturas), com recarga curta pra evitar ping-pong.
  Não funciona durante run e não substitui o Talismã (run) nem os portais de
  escolha dentro da run.
- Formato atual por mapa: **sala de combate única** (arena), sem corredores.
  Em mapas normais, a sala começa com uma leva de **3–5 inimigos** e novas
  levas continuam surgindo até fechar um total de **25–30 inimigos** no
  mapa. Só depois da última leva os portais de escolha aparecem.
- Conteúdo escala com a profundidade (`map_index`) e com o **viés**
  escolhido no portal anterior: minério (mais veios), combate (mais
  inimigos + chance de elite), suprimentos (mais props).
- **Run Modifiers** (registrado jul/2026, `RunModifierDef`, .tres em
  `world/dungeon/modifiers/`) — "maldição do dia" estilo Hades/Slay the
  Spire: `WorldLayers` sorteia UM modificador ao entrar no talismã
  (`_do_start_run`), vale pra todos os mapas até voltar pra base (toast de
  anúncio no início). 6 hoje, cada um com um efeito dominante só (fácil de
  testar isolado): Escuridão (cura pela metade), Fúria Inimiga (+25% vel./
  +15% dano dos inimigos), Veios Ricos (2× minério), Armas Frágeis (-25%
  dano do jogador), Chefe Fortalecido (+50% poder do boss), Enxame (+25%
  chance de elite em cima do viés do portal). Adicionar modificador novo =
  criar `.tres`; nenhum código muda. `WorldLayers.active_modifier` é null
  fora de run — todo getter (`get_enemy_speed_mult()` etc.) já tem
  fallback neutro, ninguém precisa checar null na mão.
- Props do dungeon (caixote, barril, pote, entulho de pedra, saco) são
  **quebráveis em 1 golpe sem ferramenta** — isso evita travar movimentação
  durante a luta em salas mais cheias.
- A cada 3 mapas, a sala final vira arena de boss: graybox com investida
  telegrafada (dash) e pancada em área telegrafada, +40% de força a cada
  ciclo completado. Vitória → dropa essência + abre portal de saída.
- Mapas sem boss terminam em 2–3 portais de escolha lado a lado, cada um
  anunciando o viés do próximo mapa — só o mais próximo responde ao F.
- **Inimigos com identidade** (`entities/enemy.gd`, um script só, 3
  comportamentos escolhidos por export — igual ao resto do jogo, o que
  muda vira dado, não script novo):
  - **Melee** (kit 1): persegue e bate por proximidade — o original.
  - **Rápido** (kit 2, melee): mais veloz, menos vida.
  - **À distância** (kit 3, novo): mantém uma faixa de distância ideal
    (foge se o jogador chega perto, aproxima se fica longe) e atira uma
    bola de fogo (`enemy_projectile.tscn`) que acerta por proximidade —
    mesma convenção de dano do resto do jogo.
  - **Explosivo** (kit 4, novo): persegue, "acende o pavio" ao chegar
    perto (pisca vermelho ~0.8s) e explode em área — dano em raio,
    depois se autodestrói (kamikaze, sem loot).
  - Todos escalam vida/dano/velocidade com a profundidade do mapa (dano
    também escala com `enemy_damage_mult` do Run Modifier ativo, se
    houver).
  - **Elite com afixos reais** (mudou jul/2026 — antes era só um
    multiplicador burro ~1.8×): agora é um bump menor de vida (1.3×) +
    2 afixos sorteados de `run_map.gd::ELITE_AFFIXES`, aplicados em
    `entities/enemy.gd` e mostrados como texto flutuante acima da cabeça
    (placeholder, sem ícone): **Rápido** (+40% velocidade), **Vampírico**
    (cura 50% do dano de contato/explosão causado — projétil ainda não
    cura em v1), **Blindado** (-35% de todo dano recebido), **Regenerativo**
    (regenera 3%/s da vida máxima) e **Explosivo** (dá um último estouro em
    área ao morrer, além do kamikaze de comportamento). Continua maior e
    avermelhado pra identificar de longe. Aplica em qualquer um dos 4
    comportamentos, não só no melee.
  - Visual: `SpriteFrames` montado em runtime a partir das strips U/D/S do
    `assets/craftpix_dungeon_kit/enemies/<1-4>/` (idle/walk/attack/death
    por direção, lado espelhado via flip_h — o kit não tem left/right
    dedicados).
  - Mistura por sala controlada por `reward_bias`: fora do viés combate,
    a run é majoritariamente melee com uma pitada dos outros 3; no viés
    combate, os quatro tipos ficam bem mais equilibrados (mais risco,
    de propósito).

## Objetivos e progressão (Bioma 1)

- Três objetivos: Derrote o Guardião ×2, Colete 6 Essências (cumulativo —
  gastar no Amuleto Vital não desfaz o progresso), Construa 4 estruturas.
- Painel no HUD (O alterna) mostra o progresso ao vivo de cada um.
- Completar os três → toast "Bioma 2 desbloqueado!" + flag persistida
  (`is_biome_unlocked(2)`), que agora realmente abre a borda pra região 2
  ("Terras Corrompidas" — ver "Regiões da superfície" acima). Antes desse
  flag, a borda barra a passagem com um aviso.

## Progressão permanente (árvore de upgrades)

- Sistema de meta-progressão comprado com **essência** (até agora só usada
  no Amuleto Vital) — dá propósito de longo prazo pra cada boss derrotado.
- Estrutura por branches: Combate, Exploração, Construção, Magia. Magia
  ainda não tem nenhum upgrade cadastrado (branch vazia por enquanto,
  aparece quando o primeiro `.tres` dela existir).
- Cada upgrade (`UpgradeDef` .tres em `progression/upgrades/`) pode exigir
  outro já comprado (`requires`) — dá uma cadeia por branch sem precisar de
  UI de árvore/grafo visual: o painel é só uma lista com estado
  bloqueado/disponível/comprado por linha.
- Painel no HUD (U abre/fecha, botão "Comprar" por linha, mutuamente
  exclusivo com craft e baú).
- 10 upgrades hoje:
  - **Combate**: Fio Afiado I e II (+10% dano corpo a corpo cada,
    encadeados), Passo Leve (-25% cooldown do dash).
  - **Exploração**: Lanterna Encantada (+25% alcance da luz pessoal),
    Mão Precisa (25% de chance de +1 unidade extra por golpe em qualquer
    nó de recurso), Pés Ligeiros (+8% velocidade de movimento).
  - **Construção**: Workbench → Forja → Mesa de Alquimia → Mesa de
    Pesquisa, em cadeia (cada um exige o anterior comprado). Cada upgrade
    não mexe em multiplicador nenhum — o efeito (`Effect.UNLOCKS_STRUCTURE`)
    é só liberar a estrutura correspondente no modo construção (ver
    `StructureDef.required_upgrade_id` acima).
- Efeitos vivem como multiplicadores/bônus em `GameState`
  (`attack_damage_mult`, `dash_cooldown_mult`, `speed_mult`,
  `lantern_range_mult`, `resource_yield_bonus_pct`) — exceto os de
  Construção, que não tocam em `GameState` (o "efeito" é o desbloqueio em
  si). O que é salvo de verdade é só a LISTA de ids comprados; os
  multiplicadores são reaplicados do zero a partir dela ao carregar o save.

## Iluminação e perspectiva

- Migração completa pra perspectiva Don't Starve-like: origem dos nós nos
  pés, colisores = pegada da base, sombra de contato, occluder na base,
  Y-sort em toda cena.
- Addon Lit: superfície com ~65% de luz ambiente; runs agora com ambiente
  mais alto (~56%) para melhorar leitura de combate nas salas. A arena de
  run também ganhou mais tochas fixas (cantos + laterais), mantendo o clima
  escuro sem sacrificar visibilidade. Fundo preto fora da área iluminada.
- Lanterna craftável aumenta força e alcance da luz pessoal (fraca sem
  ela, forte com ela no inventário).

## Save e persistência

- JSON versionado em `user://save.json`: vida, fome, vida máxima,
  inventário completo, ferramenta equipada, posição do jogador, todas as
  estruturas construídas (incluindo o conteúdo de cada baú), nós de
  recurso já esgotados na superfície, progresso de objetivos.
- Autosave a cada 45s + em eventos-chave (construir, entrar/sair de run,
  abrir o pause, fechar o jogo).
- Runs nunca salvam nada — permadeath é do MAPA (por design, roguelite),
  nunca do personagem ou do progresso da base.

## HUD e UI

- Barras de vida/fome, indicador de ferramenta equipada, hotbar numerada,
  painel de craft, painel do baú, painel de progressão, painel de
  objetivos, mapa simples, tela de morte, menu de pause.
- **Número exato sobreposto nas barras de vida/fome** (registrado jul/2026,
  pedido do usuário): `"atual / máximo"` centralizado em cima do
  preenchimento (`HealthBar/ValueLabel`, `HungerBar/ValueLabel` em
  `hud.tscn`, atualizado em `_on_health_changed`/`_on_hunger_changed`).
  Sem isso, 100/100 (sem Amuleto Vital) e 150/150 (com dois) apareciam
  visualmente IDÊNTICOS — a barra sempre cheia, só a escala mudando por
  baixo — o que tornava difícil confirmar se o bônus passivo estava
  ativo só de olhar.
- **Redesign do bloco de status (Vida/Fome) focado em legibilidade**
  (registrado jul/2026, pedido do usuário): HUD voltou para barras
  minimalistas (`ProgressBar`) sem arte final e ganhou hierarquia clara:
  card de status com painéis arredondados, Vida como recurso primário
  (barra maior/mais destacada) e Fome como secundário. O update de valor
  continua vindo dos mesmos sinais (`GameState.health_changed` /
  `GameState.hunger_changed`), mas agora com interpolação suave por `Tween`
  em vez de salto instantâneo.
- **Feedback visual contextual nas barras** (registrado jul/2026): Vida dá
  flash curto ao tomar dano e entra em pulso quando cai para <=25%; Fome
  mostra aviso específico de crítico (label "FOME CRÍTICA" + pulso visual)
  quando fica <=20%.
- **Textos de Vida/Fome sob demanda** (registrado jul/2026): os rótulos
  ("VIDA"/"FOME") e números `"atual / máximo"` ficam ocultos por padrão e
  aparecem ao passar o mouse sobre cada medidor, deixando a HUD mais limpa
  durante exploração/combate. Ajuste posterior removeu flick de hover:
  texto continua no layout e só muda opacidade (sem toggle de `visible`).
- **Expansão de barras no hover** (registrado jul/2026): card de status
  começa colapsado (mostra só as barras); ao passar o mouse em uma barra, o
  card expande com tween curto e revela cabeçalhos + números. Ao sair da
  área do card, ele colapsa de novo.
- Pause (ESC): volume persistido entre sessões, continuar, **Controles**
  (mostra a lista de teclas — mesmo texto que antes só aparecia ~6s no
  boot com fade; agora fica sempre acessível aqui, e o boot não mostra
  mais nada sozinho), recomeçar do zero (confirmação dupla — único jeito
  de apagar o save de verdade), salvar e sair. "Controles" troca pra uma
  segunda tela dentro do mesmo painel (botão "Voltar" ou ESC volta pro
  menu principal sem fechar o pause).
- ESC funciona em cadeia por prioridade: dentro da tela de Controles só
  volta um nível (não fecha o pause) > fecha pause > fecha cheat > fecha
  mapa > fecha painel do baú > fecha progressão > fecha craft > sai do
  modo construção > abre o pause.
- **Menu de cheat/debug (F1)**: só existe em build de debug
  (`OS.is_debug_build()` — nunca aparece num export de release). Um botão
  "+10" por item de categoria RESOURCE (madeira, pedra, fibra, minério,
  essência) OU FOOD (Cogumelo, Refeição Reforçada — categoria FOOD entrou
  jul/2026, a pedido do usuário) — data-driven via `ItemDB.get_all()`, item
  novo aparece sozinho — + "Curar + saciar tudo". Existe só pra testar a
  progressão (branch Construção, upgrades) sem precisar farmar em runs de
  verdade a cada teste. Mutuamente exclusivo com craft/baú/progressão,
  integrado na cadeia do ESC. **Ancorado no topo-esquerda dentro de um
  `ScrollContainer`** (jul/2026, era `CENTER_LEFT` sem scroll — a lista
  cresceu e passou a cortar no canto inferior esquerdo da tela).

## Áudio

- SFX implementados: dano no jogador, dano em inimigo, mineração/coleta,
  comer, passos (6 variações que tocam aleatoriamente a cada ~42px
  andados). Ainda sem música nenhuma.

## Decisões de design registradas

- **Mundo único e persistente**: não existe "base por bioma". Progredir
  libera novas regiões conectadas ao mesmo mapa (mais recursos, inimigos,
  NPCs, quests, dungeons) — a base que o jogador constrói é sempre a
  mesma, num só lugar.
- **Raids ocasionais na base**: motivo adicional (além de progressão) pra
  fazer runs — o equipamento trazido de lá prepara o jogador pra defender
  a base. Mecânica ainda sem gatilho/frequência definidos.
- **Sem saída voluntária de run**: ver seção "Talismã e runs" acima.
- **Portal ≠ Talismã**: um "Portal" de atalho (fast-travel entre regiões
  distantes do mesmo mundo) é uma ideia separada, planejada como estação
  tardia na branch Construção/Magia da progressão. Não substitui nem se
  confunde com o Talismã, que continua sendo a única entrada pra uma run.

Detalhe completo de cada decisão em `docs/plano-2-anos.md` §2 e §6.
