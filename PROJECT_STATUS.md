# Light in the Dark — Estado do Projeto (handoff)

> Documento de continuidade: cole no início de um novo chat (ou peça pra ler
> `PROJECT_STATUS.md`). Docs complementares: `docs/plano-2-anos.md` (roadmap)
> e `docs/perspective-migration.md` (migração de perspectiva, ref. técnica).

## Visão

Survival/base-building 2D (Godot 4.7) com **superfície fixa e persistente**
(lado Stardew) + **runs procedurais estilo Hades** acessadas por um talismã
(tecla T): mapas encadeados por portais de escolha, boss a cada 3 mapas,
materiais raros movem a progressão. Perspectiva pseudo-isométrica estilo
Don't Starve (2D puro, Y-sort, âncora nos pés). Arte atual é 100% placeholder
(Kenney + Craftpix); a arte final será desenhada à mão pela dupla.

## Controles

WASD/setas move · Espaço/clique ataca (alvo único priorizado) · E come ·
Q troca ferramenta · 1..0/scroll seleciona hotbar · C craft (ESC fecha) ·
B constrói · O painel de objetivos · T talismã (entra/sai da run) ·
F interage (portais) · ESC pause.

## Sistemas implementados

### Perspectiva e mundo
- Migração top-down → Don't Starve-like completa: `Entities` com Y-sort em
  toda cena, origem dos nós nos pés, colisores = pegada da base (cápsulas),
  occluders na base, foreshortening vertical 0.8 no movimento.
- Camadas de física: 1=world, 2=player, 3=enemies. Inimigos NÃO colidem com
  o player (dano é por distância) — nada de prensar o jogador em fila.
- Cena principal: `world/biome_1.tscn` (superfície do bioma 1, fixa).
- Iluminação: addon Lit. Superfície ~65% de ambiente; runs 30% (escuras de
  propósito — lanterna importa). Fundo preto via `default_clear_color`.

### Loop de superfície
- **Itens data-driven**: `ItemDef` (.tres em `items/defs/`) — categoria,
  stack, ferramenta (tipo+tier), comida (fome+cura). `ItemDB` carrega a pasta.
- **Ferramentas com gating**: fibra/pedra à mão → Machado I → madeira →
  Picareta I → minério → Picareta II. Nós de recurso (`resource_node.gd`)
  exigem tipo+tier EQUIPADO e têm drop tables; aviso "Requer X" flutuante.
- **Receitas data-driven**: `RecipeDef` (.tres em `items/recipes/`); o painel
  de craft do HUD se monta sozinho. Lanterna (luz pessoal forte só com o
  item), Refeição (comida consumível), Amuleto Vital (3 essências → +25 HP).
- **Construção (B)**: `BuildMode` autoload + `StructureDef` (.tres em
  `items/structures/`): cerca, fogueira, tocha. Ghost com snap, validade por
  física/custo/alcance, custo em recursos descontado direto.
- **Hotbar de 10** numerada (números embaixo dos slots), seleção por tecla
  1..0 e scroll; selecionar ferramenta equipa; E come a comida selecionada.

### Runs (lado roguelite)
- `WorldLayers` autoload: superfície escondida/desabilitada durante a run;
  mapa gerado a 100k px de offset; fade preto em toda transição; T alterna.
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
  ESC em cadeia: fecha pause > fecha craft > sai do modo construção > pausa.
- **Game feel**: knockback nos inimigos, hit-stop 50ms, fagulhas de acerto.
- Componentes reusáveis: `components/drop_shadow.gd`, `height_sprite.gd`.

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
3. **Commit pendente**: repositório resetado limpo em `47040ac` (o índice
   do git corrompia via ambiente remoto). Commitar TUDO via TortoiseGit/git
   nativo do Windows (fechar o Godot antes se aparecer erro de index.lock),
   e fazer push pra um remoto.
4. Essência só tem 1 uso (Amuleto); Picareta II reservada pra gating futuro.
5. Bioma 2 desbloqueia mas ainda não existe (só flag + toast).

## Próximos passos (ordem recomendada)
1. **Commit + push** (item 3 acima) — urgente, antes de qualquer coisa.
2. **Baú de armazenamento** na base (estrutura + UI de transferência +
   persistência no save) — a hotbar de 10 enche em meia run.
3. **Inimigos com identidade**: SpriteFrames dos 4 inimigos do kit
   (`assets/craftpix_dungeon_kit/enemies/`), 1–2 comportamentos novos
   (ranged/explosivo), mix por viés de portal.
4. **NPC resgatável + diretor de encontros v1** (T3 do plano): sala de NPC
   injetada na run por flag de quest, resgate → NPC na base com 1 serviço.
5. Playtest externo de 30 min; depois seguir o `docs/plano-2-anos.md`.

## Convenções pra quem continuar
- Conteúdo novo = criar `.tres` (item/receita/estrutura/objetivo), nunca
  hardcodar. Cenas de entidade: origem nos pés, colisor na pegada, sombra.
- Graybox primeiro: código nunca espera arte; o visual é um nó trocável.
- Autoloads (ordem importa): ItemDB, GameState, PhantomCameraManager,
  LitManager, CursorManager, WorldLayers, RecipeDB, BuildMode,
  ObjectiveTracker, SaveManager.
- Conferir a integridade de arquivos após gravações grandes (item 2 acima).
