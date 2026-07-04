# Funcionalidades — Light in the Dark

> Catálogo completo do que já está **implementado e jogável**, organizado por
> sistema. Não é roadmap nem estado de tarefas — pra isso, ver
> `PROJECT_STATUS.md` (handoff rápido) e `docs/plano-2-anos.md` (roadmap +
> decisões de design). **Regra: sempre que uma funcionalidade nova entrar no
> jogo, atualizar este arquivo na mesma sessão.**

Última atualização: 2026-07-03 (Forja com função própria: Tier II + Espada da Forja).

---

## Movimento e combate

- Movimento 8-direcional (WASD ou setas), perspectiva pseudo-isométrica
  estilo Don't Starve: 2D puro, achatamento vertical (passo pra cima/baixo
  cobre menos tela que um passo lateral).
- Ataque de alvo único (Espaço ou clique esquerdo): entre tudo que está na
  área de ataque, escolhe o melhor por distância + alinhamento com a
  direção encarada, com leve prioridade a inimigos sobre coleta. Acerta
  qualquer coisa com método `hit()` — inimigos, boss, nós de recurso, props
  quebráveis do dungeon.
- Hit-stop de 50ms no acerto + fagulhas de partícula — dá peso ao golpe.
- Knockback nos inimigos comuns ao levarem dano.
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
- **Ataque especial em área (Q)** (registrado jul/2026): golpe giratório
  que acerta TODOS os alvos num raio ao redor do jogador
  (`SPECIAL_ATTACK_RADIUS = 100`), ao contrário do ataque normal (alvo
  único). Dano é instantâneo (aplicado no frame em que Q é apertado); o
  visual — um anel se expandindo — é o mesmo do ataque "Pancada" do Boss da
  dungeon (`boss.gd::_do_slam`/`_draw`), só que aqui é puramente cosmético e
  toca DEPOIS do dano, não antes. Só funciona com uma arma equipada
  (`ItemDef.weapon_damage_bonus > 0` — ver abaixo); com machado/picareta
  equipados não faz nada. Cooldown de 2.5s (`SPECIAL_ATTACK_COOLDOWN`) pra
  não virar o ataque padrão — é um "nuke" ocasional. Não funciona durante o
  dash (diferente do ataque normal, que agora funciona).
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
- Drag-and-drop entre slots: solta sobre outro item igual empilha (até o
  máximo, sobra fica no slot de origem), solta sobre item diferente troca
  de posição. O mesmo sistema funciona entre a hotbar e o baú (ver abaixo).
- Itens data-driven (`ItemDef` .tres em `items/defs/`) — 11 hoje:
  madeira, pedra, fibra, minério, essência (sem uso de coleta direta, só
  drop de boss), Cogumelo/comida (+25 fome), Refeição Reforçada (craftada,
  +60 fome / +30 vida), Machado I, Picareta I, Picareta II, Lanterna.
- Categorias: recurso, ferramenta, comida, estrutura.

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
  cadastradas — nenhuma linha de UI hardcoded.
- Receitas hoje: Machado I, Machado II, Picareta I, Picareta II, Espada da
  Forja, Lanterna (2 fibra + 2 madeira — luz pessoal bem mais forte
  enquanto no inventário), Refeição Reforçada (5 comida → 1 refeição),
  Amuleto Vital (3 essências → +25 vida máxima permanente + cura 25 na
  hora do craft).
- **Receitas com estação exigida** (`RecipeDef.required_station`, "" = em
  qualquer lugar): Machado II, Picareta II e Espada da Forja só craftam com
  uma Forja construída a ~200px (`hud.gd::_near_station`, mesmo raio e
  mesma ideia do `BuildMode._workbench_nearby`, mas medido a partir do
  jogador em vez do ghost). Sem a estação por perto, o painel mostra
  "Precisa estar perto da Forja" em vez de craftar. O painel de craft já
  lista isso na linha da receita (`"... (perto da Forja)"`).

## Estações com função (registrado jul/2026)

- Antes, as 4 estações da branch Construção (Workbench, Forja, Mesa de
  Alquimia, Mesa de Pesquisa) só existiam como marco de progressão — nada
  de verdade exigia estar perto delas. Primeiro passo pra mudar isso:
  **Forja** agora dá acesso a receitas próprias (`RecipeDef.
  required_station = "forja"`, ver "Crafting" acima): Machado II, Picareta
  II e a Espada da Forja. Ainda faltam: Workbench (móveis/melhorias
  básicas), Mesa de Alquimia (poções/buffs temporários — precisa de um
  sistema de efeito com duração que ainda não existe) e Mesa de Pesquisa
  (desbloqueios/receitas especiais).
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
- Estruturas hoje (`items/structures/*.tres`, tecla 1..N escolhe no modo B):
  Cerca de Madeira (2 madeira), Fogueira (4 madeira + 2 pedra, ilumina),
  Tocha (1 madeira + 2 fibra, ilumina), **Baú** (6 madeira + 3 pedra,
  armazenamento), **Talismã** (8 madeira + 4 pedra, acesso à run),
  **Workbench** (8 madeira + 4 pedra), **Forja** (6 pedra + 4 minério),
  **Mesa de Alquimia** (6 madeira + 4 fibra), **Mesa de Pesquisa**
  (8 madeira + 6 pedra).
- Estrutura nova = só criar um `.tres` + uma cena — nenhum código muda.
- **Estruturas desbloqueáveis**: `StructureDef.required_upgrade_id` (opcional)
  só deixa a estrutura aparecer no modo B depois de comprado o upgrade
  correspondente na árvore de progressão (ver "Progressão permanente"
  abaixo) — é o caso da Workbench e das 3 estações seguintes. A lista
  numerada (1..N) é recalculada toda vez que o modo B abre e sempre que um
  upgrade é comprado.
- **Estações avançadas perto da Workbench**: Forja, Mesa de Alquimia e Mesa
  de Pesquisa só podem ser erguidas dentro de ~200px de uma Workbench já
  construída (`StructureDef.requires_workbench_nearby`, checado no modo B
  junto com custo/alcance/espaço — o ghost fica vermelho e o texto explica
  o motivo). Ferramentas (Machado, Picareta) continuam craftáveis de
  qualquer lugar pelo painel de craft (C) — só a CONSTRUÇÃO das estações
  avançadas exige a Workbench por perto, não o craft de itens.
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

## Baú de armazenamento

- 20 slots próprios, independentes da hotbar do jogador (o dobro da
  hotbar — dá fôlego real numa run).
- F abre/fecha a UI de transferência — só o baú mais próximo ao jogador
  responde (label acima da cabeça avisa qual). Arrastar um item entre baú
  e hotbar transfere de verdade (empilha se bater o item, troca de posição
  senão).
- Conteúdo persiste no save junto com a posição da estrutura.

## Talismã e runs (lado roguelite)

- O talismã é uma **estrutura construível** na base (não mais tecla
  global) — F nele leva o jogador pra dentro de uma run gerada na hora.
- **Dentro da run não existe saída voluntária**: só se sai ganhando
  (derrotar o boss abre um portal de saída) ou morrendo (morte continua
  leve — ver acima).
- Geração procedural por mapa: "drunkard walk" numa grade de salas (6 a 11
  salas, cresce com a profundidade), conectadas em árvore — só existe UM
  caminho entre o spawn e o fim, sem bifurcação real. Corredores em L de 3
  tiles de largura. Uma trilha de tiles mais claros marca visualmente o
  caminho até o fim.
- Conteúdo escala com a profundidade (`map_index`) e com o **viés**
  escolhido no portal anterior: minério (mais veios), combate (mais
  inimigos + chance de elite), suprimentos (mais props).
- Props do dungeon (caixote, barril, pote, entulho de pedra, saco) são
  **quebráveis em 1 golpe sem ferramenta** — nunca fecham permanentemente
  a única passagem de uma sala gerada (fix de bug real).
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
  - Todos escalam vida/dano/velocidade com a profundidade do mapa; elites
    (só no viés combate) são maiores, avermelhados, ~1.8× mais fortes —
    aplica em qualquer um dos 4 tipos, não só no melee.
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
- Addon Lit: superfície com ~65% de luz ambiente; runs com 30% (escuras de
  propósito — a lanterna importa de verdade lá dentro); fundo preto fora
  da área iluminada.
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
  essência — data-driven via `ItemDB.get_all()`, item novo aparece
  sozinho) + "Curar + saciar tudo". Existe só pra testar a progressão
  (branch Construção, upgrades) sem precisar farmar em runs de verdade a
  cada teste. Mutuamente exclusivo com craft/baú/progressão, integrado na
  cadeia do ESC.

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
