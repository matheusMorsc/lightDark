# Light in the Dark — Estado do Projeto (handoff)

> Documento de continuidade: cole no início de um novo chat (ou peça pra ler
> `PROJECT_STATUS.md`). Docs complementares: `docs/funcionalidades.md`
> (catálogo completo do que já está implementado — atualizar sempre que
> algo novo entrar), `docs/plano-2-anos.md` (roadmap) e
> `docs/perspective-migration.md` (migração de perspectiva, ref. técnica).

## Visão

Survival/base-building 2D (Godot 4.7) com **superfície fixa e persistente**
(lado Stardew) + **runs procedurais estilo Hades** acessadas por um talismã
construído na base: mapas encadeados por portais de escolha, boss a cada 3
mapas, materiais raros movem a progressão. Dentro da run não existe saída
voluntária — só se volta ganhando ou morrendo. Perspectiva pseudo-isométrica
estilo Don't Starve (2D puro, Y-sort, âncora nos pés). Arte atual é 100%
placeholder (Kenney + Craftpix); a arte final será desenhada à mão pela dupla.

## Controles

WASD/setas move · Espaço/clique ataca — moveset muda conforme a arma
equipada (jul/2026, ver "Convenções"): Espada é alvo único (funciona
durante o dash e numa janela curta depois, com alcance maior — "ataque
rápido"), Lança perfura uma linha inteira, Martelo acerta em área e
atordoa (mas é mais lento) · Shift dash (instantâneo, i-frames curtas,
cooldown) · Q ataque especial em área, dano instantâneo + cooldown 2.5s,
só com arma equipada e roteado por arma — Espada gira, Lança vira cone
longo, Martelo sempre atordoa (jul/2026, ver "Convenções") ·
1..0/scroll/clique seleciona hotbar — se o slot for ferramenta/arma,
equipa na hora, qualquer outra coisa desequipa (sem tecla dedicada de
troca, ver "Convenções") · clique direito come a comida SELECIONADA na
hotbar (mudou jul/2026 — antes E comia a primeira comida do inventário
automaticamente) · M mapa · C craft geral (ESC fecha) · E craft filtrado
ao lado de Forja/Mesa de Pesquisa/Mesa de Alquimia/Workbench (jul/2026,
ver "Convenções" — não é F pra não arriscar entrar numa run se a estação
estiver perto do Talismã) · U progressão permanente (ESC fecha) ·
B constrói (1..0/scroll/clique troca de estrutura, corrigido jul/2026 —
ver "Problemas conhecidos" item 11) · O painel de objetivos · F interage
(baú, talismã, portais) · ESC pause · F1 menu de cheat (só build de
debug).

## Decisões de design

- **Mundo único, base persistente (registrado jul/2026):** não existe "base
  do bioma 2". Progredir libera novas REGIÕES conectadas ao mesmo mapa —
  mais recursos, inimigos, NPCs, quests, novas dungeons — mas a base que o
  jogador constrói continua sendo sempre a mesma, num só lugar. Sempre que
  a documentação disser "novo bioma na superfície", leia "nova região
  explorável", nunca "nova base pra recomeçar". Detalhe completo em
  `docs/plano-2-anos.md` §2.
- **`WorldLayers` multi-região implementado (registrado jul/2026):**
  generalizado de "1 superfície fixa" pra N regiões (`RegionDef` .tres em
  `world/regions/`, região nova = .tres + cena, nenhum código muda). Região
  1 é sempre a base (a cena principal, viva desde o boot); regiões 2+
  nascem sob demanda ao cruzar uma borda (`entities/region_edge.gd`) e
  ficam vivas escondidas pelo resto da sessão. Construção (B) e talismã só
  funcionam na região 1. Região 2 hoje é só um graybox de teste
  (`world/region_2.tscn`) — prova que a troca funciona, sem conteúdo
  próprio de verdade ainda. **Limitação de v1**: só a posição na base
  persiste entre sessões (salvar numa região 2+ acorda na base ao
  recarregar, mesma lógica da morte). Detalhe em
  `docs/funcionalidades.md` §"Regiões da superfície".
- **Raids na base (novo, ainda sem mecânica desenhada):** runs não servem só
  pra progredir — a base pode sofrer invasões ocasionais de inimigos, e o
  que se traz das runs (equipamento, estruturas defensivas) é o que prepara
  o jogador pra defendê-la. Gatilho, frequência e quem ataca ainda não
  foram definidos.
- **Talismã virou estrutura, sem saída voluntária da run (registrado
  jul/2026):** a tecla T global foi removida. O talismã agora é uma
  `StructureDef` construível igual ao baú/fogueira (`items/structures/
  5_talisma.tres` + `entities/structures/talisman.gd`) — F nele entra na
  run. Uma vez dentro, **não existe mais forma de sair a qualquer momento**:
  só ganhando (derrota o boss → portal de saída) ou morrendo (morte
  continua leve — acorda em casa com metade da vida). Isso também
  **substitui** o plano antigo do `docs/plano-2-anos.md` §6 de "corda de
  emergência" pra extração voluntária — esse item não vale mais.
- **Gating da branch Construção (registrado jul/2026):** ferramentas
  (Machado, Picareta) continuam craftáveis em qualquer lugar pelo painel
  de craft (C) — isso não muda. Só a CONSTRUÇÃO das estações avançadas
  (Forja, Mesa de Alquimia, Mesa de Pesquisa) exige estar perto de uma
  Workbench já erguida; Baú Grande e Poste de Luz seguem o mesmo gating,
  mas entram pelo E da Workbench (não no B geral). A Workbench em si não
  exige nada além do upgrade comprado. Decisão do usuário, resolve a
  ambiguidade que estava em aberto desde a sessão anterior.

## Sistemas implementados

### Perspectiva e mundo
- Migração top-down → Don't Starve-like completa: `Entities` com Y-sort em
  toda cena, origem dos nós nos pés, colisores = pegada da base (cápsulas),
  occluders na base, foreshortening vertical 0.8 no movimento.
- Camadas de física: 1=world, 2=player, 3=enemies. Inimigos NÃO colidem com
  o player (dano é por distância) — nada de prensar o jogador em fila.
- Cena principal: `world/biome_1.tscn` (região 1, a base — sempre viva).
- Iluminação: addon Lit. Superfície ~65% de ambiente; runs subiram para
  ~56% e receberam mais pontos de luz na arena (tochas extras) para melhorar
  leitura sem perder o clima escuro. Fundo preto via `default_clear_color`.
- **Ciclo de dia/noite v1 (Sprint 1, jul/2026):** `WorldLayers` agora
  controla um relógio global da superfície (**1 min por ciclo em modo de
  teste**, persistido no save) e reaplica o `LitCanvasModulate` da região
  ativa conforme a fase (`dia`, `entardecer`, `noite`, `amanhecer`). Runs
  congelam o horário.
- **Pressão noturna v1:** à noite, a superfície spawna inimigos extras ao
  redor do jogador com buff mais agressivo de stats, em lotes e com cap
  maior; perto da base existe uma zona segura onde novos spawns noturnos
  não entram. Ao amanhecer, esses extras são removidos.
- **Marcador da zona segura da base:** `world/base_safe_radius_marker.gd`
  desenha um anel/círculo pulsante no chão da base, centrado em
  `home_position`, para visualizar o alcance do efeito seguro noturno. Raio
  de teste atual reduzido para `BASE_SAFE_RADIUS = 280`.

### Regiões (multi-região)
- `WorldLayers` gerencia N regiões via `RegionDef` (.tres em
  `world/regions/`) — região nova = .tres + cena, nenhum código muda.
  Região 1 (base) é a cena principal, sempre viva; regiões 2+ nascem sob
  demanda ao cruzar uma borda (`entities/region_edge.gd`, Area2D sem
  tecla) e ficam vivas escondidas pelo resto da sessão (offset espacial
  fixo, mesmo truque das runs). `WorldLayers.goto_region(id, pos_local)`.
- Construção (B) e talismã só funcionam na região 1.
- **Gate de progressão** (`RegionDef.required_biome_unlock`): borda só deixa
  passar se o bioma exigido já estiver desbloqueado
  (`ObjectiveTracker.is_biome_unlocked`); senão mostra aviso flutuante,
  sem cooldown de retry.
- **Região 2 = "Terras Corrompidas"** (tema registrado jul/2026, nome fácil
  de trocar): exige bioma 2. Ambiente arroxeado/nebuloso (fog reaproveitando
  `shadow_blob.png` tingido), inimigos reaproveitados com tint + menos
  velocidade/mais vida ("morto-vivo lento"), recurso próprio **Resíduo
  Sombrio** (`items/defs/residuo_sombrio.tres`, sem ícone ainda —
  placeholder, gancho futuro pra branch Magia). Deixou de ser graybox puro,
  mas ainda sem NPCs/estruturas próprias.
- Limitação de v1: só a posição na base persiste entre sessões; salvar
  numa região 2+ acorda na base ao recarregar.

### Loop de superfície
- **Itens data-driven**: `ItemDef` (.tres em `items/defs/`) — categoria,
  stack, ferramenta (tipo+tier), comida (fome+cura). `ItemDB` carrega a pasta.
- **Ferramentas com gating**: fibra/pedra à mão → Machado I → madeira →
  Picareta I → minério. Nós de recurso (`resource_node.gd`) exigem
  tipo+tier EQUIPADO e têm drop tables; aviso "Requer X" flutuante.
- **Receitas data-driven**: `RecipeDef` (.tres em `items/recipes/`); o painel
  de craft do HUD se monta sozinho. Lanterna (luz pessoal forte só com o
  item), Refeição (comida consumível), Amuleto Vital (3 essências → +25 HP).
  `RecipeDef` agora também suporta construção direta via C
  (`build_structure_id`): primeira receita usando isso é o **Portal de
  Atalho** (8 essência).
- **Tier II como upgrade + Estações com função (registrado jul/2026)**:
  Machado II/Picareta II agora CONSOMEM a ferramenta Tier I (não são mais
  itens soltos e redundantes) e só craftam perto de uma Forja
  (`RecipeDef.required_station`, checado em `hud.gd::_near_station` — o
  mesmo raio/ideia do `BuildMode._workbench_nearby`, mas a partir do
  jogador). Primeira arma pura do jogo: **Espada da Forja**
  (`ItemDef.weapon_damage_bonus = 15`, aplicado em `player.gd::_attack()`
  via `_equipped_weapon_bonus()`) — machado/picareta nunca deram dano de
  combate, isso é novo. Sem ícone ainda (placeholder). Hoje as 4 estações
  já têm função própria (incluindo Workbench com fluxo de construção via E).
- **Construção (B)**: `BuildMode` autoload + `StructureDef` (.tres em
  `items/structures/`): cerca, fogueira, tocha, **baú**, **talismã**,
  **Workbench, Forja, Mesa de Alquimia, Mesa de Pesquisa**. Ghost com
  snap, validade por física/custo/alcance/upgrade-desbloqueado/Workbench-
  por-perto (as 3 estações avançadas), custo em recursos descontado
  direto. `StructureDef.required_upgrade_id` filtra a lista numerada pelo
  que já foi comprado na progressão; a lista é recalculada ao abrir o
  modo e a cada compra nova (e também ao carregar um save — ver fix
  abaixo). Painel no HUD (centro-esquerda) lista as opções numeradas com a
  seleção destacada enquanto o modo B está aberto — antes só existia o hint
  flutuante no ghost, fácil de não perceber com 9 estruturas na lista.
- **Hotbar de 10** numerada (números embaixo dos slots), seleção por tecla
  1..0 e scroll; selecionar ferramenta equipa; E come a comida selecionada.
- **Baú de armazenamento** (`entities/structures/chest.gd`): 20 slots
  próprios, interação F (só o mais próximo responde, mesma regra dos
  portais de run), UI de transferência por drag-and-drop entre baú e
  hotbar (`ui/inventory_slot.gd` generalizado pra "dono" do slot — jogador
  ou baú). Conteúdo persiste no save (grupo `chests`).
- **Portal de Atalho (protótipo inicial)** (`entities/structures/portal_atalho.gd`,
  `items/recipes/portal_atalho.tres`, `items/structures/9c_portal_atalho.tres`):
  criado pelo Crafting (C) com custo de essência e construído direto perto do
  jogador (sem fluxo B). Com dois portais na base, F teleporta entre eles
  (regra "só o mais próximo responde" + cooldown curto pra evitar retorno
  imediato). Persistido pelo SaveManager como qualquer estrutura construída
  (`player_built` + `structure_id`).

### Inimigos
- 4 identidades (`entities/enemy.gd` único, comportamento por export):
  melee (kit 1), rápido/melee (kit 2), à distância com kiting + projétil
  (kit 3, novo), explosivo com fusível + AoE (kit 4, novo). Visual via
  `SpriteFrames` gerado em runtime das strips U/D/S do
  `craftpix_dungeon_kit/enemies/`. Mix por sala pesado pelo `reward_bias`
  do portal (viés combate = mais variedade/risco). Elite aplica a qualquer
  um dos 4 tipos.
- **Elite com afixos reais** (registrado jul/2026 — antes era só stat
  ×1.8): bump de vida menor (1.3×) + 2 afixos sorteados de
  `run_map.gd::ELITE_AFFIXES` (rápido, vampírico, blindado, regenerativo,
  explosivo ao morrer), com label flutuante listando quais (placeholder de
  texto, sem ícone). Ver detalhe de cada um em `docs/funcionalidades.md`.

### Runs (lado roguelite)
- **Talismã** (`entities/structures/talisman.gd`, `StructureDef "talisma"`):
  estrutura construível na base (madeira+pedra), F entra na run — mesma
  regra "só o mais próximo responde" do baú/portais. Sem saída voluntária.
- `WorldLayers` autoload: superfície escondida/desabilitada durante a run;
  mapa gerado a 100k px de offset; fade preto em toda transição;
  `start_run()`/`end_run()` chamados pelo talismã/portal de saída/morte.
- `world/dungeon/run_map.gd`: formato de **arena/sala única** por mapa
  (sem corredores). Mapas normais usam encontro por ondas: começa em 3–5
  inimigos e continua spawnando novas levas até total de 25–30; só então
  surgem os portais de escolha. Mantém zona segura de spawn (190px),
  escala por `map_index` e viés do portal anterior (minério/combate/
  suprimentos), com elites/afixos no viés de combate.
- **Run Modifiers** (registrado jul/2026, `RunModifierDef` .tres em
  `world/dungeon/modifiers/`): `WorldLayers` sorteia UM por run inteira em
  `_do_start_run()` (toast de anúncio via `run_modifier_rolled`), limpo em
  `_do_end_run()`. Getters com fallback neutro (`WorldLayers.
  get_enemy_speed_mult()` etc. — 1.0/0.0 sem modificador, seguro chamar
  sempre). 6 hoje: Escuridão, Fúria Inimiga, Veios Ricos, Armas Frágeis,
  Chefe Fortalecido, Enxame. Modificador novo = `.tres` novo.
- **Portais de escolha** (`run_portal.gd`): 2–3 na sala final, cor+luz por
  tipo; só o portal MAIS PRÓXIMO mostra label e responde ao F.
- **Boss a cada 3 mapas** (`entities/dungeon/boss.gd`, graybox Polygon2D):
  investida e pancada AoE telegrafadas, barra de vida via `_draw`, +40% de
  força por ciclo. Vitória → essência + portal verde de saída.
- **Morte unificada** (pilar: morrer atrasa, nunca pune): em qualquer lugar,
  toast + 2s → acorda em casa com 50% de vida e fome mínima de 50%. O save
  NUNCA é apagado por morte.
- **Props do dungeon são quebráveis** (`entities/dungeon/breakable_prop.gd`,
  anexado a crate_a/b, barrel, pot, rocks_a, sack): 1 golpe, sem ferramenta.
  Fix de bug — antes eram colisão sólida sem `hit()`, e podiam travar
  circulação em trechos da arena durante as ondas.

### Meta-sistemas
- **Save** (`SaveManager`): JSON versionado em `user://save.json` — vida/
  fome/vida máx, inventário, ferramenta, posição, estruturas construídas
  (grupo `player_built` + meta `structure_id`), nós esgotados da superfície,
  objetivos. Autosave 45s + eventos (construir, entrar/sair de run, pause,
  fechar o jogo). Runs nunca salvam (permadeath da run por design).
- **Objetivos** (`ObjectiveTracker` + `ObjectiveDef` .tres em
  `progression/objectives/`): Guardião 2×, 6 essências (cumulativo — gastar
  não desfaz), 4 estruturas → toast "Bioma 2 desbloqueado!" + flag
  persistida (`is_biome_unlocked(2)`). Painel no HUD (O alterna).
- **Pause (ESC)**: volume persistido (`user://settings.cfg`), continuar,
  recomeçar do zero (confirmação dupla; ÚNICO jeito de apagar o save), sair.
  ESC em cadeia: fecha pause > fecha baú > fecha progressão > fecha craft >
  sai do modo construção > pausa.
- **Game feel**: knockback nos inimigos, hit-stop 50ms, fagulhas de acerto.
- **Dash do player** (`player/player.gd`): Shift, instantâneo (sem
  telegraph), ~0.16s de duração, cooldown 0.7s, sem custo de recurso.
  Concede i-frames via `GameState.invulnerable` (novo flag genérico,
  checado em `take_damage()`) — bloqueia ataque e vice-versa, sem
  animação própria (reaproveita walk_ + rajada de partículas).
- **Progressão permanente** (`UpgradeTracker` + `UpgradeDef` .tres em
  `progression/upgrades/`): gasta essência em upgrades permanentes,
  organizados por branch (Combate, Exploração, Construção, Magia — só
  Magia ainda sem conteúdo) com pré-requisito opcional entre eles
  (`requires`). Painel no HUD (U alterna), lista simples (sem grafo
  visual) com botão "Comprar" por linha. 10 upgrades hoje: 2 de dano
  encadeados + cooldown do dash (Combate); alcance de lanterna + chance de
  coleta bônus + velocidade (Exploração); Workbench → Forja → Mesa de
  Alquimia → Mesa de Pesquisa em cadeia (Construção — cada um só
  desbloqueia a estrutura, não mexe em `GameState`, novo
  `Effect.UNLOCKS_STRUCTURE`). Efeitos de stat vivem como multiplicadores
  em `GameState` (`attack_damage_mult`, `dash_cooldown_mult`, `speed_mult`,
  `lantern_range_mult`, `resource_yield_bonus_pct`), reaplicados do zero
  ao carregar o save a partir da lista de comprados.
- Componentes reusáveis: `components/drop_shadow.gd`, `height_sprite.gd`.
- **Menu de cheat (F1)**: só em build de debug (`OS.is_debug_build()`),
  botão "+10" por recurso (data-driven, `ItemDB.get_all()` filtrado por
  `Category.RESOURCE`) + cura/saciedade cheia. Serve pra testar a
  progressão sem precisar rodar runs de verdade toda vez.

## Assets
- `assets/craftpix_dungeon_kit/` — kit dungeon organizado (tiles, objects,
  animated, 4 inimigos em strips U/D/S de 32px, GUI + fonte
  `TinyFontCraftpixPixel.otf`). 18 cenas de props em `entities/dungeon/`,
  tileset em `world/dungeon_tileset.tres` (gerado por script; física nos
  tiles de parede 15:2/16:2). Vitrine: `world/dungeon_props_demo.tscn`.
- Ícones recortados do atlas Kenney em `assets/ui/icons/`.

## Problemas conhecidos / em aberto
1. **Verificar com a build atual** (correções entraram DEPOIS dos últimos
   screenshots): labels de portais sobrepostas (fix: só o mais próximo) e
   brilho geral das runs após ajuste de iluminação (~56% + tochas extras).
2. **A pasta do projeto truncou gravações 3×** (test_biome, resource_node,
   dungeon_tileset — todos recuperados/regenerados): investigar
   OneDrive/antivírus em Downloads; mover o projeto pra fora de Downloads.
3. Essência agora tem a árvore de progressão além do Amuleto — a branch
   Magia ainda está vazia (nenhum `.tres` criado). ~~Picareta II segue
   reservada pra gating futuro~~ — parcialmente resolvido: agora consome
   Picareta I ao craftar (não fica mais redundante no inventário), mas
   ainda não existe nenhum nó de recurso que EXIJA tier 2 pra colher.
4. ~~Bioma 2 desbloqueia mas não existe conteúdo de verdade / borda sem
   gate~~ — **RESOLVIDO em parte**. Região 2 agora tem identidade própria
   ("Terras Corrompidas": ambiente, inimigos reaproveitados com tint+stats,
   recurso próprio) e a borda exige `is_biome_unlocked(2)`. Ainda falta:
   NPCs, estruturas, e um ícone de verdade pro Resíduo Sombrio (hoje sem
   ícone, placeholder deliberado).
5. Regiões 2+ não persistem posição entre sessões (só a base persiste) —
   ver limitação de v1 em `docs/funcionalidades.md` §"Regiões da
   superfície". Se virar problema real no playtest, dá pra salvar
   `current_region_id` + posição local também.
6. ~~Forja/Mesa de Alquimia/Mesa de Pesquisa não apareciam no modo B~~ —
   **RESOLVIDO**. Causa raiz achada pelo Output do editor: `forge.tscn`,
   `alchemy_table.tscn` e `research_table.tscn` tinham `modulate =
   Color(r, g, b)` com só 3 argumentos — válido em GDScript, mas o parser
   de recurso `.tscn`/`.tres` (formato de texto, parser diferente) exige
   sempre os 4 componentes (`Color(r, g, b, a)`). Erro de parse nas 3 cenas
   fazia o `load()` do respectivo `StructureDef` falhar em silêncio dentro
   de `BuildMode._ready()` (sem travar o jogo, só sumindo da lista). Fix:
   adicionado `1.0` de alpha nas 3 linhas. Lição registrada em
   "Convenções" abaixo pra não repetir.
7. ~~Clique do mouse parou de atacar depois da mudança de seleção de
   ferramenta por hotbar~~ — **RESOLVIDO**. Causa: um guard novo
   (`get_viewport().gui_get_hovered_control() != null`) pra impedir que
   clicar num slot da hotbar também disparasse ataque passou a bloquear
   TODO clique, porque o `Control` raiz de tela cheia da HUD não tinha
   `mouse_filter` definido (padrão `STOP` = sempre "hover" em qualquer
   ponto da tela). Fix: `mouse_filter = 2` nesse wrapper. Lição registrada
   em "Convenções" abaixo.
8. ~~Ataque especial (Q) funcionava mesmo sem a espada equipada~~ —
   **RESOLVIDO**. Causa raiz: `GameState.select_slot()` só EQUIPAVA uma
   ferramenta nova quando o slot selecionado tinha uma, mas nunca
   DESEQUIPAVA ao selecionar outra coisa (comida, recurso, slot vazio) —
   `equipped_tool_id` ficava "grudado" na última arma/ferramenta escolhida
   por baixo dos panos, mesmo com a hotbar mostrando outro item
   selecionado. Fix: selecionar qualquer slot que não seja ferramenta/arma
   agora desequipa de verdade. Também corrige o bônus de dano da arma no
   ataque normal, que tinha o mesmo problema.
9. ~~Jogo travava (Out of bounds) ao abrir o painel de craft (C) depois de
   Lança/Martelo~~ — **RESOLVIDO**. Causa: `RECIPE_KEYS` (atalhos 1-9) só
   tinha 9 entradas; passar de 9 pra 10 receitas fez o loop de detecção de
   tecla em `_process()` (hud.gd) estourar o array, sem o mesmo limite que
   `_build_recipe_rows()` já usava. Fix: `RECIPE_KEYS` ganhou o `0` (10
   teclas no total) e os dois loops agora usam o mesmo
   `mini(_recipes.size(), RECIPE_KEYS.size())`. Lição registrada em
   "Convenções" abaixo.
10. **Dois arquivos órfãos em `items/structures/`**: `10_bau_grande.tres` e
    `11_poste_luz.tres` foram criados por engano com prefixo numérico de
    2 dígitos (ver item "Numeração de `.tres` em pasta escaneada" nas
    Convenções) e depois esvaziados pra `Resource` genérico (sem
    `script_class`) em vez de apagados — o sandbox de shell desta sessão
    não enxergava os arquivos do projeto pra rodar `rm` (ver Convenções),
    só as ferramentas de arquivo diretas. `BuildMode._ready()` já ignora
    esses dois graciosamente (`load()` retorna um `Resource` que falha o
    cast pra `StructureDef`, cai no `push_warning` + `continue` existente).
    Sem efeito no jogo, mas se algum dia o shell voltar a enxergar o
    projeto, apagar os dois de verdade é só limpeza.
11. ~~Tecla 10/11 não funcionava no modo construção (B)~~ — **RESOLVIDO**.
    MESMA CLASSE de bug do item 9, só que em `build_mode.gd`: o código
    somava `Input.is_key_pressed(KEY_1 + i)` direto em vez de usar um
    array de teclas — funcionava por acidente até 9 itens (`KEY_1+8 =
    KEY_9`), mas quebrava no 10º (`KEY_1+9` não é `KEY_0`, os codes não são
    sequenciais nessa direção) e não tinha tecla nenhuma pro 11º (Baú
    Grande/Poste de Luz, ver item anterior, deixaram a lista com 11).
    Reportado pelo usuário via screenshot do editor mostrando `[1..11]` no
    painel. Primeira correção: `BuildMode.BUILD_KEYS` (array explícito,
    mesmo padrão de `RECIPE_KEYS`/`HOTBAR_KEYS`) + scroll do mouse
    (`BuildMode._unhandled_input`). Usuário apontou que isso ainda não
    resolvia de verdade — teclado físico nunca vai ter "tecla 10" — e
    pediu o painel igual ao de progressão (U). Fix definitivo: painel do
    modo B virou clicável/scrollável (`hud.gd::_build_row`, um `Button` por
    estrutura chamando `BuildMode.select_index(i)` novo), igual ao padrão
    já usado no painel de progressão; tecla e scroll continuam funcionando
    também, sem se excluir. Precisou de um guard de UI-hover no clique de
    construir (`BuildMode._process()`) pra clicar num botão do painel não
    também tentar construir embaixo dele. Durante a primeira correção, um
    erro de edição colou o polling de clique-pra-construir dentro do
    `_unhandled_input()` novo por engano — pego e corrigido antes de
    finalizar (o polling continua em `_process()`, só o scroll entrou em
    `_unhandled_input()`).
12. ~~Números de contagem cortados na hotbar~~ — **RESOLVIDO**. Reportado
    pelo usuário via screenshot ("x75" etc. levemente cortado). Causa:
    `CountLabel` em `inventory_slot.tscn` tinha uma caixa de 21×17px pra
    fonte 13 + contorno 3 — apertado demais pra 2-3 dígitos. Fix: caixa
    32×20px, fonte 12, `clip_text = false` explícito.
13. **Painel de craft (C) também virou clicável/scrollável preventivamente**
    (jul/2026, junto com a Mesa de Pesquisa): a lista de receitas cortava
    nas primeiras `RECIPE_KEYS.size()` (10) — igual ao painel de
    construção antes do fix do item 11 — e as 2 receitas novas
    (Lanterna Avançada, Amuleto Vital II) levavam o total a 12, o que ia
    escondê-las de verdade (sem tecla, sem clique, invisíveis) assim que
    fossem criadas. Corrigido ANTES de adicionar as receitas, não depois:
    `CraftingPanel` em `hud.tscn` ganhou `Scroll/RecipesVBox`
    (`ScrollContainer` + `VBoxContainer`, painel cresceu de 320×200 pra
    440×440), e `hud.gd::_build_recipe_row` cria um `Button` por receita
    em vez de ícone+`Label`. Tecla 1..0 continua funcionando pras 10
    primeiras.
14. **`research_table.tscn` não tinha grupo nenhum atribuído** — diferente
    de `forge.tscn` (`groups=["forja"]`) e `workbench.tscn`
    (`groups=["workbench"]`), a Mesa de Pesquisa nunca tinha sido ligada
    ao sistema de `_near_station`. Só virou um problema de verdade agora
    que a primeira receita com `required_station = "mesa_pesquisa"` foi
    criada (item 2 de "Próximos passos") — sem o grupo, a receita nunca
    encontraria a estação por perto, não importa a distância. Corrigido
    junto: `groups=["mesa_pesquisa"]` adicionado à cena. `alchemy_table.tscn`
    tinha o MESMO problema (achado ao implementar o item 15 abaixo) — sem
    receita nenhuma ainda, então nunca tinha dado sintoma visível.
15. **Interação por E nas estações** (jul/2026, pedido do usuário depois de
    ver o menu geral de craft ficando cheio): Forja/Mesa de Pesquisa/Mesa
    de Alquimia/Workbench ganharam `entities/structures/station_interact.gd`
    (script reusado nas 4 via `@export station_group/
    station_display_name` — mesmo padrão de "chest.gd reusado pelo Baú e
    Baú Grande via export"). E abre o painel de craft do HUD já FILTRADO
    só pelas receitas daquela estação (`hud.gd::open_station_crafting`);
    Workbench (ajuste posterior na mesma linha de trabalho) lista
    **Baú Grande/Poste de Luz** como ações de **construção** e inicia o
    `BuildMode` focado nessas duas estruturas ao clicar. Groups deixaram de vir
    só do `.tscn` estático — o script agora chama `add_to_group
    (station_group)` no `_ready()`, pra não repetir o bug dos itens 14/
    esse mesmo (esquecer de atribuir o grupo na cena).
16. **Função da Mesa de Alquimia** (jul/2026): sistema de multiplicador
    TEMPORÁRIO novo em `GameState` (3 canais fixos — `potion_speed_mult`/
    `potion_attack_mult`/`potion_defense_mult` — cada um com timer próprio
    contado em `_process`, expira sozinho e emite `potion_expired`; ver
    `GameState.apply_potion`). 3 receitas novas (`required_station =
    "mesa_alquimia"`, custo só em recursos base — fibra/comida/minério/
    pedra, de propósito sem essência): Poção de Velocidade (+35%, 60s),
    Poção de Força (+30% dano, 60s), Poção de Proteção (-30% dano
    recebido, 60s). Craftar = beber na hora (mesmo padrão instantâneo do
    Amuleto Vital, `RecipeDef.potion_channel/potion_mult/potion_duration`).
    Sem arte de frasco no projeto ainda — as 3 usam ícone placeholder
    gerado em código (`PlaceholderIcons.potion_icon`, cor do líquido por
    canal) em vez de reaproveitar um ícone só, porque aqui (diferente do
    Amuleto Vital) são 3 itens que precisam ser diferenciáveis entre si.
17. **Polimento pós-Mesa de Alquimia** (jul/2026, feedback do usuário
    testando a build):
    - Poções não aparecem na hotbar — **intencional**, mesmo padrão
      instantâneo do Amuleto Vital (craftar = já aplicar o efeito, sem item
      passando pelo inventário).
    - **Craft geral (C) restrito ao básico**: Amuleto Vital (T1) tinha
      `required_station = ""` e craftava em qualquer lugar, fugindo do
      padrão "nível 2 só nas mesas" — movido pra `required_station =
      "mesa_alquimia"`. Geral (C) sem estação por perto agora só mostra
      Machado I, Picareta I, Lanterna e Refeição Reforçada.
    - **Cheat (F1)**: loop de botões passou a incluir categoria FOOD além
      de RESOURCE (Cogumelo/Refeição Reforçada apareciam de fora antes).
      Painel reancorado de `CENTER_LEFT` pra `TOP_LEFT` + lista dentro de
      um `ScrollContainer` (240×420) — cortava no canto inferior esquerdo
      conforme a lista crescia.
    - **Fome mais lenta**: `GameState.hunger_drain_per_second` 0.3 → 0.15
      (dobra o tempo até zerar com fome cheia, ~11min).
    - **"Bug" investigado**: vida/fome restauradas ao comer variavam
      conforme a comida SELECIONADA (`ItemDef.hunger_restore`/`heal_amount`
      por item — Cogumelo só fome, Refeição Reforçada fome+cura bem
      maiores), reportado pelo usuário como "muda dependendo do item
      equipado". Não era bug de fato (era por design) — 1ª tentativa foi
      igualar tudo num valor fixo, mas o usuário pediu de volta a Refeição
      mais forte (ver item 18 abaixo: a queixa de fundo era a ESCALA da
      barra de vida mudando por causa do Amuleto Vital, não a comida).
18. **Amuleto Vital vira item PASSIVO real** (jul/2026, pedido do usuário
    depois do item 17: "quero barra de vida fixa" + "o amuleto também deve
    ser algo levado no inventário, boost permanente enquanto estiver
    'equipado' — só estar no hotbar já conta"). Reversão + redesenho:
    - `player.gd::_eat()` voltou a usar `ItemDef.hunger_restore`/
      `heal_amount` por item (Refeição Reforçada de novo +60 fome/+30 vida,
      Cogumelo só +25 fome) — a tentativa de valor fixo do item 17 foi
      desfeita.
    - `ItemDef` ganhou `Category.PASSIVE` + `passive_bonus_max_health`.
      Amuleto Vital e Amuleto Vital II (`items/defs/amuleto_vital*.tres`)
      viraram itens de verdade (`result_id` na receita, antes era `""`)
      em vez de efeito instantâneo sem item.
    - `GameState._recompute_passive_bonuses()` (novo, conectado em
      `inventory_changed`): soma `passive_bonus_max_health` de tudo que
      estiver em QUALQUER slot do inventário principal (não precisa estar
      selecionado — só não pode estar guardado num baú) e recalcula
      `max_health = BASE_MAX_HEALTH (100, nova const) +
      passive_bonus_max_health`. Ganhar cura o delta na hora e emite
      `passive_bonus_changed` (toast "Vida máxima aumentada em X", mesmo
      padrão do toast de poção); perder reduz o teto sem dano extra e
      mostra "reduzida". `max_health` nunca mais é somado direto de fora
      (antes `hud.gd::_try_craft` fazia `GameState.max_health +=
      recipe.bonus_max_health` sem ligação com o inventário — o teto só
      crescia, nunca voltava, e sumir com o item não fazia diferença
      nenhuma; o código genérico continua em `_try_craft` pra receitas
      futuras, só não é mais usado pelos amuletos).
    - `save_manager.gd::load_game()` reordenado: inventário carrega e
      dispara o recálculo (com `GameState._silent_passive_recompute = true`
      pra não mostrar o toast toda vez que um save com amuleto abre) ANTES
      de aplicar vida/fome salvas — senão o clamp usaria um `max_health`
      errado (100 base, sem contar os amuletos guardados).
19. **Bug real: craft geral (C) não escondia receita de estação** (jul/2026,
    achado pelo usuário via print — o item 17 moveu o Amuleto Vital pra
    `required_station` mas ele continuou aparecendo no C geral igual).
    Causa: `hud.gd::_build_recipe_rows` só filtrava a visão FILTRADA (E
    numa estação); a visão geral nunca escondia nada, só acrescentava
    "(perto de X)" no texto — barrado só na hora do craft
    (`_try_craft`), não na listagem. Toda receita com `required_station`
    setado (Amuleto Vital, Lanterna Avançada, Amuleto Vital II, as 3
    poções, até Lança/Martelo da Forja) aparecia solta no C. Corrigido
    trocando a condição por comparação direta
    (`r.required_station != _crafting_station_filter`) — cobre os dois
    casos (geral só mostra sem estação; filtrado só mostra da própria
    estação) numa linha só. Hint "(perto de X)" removido junto, virou
    inatingível depois do fix.
20. **Baú Grande/Poste de Luz passam a exigir o upgrade da Workbench**
    (jul/2026, pedido do usuário: apareciam no modo B mesmo antes de
    comprar/construir a Workbench, e a lista informativa deles no painel
    de craft filtrado pela Workbench (E) confundia com "dá pra craftar no
    C"). Os dois ganharam `required_upgrade_id = "constr_workbench"` (o
    MESMO upgrade que libera a própria Workbench) — reverte a decisão
    original do item "Função da Workbench" abaixo, que deixava os dois
    sem upgrade de propósito. Ajuste posterior: em vez de sumirem do
    painel da Workbench, passaram a aparecer ali como botões de
    **[construir]**, iniciando o `BuildMode` pela interação E e saindo da
    lista geral do B.
21. **Barra de vida + número de dano nos inimigos comuns** (jul/2026,
    pedido do usuário). `entities/enemy.gd` ganhou `_draw()` com barra de
    vida flutuante (mesma receita que o Boss já tinha sozinho em
    `boss.gd::_draw()`, só menor — 36×5px vs 64×7px), redesenhada via
    `queue_redraw()` toda vez que `health` muda (hit, regen do afixo
    "regenerating", cura do afixo "vampiric"). Novo utilitário estático
    `entities/damage_numbers.gd` (`class_name DamageNumbers`, mesmo padrão
    do `PlaceholderIcons` — sem estado, só uma função `spawn()`) cria um
    Label vermelho "-N" que sobe e desaparece no ponto do acerto; chamado
    de `enemy.gd::hit()` (depois da redução do afixo "shielded", então
    mostra o valor JÁ reduzido) e `boss.gd::hit()`.

22. **Diagnóstico: Baú Grande/Poste de Luz continuam sumidos mesmo com
    "constr_workbench" comprado (jul/2026) — RESOLVIDO, não era bug**:
    revisão completa do código (`9a_bau_grande.tres`/`9b_poste_luz.tres` com
    `required_upgrade_id = "constr_workbench"`, id bate exatamente com
    `constr_workbench.tres`, `UpgradeTracker.is_purchased` é a MESMA função
    que o painel U usa pro ✓, ordem dos autoloads em `project.godot` faz
    `BuildMode` conectar em `UpgradeTracker.purchased` ANTES de
    `SaveManager.load_game()` reemitir as compras salvas) não achou nenhum
    motivo lendo o código. Adicionado diagnóstico permanente em build de
    debug (`BuildMode._ready()`/`_refresh_available()`, print "BuildMode:
    estruturas carregadas..."/"... escondida ..."). O print revelou
    `is_purchased == false` pra TODOS os upgrades de Construção, mesmo com
    ✓ no painel U — causa raiz confirmada pelo usuário: ele tinha usado
    "Recomeçar do zero" (menu de pause), que dá `UpgradeTracker.reset()` +
    `SaveManager.wipe()`, achando que só reiniciava a run; o print vinha de
    ANTES de ele recomprar os upgrades no save resetado. Confirmado com
    save novo e print limpo: com só a Workbench comprada, Baú Grande e
    Poste de Luz já aparecem na interação E da Workbench como opções de
    construção (e não na lista geral do B).
    Diagnóstico dos prints mantido (gated por `OS.is_debug_build()`, não
    afeta build de release).
    Efeito colateral notado ao testar: ao liberar Forja/Mesa de
    Alquimia/Mesa de Pesquisa também, Baú Grande/Poste de Luz "somem" da
    área visível do painel — não é bug, é o `ScrollContainer` de altura
    fixa (420px, mesmo padrão do painel de cheat) que só mostra ~9 linhas
    de cada vez; a ordem de `_all_defs` é alfabética por nome de arquivo
    (`9_research_table.tres` < `9a_bau_grande.tres` < `9b_poste_luz.tres`),
    então Baú Grande/Poste de Luz viram itens [10]/[11] e ficam abaixo da
    dobra — basta rolar o painel (scroll do mouse ou arrastar a barra) pra
    ver. Comentário em `hud.gd` (linhas ~767-770) já documentava esse
    limite: teclas 1-0 só cobrem as 10 primeiras, item 11+ mostra
    "[scroll]" no lugar do número, mas o clique na linha sempre funciona.
23. **Barra de vida "muda de largura visualmente" sem o número mudar**
    (jul/2026, confirmado pelo usuário depois do número aparecer na
    barra): nenhum código escreve em `health_bar`/`hunger_bar` fora de
    `_on_health_changed`/`_on_hunger_changed`, que atualizam valor E
    label juntos — não deveria dessincronizar. Aplicado fix defensivo:
    `HealthBar`/`HungerBar` ganharam `size_flags_horizontal/vertical = 0`
    (antes sem size_flags explícito, sujeitos a esticar pro tamanho do
    `VBoxContainer` pai) e o Label "Ferramenta: X" (mesmo VBoxContainer,
    texto de tamanho variável a cada troca de arma) ganhou
    `custom_minimum_size`/`clip_text`/`size_flags_horizontal = 0` fixos —
    elimina qualquer chance de o container reagir ao texto variável e
    esticar as barras junto. Ainda não confirmado se resolve de verdade
    (sem acesso pra rodar o jogo) — pedir pro usuário testar de novo.
24. **Troca visual da barra de vida por imagens fornecidas pelo usuário**
    (jul/2026): `ui/hud.tscn` migrou `HealthBar` de `ProgressBar` para
    `TextureProgressBar`, com textura de fundo (vida vazia) e progresso
    (vida cheia) via `AtlasTexture` recortado; depois recebeu ajuste fino
    no recorte horizontal para eliminar o último espaço branco à direita;
    `ui/hud.gd` tipou
    `health_bar` como `Range` (continua compatível com update por `value`/
    `max_value`). O texto numérico (`ValueLabel`) permaneceu por cima.
25. **Redesign minimalista de Vida/Fome (sem arte final)**
    (jul/2026, pedido do usuário em inglês): prioridade mudou de textura
    para legibilidade/game feel. `ui/hud.tscn` foi reestruturado com
    `VitalsCard` + `HealthMeter` + `HungerMeter` (painéis arredondados,
    spacing e hierarquia), mantendo no mesmo HUD. `ui/hud.gd` preservou os
    sinais atuais (`health_changed`/`hunger_changed`) e passou a aplicar:
    interpolação suave via `Tween`, flash curto ao tomar dano, pulso em
    vida baixa (<=25%) e aviso visual distinto de fome crítica (<=20%,
    label + pulso). Implementação ficou parametrizada por `@export` para
    tuning rápido sem mexer na lógica de gameplay.
26. **HUD ainda mais limpa por hover de texto em Vida/Fome**
    (jul/2026): rótulos e números das barras (`VIDA/FOME`, `atual / máximo`)
    agora ficam ocultos por padrão e aparecem só no `mouse_entered` de cada
    medidor (`HealthMeter`/`HungerMeter`). Mantém os mesmos sinais e lógica
    de update, reduzindo ruído visual sem perder informação sob demanda.
    Ajuste seguinte eliminou flick de hover trocando toggle de `visible` por
    controle de opacidade (`modulate.a`) e `mouse_filter = IGNORE` nos labels.
27. **Card de vitais colapsável com expansão no hover**
    (jul/2026): para evitar a sensação de "área específica da borda", o
    trigger passou a ser direto nas barras (`HealthBar`/`HungerBar`), e o
    card inteiro anima entre dois tamanhos (`vitals_collapsed_height` /
    `vitals_expanded_height`) com tween curto. Colapsado mostra só as barras;
    expandido revela títulos e valores.
28. **Sprint 1 do ciclo de dia/noite**
    (jul/2026): `autoload/world_layers.gd` ganhou relógio global da
    superfície (`_time_of_day_ratio`, 1 minuto por ciclo em teste), fases nomeadas
    (`dia`, `entardecer`, `noite`, `amanhecer`), sinais públicos
    (`day_phase_changed`, `time_of_day_changed`) e persistência via
    `save_manager.gd`. O `LitCanvasModulate` de cada região usa sua cor-base
    armazenada em meta e recebe um multiplicador de brilho por fase, sem
    apagar a identidade própria da cena. Pressão inicial: à noite surgem
    inimigos extras ao redor do jogador (`night_surface_enemy`) em lotes,
    com buff mais forte e zona segura perto da base; amanhecer limpa esses
    spawns.

## Próximos passos (ordem recomendada)
1. ~~Função da Workbench~~ — **RESOLVIDO** (jul/2026, decisão do usuário:
   "Baú Grande + estruturas de conforto"). Workbench usa o próprio E pra
   listar/construir duas `StructureDef` (**Baú Grande** e **Poste de Luz**),
   ambas com `required_upgrade_id = "constr_workbench"` e
   `requires_workbench_nearby`; elas não aparecem no fluxo geral do B.
   Baú Grande: 40 slots (`chest.gd::slot_count` virou `@export`, era const
   fixa em 20). Poste de Luz: mesma luz por ponto da Tocha, alcance/energia
   maiores. Ver `docs/funcionalidades.md`.
2. ~~Função da Mesa de Pesquisa~~ — **RESOLVIDO** (jul/2026, mesmo padrão da
   Forja: `RecipeDef.required_station = "mesa_pesquisa"`, sem sistema
   novo). Duas receitas novas: **Lanterna Avançada** (consome 1 Lanterna,
   alcance/energia de luz maiores — `player.gd::_update_lantern` agora
   checa dois tiers) e **Amuleto Vital II** (6 essência → +40 HP
   permanente, mesmo padrão do Amuleto Vital original). Bug encontrado no
   processo: `research_table.tscn` não tinha NENHUM grupo atribuído — a
   estação existia fisicamente mas `_near_station("mesa_pesquisa")` nunca
   ia encontrá-la; corrigido junto (`groups=["mesa_pesquisa"]`).
3. ~~Função da Mesa de Alquimia~~ — **RESOLVIDO** (jul/2026). 3 poções
   temporárias (Velocidade/Força/Proteção), sistema de multiplicador com
   duração novo em `GameState` (`apply_potion`/`potion_*_mult`). Ver item
   16 do histórico acima e `docs/funcionalidades.md`.
4. ~~Polimento de combate: novos tipos de ataque pro jogador (área, longa
   distância, especial)~~ — **RESOLVIDO em boa parte**. Entregue: ataque
   especial em área (Q) hoje ROTEADO POR ARMA (Espada gira, Lança vira
   cone longo `SPECIAL_LANCE_RANGE=220`, Martelo sempre atordoa
   `SPECIAL_HAMMER_STUN_DURATION=1.6s` — antes era genérico, o mesmo giro
   pra qualquer arma), "ataque rápido" durante o dash, 3 armas com
   moveset próprio via Forja (Espada/Lança/Martelo), ícones geométricos
   próprios pra cada arma no inventário, e um flash geométrico no MOMENTO
   do golpe de Lança (retângulo)/Martelo (anel) — resolve o "sempre
   parece golpe de espada" já que o `AnimatedSprite2D` do Swordsman
   continua sendo o mesmo swing pra qualquer arma (ver "Convenções" e
   `docs/funcionalidades.md`). O martelo introduziu `Enemy.stun()`, ainda
   sem uso em nenhum inimigo além de reagir ao jogador. Falta, se quiser
   ir além: identidade de inimigo por arma (espada/martelo/lança/explosivo
   nos próprios inimigos — discutido jul/2026, adiado; precisa fechar
   quantos tipos + o que cada um faz ANTES de implementar, e um stun
   inverso — inimigo atordoando o jogador via `GameState` — pro caso
   simétrico).
5. **Portal de atalho** — **EM PROGRESSO**: protótipo inicial já criado
   (receita no C + estrutura persistente + teleporte portal↔portal na base).
   Próximo passo: evolução para fast-travel entre regiões do mundo (não é
   Talismã e não interfere no loop de run).
6. **NPC resgatável + diretor de encontros v1** (T3 do plano): sala de NPC
   injetada na run por flag de quest, resgate → NPC na base com 1 serviço.
7. Playtest externo de 30 min; depois seguir o `docs/plano-2-anos.md`.
8. **Raids na base**: ainda sem mecânica desenhada (gatilho, frequência,
   quem ataca) — projetar quando o resto do loop estiver validado no
   playtest.

## Convenções pra quem continuar
- Conteúdo novo = criar `.tres` (item/receita/estrutura/objetivo), nunca
  hardcodar. Cenas de entidade: origem nos pés, colisor na pegada, sombra.
- Graybox primeiro: código nunca espera arte; o visual é um nó trocável.
- Autoloads (ordem importa): ItemDB, GameState, PhantomCameraManager,
  LitManager, CursorManager, WorldLayers, RecipeDB, UpgradeTracker,
  BuildMode, ObjectiveTracker, SaveManager. UpgradeTracker precisa vir
  antes de BuildMode porque BuildMode consulta upgrades comprados
  (`required_upgrade_id`) já no `_ready()`.
- Conferir a integridade de arquivos após gravações grandes (item 2 acima).
- **`Color(...)` em `.tscn`/`.tres` sempre com os 4 argumentos** (`r, g, b, a`).
  O parser de recurso texto (diferente da expressão GDScript, que aceita
  3 argumentos com alpha implícito) rejeita a forma curta com um parse
  error silencioso — o `.tscn` inteiro falha ao carregar, mas quem chama
  `load()` só recebe `null`, sem crash. Causou um bug real (item 6 de
  "Problemas conhecidos/resolvidos").
- **Toda funcionalidade nova implementada = atualizar `docs/funcionalidades.md`
  na mesma sessão.** É o catálogo completo do que já existe; deixa de servir
  pra continuidade se ficar desatualizado.
- **Controles de tela cheia (full-rect) na HUD precisam de `mouse_filter =
  2` (IGNORE) explícito**, senão viram um "vidro" invisível que captura
  hover em qualquer ponto da tela — mesmo onde não tem nenhum botão visível
  — e qualquer código que confira `get_viewport().gui_get_hovered_control()`
  pra distinguir clique-na-UI de clique-no-mundo passa a achar que a UI
  está sempre no caminho. Causou um bug real: o clique do mouse pra atacar
  parou de funcionar por completo assim que um guard desse tipo foi
  adicionado (`Control` raiz de `ui/hud.tscn`, `anchors_preset = 15`, sem
  `mouse_filter` definido = padrão `STOP`). Corrigido definindo
  `mouse_filter = 2` só nesse wrapper raiz — os painéis/slots reais
  (que têm fundo visível e devem mesmo bloquear clique) continuam com o
  padrão.
- **Armas com moveset próprio** (`ItemDef.weapon_type`, jul/2026): dano
  continua um número só (`weapon_damage_bonus`), mas o FORMATO do golpe
  (alvo único/perfura linha/área) é uma string (`""`/"espada"/"lanca"/
  "martelo") que `player.gd::_attack` usa num `match` pra rotear pra
  `_attack_sword`/`_attack_lance`/`_attack_hammer`. Todas as 3 reaproveitam
  o mesmo `_query_hittable(shape, center)` genérico (`PhysicsShapeQueryParameters2D`,
  não depende do overlap cacheado da `AttackArea`) — adicionar uma arma
  nova com moveset MUITO diferente (ex.: arma à distância) provavelmente
  só precisa de mais um `Shape2D` + mais um `case` no match, não sistema
  novo. Efeitos extras (como o stun do Martelo) são opcionais: quem ataca
  confere `has_method("stun")` antes de chamar, então nem todo alvo
  precisa suportar — Boss e nós de recurso ficam imunes de graça, sem
  exceção especial no código.
- **`@export_enum(...)` não aceita `""` (string vazia) como opção** — dá
  parse error no arquivo inteiro (e quebra em cascata qualquer script que
  dependa da classe, com uma mensagem confusa tipo "could not resolve
  external class member" em outro arquivo). Se o valor válido default de
  um campo é `""`, não dá pra usar `@export_enum` nele — só `@export var
  campo: String = ""` mesmo, texto livre com o significado documentado em
  comentário.
- **Arrays de tamanho fixo pareados com "quantidade de conteúdo
  data-driven" são uma bomba-relógio** (`RECIPE_KEYS` tinha 9 teclas pra
  atalho 1-9; a 10ª receita — Martelo — estourou o array e travou o jogo
  ao abrir o painel de craft). Sempre que um array como esse existir
  (teclas, slots, cores por índice...), ou ele cresce junto com o
  conteúdo que ganha `.tres` novo com frequência, ou todo loop que o usa
  precisa de `mini(tamanho_do_conteúdo, tamanho_do_array)` — nunca supor
  que "sempre vai caber".
- **Graybox de ícone/sprite: geometria própria, não reaproveitar um sprite
  genérico pra várias coisas diferentes** (decisão do usuário, jul/2026).
  Espada/Lança/Martelo reaproveitavam o mesmo `recipe_tool.png` e ficavam
  idênticas no inventário — confuso, especialmente com movesets diferentes
  cada. Padrão adotado: gerar o ícone em CÓDIGO (`Image` + `fill_rect`,
  ver `items/placeholder_icons.gd`) com uma silhueta simples e distinta
  por tipo, em vez de caçar/reaproveitar sprite pronto. Vantagem extra:
  não depende de escrever `.png` novo no projeto (binário não é confiável
  neste ambiente, ver histórico). `ItemDB._ready()` só usa o placeholder
  se o `.tres` deixar `icon` vazio — arte de verdade sempre tem
  prioridade, basta setar `icon` no `.tres` quando ela existir. Extensível
  pra outros casos (afixo de elite, tipo de inimigo, tipo de recurso) se
  a confusão visual continuar incomodando no playtest.
- **Numeração de `.tres` em pasta escaneada por `dir.get_files() +
  files.sort()` (registrado jul/2026)**: `items/structures/` usa prefixo
  numérico (`1_cerca.tres` ... `9_research_table.tres`) só pra ordem visual
  na pasta — o índice real no modo B vem da posição no array carregado,
  não do nome do arquivo. Armadilha: `sort()` é lexicográfico
  (string), então `"10_..."` vem ANTES de `"2_..."` (compara char a char:
  `'1' == '2'`? não — `'1' < '2'`, então qualquer `"1..."` vem antes de
  `"2_..."`, incluindo `"10_"`, `"11_"` etc.) — passar de 9 pra 10+
  arquivos com essa convenção reordena tudo de forma não-óbvia. Fix usado
  ao adicionar a 10ª e 11ª estrutura: prefixo `"9a_"`/`"9b_"` (mantém
  ordenação correta sem tocar nos 9 arquivos existentes). Se a pasta um dia
  passar de ~15 arquivos, vale trocar todos pra zero-padded (`01_`...`11_`)
  de uma vez.
- **O sandbox de shell (bash) desta sessão não enxerga os arquivos do
  projeto de forma confiável** — `ls`/`find`/`rm` em `items/`,
  `items/structures/` etc. retornam "No such file or directory" mesmo
  para arquivos que as ferramentas de arquivo diretas (`Read`/`Write`/
  `Edit`/`Glob`) leem e escrevem sem problema. Não é só o problema já
  conhecido de escrever binário — leitura E remoção também falham. Pra
  qualquer operação neste projeto (ler, criar, editar, e principalmente
  APAGAR arquivo), usar sempre as ferramentas de arquivo diretas; não
  assumir que um `rm` via shell vai funcionar só porque
  `allow_cowork_file_delete` foi concedido — o gargalo é o mount do shell
  em si, não a permissão.
