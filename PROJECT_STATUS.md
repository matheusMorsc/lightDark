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

WASD/setas move · Espaço/clique ataca (alvo único priorizado; agora
funciona durante o dash e numa janela curta depois, com alcance maior —
"ataque rápido", jul/2026) · Shift dash (instantâneo, i-frames curtas,
cooldown) · Q ataque especial em área, dano instantâneo + cooldown 2.5s,
só com arma equipada (jul/2026, ver "Convenções") ·
1..0/scroll/clique seleciona hotbar — se o slot for ferramenta/arma,
equipa na hora, qualquer outra coisa desequipa (sem tecla dedicada de
troca, ver "Convenções") · clique direito come a comida SELECIONADA na
hotbar (mudou jul/2026 — antes E comia a primeira comida do inventário
automaticamente) · M mapa · C craft (ESC fecha) · U progressão permanente
(ESC fecha) · B constrói · O painel de objetivos · F interage (baú,
talismã, portais) · ESC pause · F1 menu de cheat (só build de debug).

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
  Workbench já erguida; a Workbench em si não exige nada além do upgrade
  comprado. Decisão do usuário, resolve a ambiguidade que estava em aberto
  desde a sessão anterior.

## Sistemas implementados

### Perspectiva e mundo
- Migração top-down → Don't Starve-like completa: `Entities` com Y-sort em
  toda cena, origem dos nós nos pés, colisores = pegada da base (cápsulas),
  occluders na base, foreshortening vertical 0.8 no movimento.
- Camadas de física: 1=world, 2=player, 3=enemies. Inimigos NÃO colidem com
  o player (dano é por distância) — nada de prensar o jogador em fila.
- Cena principal: `world/biome_1.tscn` (região 1, a base — sempre viva).
- Iluminação: addon Lit. Superfície ~65% de ambiente; runs 30% (escuras de
  propósito — lanterna importa). Fundo preto via `default_clear_color`.

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
- **Tier II como upgrade + Estações com função (registrado jul/2026)**:
  Machado II/Picareta II agora CONSOMEM a ferramenta Tier I (não são mais
  itens soltos e redundantes) e só craftam perto de uma Forja
  (`RecipeDef.required_station`, checado em `hud.gd::_near_station` — o
  mesmo raio/ideia do `BuildMode._workbench_nearby`, mas a partir do
  jogador). Primeira arma pura do jogo: **Espada da Forja**
  (`ItemDef.weapon_damage_bonus = 15`, aplicado em `player.gd::_attack()`
  via `_equipped_weapon_bonus()`) — machado/picareta nunca deram dano de
  combate, isso é novo. Sem ícone ainda (placeholder). Primeiro passo de um
  plano maior: dar função própria às 4 estações (Workbench, Alquimia e
  Pesquisa ainda faltam).
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

### Inimigos
- 4 identidades (`entities/enemy.gd` único, comportamento por export):
  melee (kit 1), rápido/melee (kit 2), à distância com kiting + projétil
  (kit 3, novo), explosivo com fusível + AoE (kit 4, novo). Visual via
  `SpriteFrames` gerado em runtime das strips U/D/S do
  `craftpix_dungeon_kit/enemies/`. Mix por sala pesado pelo `reward_bias`
  do portal (viés combate = mais variedade/risco). Elite (viés combate)
  aplica a qualquer um dos 4 tipos.

### Runs (lado roguelite)
- **Talismã** (`entities/structures/talisman.gd`, `StructureDef "talisma"`):
  estrutura construível na base (madeira+pedra), F entra na run — mesma
  regra "só o mais próximo responde" do baú/portais. Sem saída voluntária.
- `WorldLayers` autoload: superfície escondida/desabilitada durante a run;
  mapa gerado a 100k px de offset; fade preto em toda transição;
  `start_run()`/`end_run()` chamados pelo talismã/portal de saída/morte.
- `world/dungeon/run_map.gd`: drunkard-walk de salas + corredores em L,
  paredes com colisão via tiles, **trilha de tiles claros** do spawn até a
  sala final, zona segura de spawn (190px), conteúdo escalado por
  `map_index` e pelo **viés** escolhido no portal anterior (minério/combate/
  suprimentos). Elites avermelhados no viés de combate.
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
  Fix de bug — antes eram colisão sólida sem `hit()`, e podiam (raramente)
  fechar a única passagem de uma sala gerada, prendendo o jogador na run.

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
   run escura demais (ambiente 30% + fundo preto). Se continuar escuro
   demais, subir `color` do `LitCanvasModulate` em `run_map.tscn` p/ ~0.45.
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

## Próximos passos (ordem recomendada)
1. **Função da Workbench**: móveis/melhorias básicas (decisão de escopo do
   usuário, jul/2026) — Forja já resolvida (ver "Estações com função" em
   `docs/funcionalidades.md`).
2. **Função da Mesa de Pesquisa**: desbloqueios/receitas especiais — mesmo
   padrão de dado (`RecipeDef.required_station`), sem sistema novo.
3. **Função da Mesa de Alquimia**: poções/buffs temporários — a mais
   arriscada das 4, precisa de um sistema de efeito com duração/expiração
   que ainda não existe em `GameState` (hoje só há multiplicadores
   permanentes e o flag binário `invulnerable`).
4. **Polimento de combate**: novos tipos de ataque pro jogador (área,
   longa distância, especial) — decisão do usuário foi sequenciar depois
   das estações, pra ter armas novas saindo delas que justifiquem movesets
   diferentes em vez de reformar o combate no vácuo.
5. **Portal de atalho** (branch Construção ou Magia — decidir): estrutura
   de fast-travel entre regiões distantes do mesmo mundo. NÃO é o Talismã
   (esse continua sendo a única entrada pra run) — é conveniência de
   deslocamento, agora que já existe mais de uma região pra viajar entre.
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
