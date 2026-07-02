# Light in the Dark — status do projeto

Resumo pra continuar o desenvolvimento em outra conversa. Cole este arquivo (ou peça pro Claude ler `PROJECT_STATUS.md` na raiz do projeto) no início do novo chat.

## O jogo

Sobrevivência/mineração/combate top-down 2.5D, estilo Core Keeper, em **Godot 4.7 + GDScript**. Visual: sprites 2D pixel art + iluminação/sombra dinâmica de verdade (addon **Lit**), dando profundidade sem ser 3D. Filosofia de combate: "bate e volta" — sem defesa, sem itens equipáveis, sem magia. Upgrades de crafting são permanentes (bônus de status), não itens.

Cena principal: `world/test_biome.tscn` (`run/main_scene` no `project.godot`).

## Sistemas já implementados

- **Movimento**: WASD/setas lidos direto via `Input.is_key_pressed` (não depende do Input Map do projeto).
- **Personagem**: jogador é o **Swordsman** (craftpix, nível 1), com animação direcional de verdade — `idle`/`walk`/`attack`/`death` cada um com 4 direções (`down`/`up`/`left`/`right`), extraídas do spritesheet original em `player/player.gd` (`_facing`, `_update_facing`, `_update_animation`) e tocadas via `AnimatedSprite2D` + `SpriteFrames` (`assets/craftpix_swordsman/lvl1/swordsman_lvl1.tres`). O personagem vira sozinho conforme o eixo dominante do movimento; ataque toca a animação de swing na direção atual antes de voltar pra idle/walk.
- **Combate**: botão de ataque (Espaço **ou clique esquerdo do mouse**) acerta tudo dentro de uma `Area2D` circular ao redor do jogador — sem mira, área fixa.
- **Vida/fome/inventário**: autoload `GameState` (`autoload/game_state.gd`) controla `health`, `hunger` e um **inventário em grade real** (`inventory`: Array de 20 slots, cada um `{item_id, count}` ou `null`, empilhando até o máximo de cada item). Sinais: `health_changed`, `hunger_changed`, `resource_changed`, `inventory_changed`, `player_damaged`, `player_died`, `recipe_crafted`. `add_resource`/`remove_resource`/`can_afford`/`craft` continuam com a mesma assinatura de antes (compatibilidade), só que agora manipulam a grade; `swap_slots(a, b)` faz drag-and-drop (empilha se for o mesmo item, senão troca). Metadados de item (nome, ícone, pilha máxima) ficam no autoload `ItemDB` (`autoload/item_db.gd`).
- **Recursos**: "comida" (cogumelo), "minério" (gema) e agora **"pedra"** (novo, do pack Rocks-and-Stones), colhidos de `ResourceNode`/`OreNode`/`StoneNode` (alguns golpes até esgotar, depois `queue_free()`). `entities/resource_node.gd` é genérico (usado pelos três).
- **Comer**: tecla E consome 1 "comida" e recupera fome (`player.gd::_eat()`).
- **Crafting**: tecla C abre painel; receitas em `ui/hud.gd::RECIPES` — "Ferramenta Reforçada" (3 minério + 2 comida, +5 dano), "Refeição Reforçada" (5 comida, +20 vida máxima e cura) e **"Fortificação"** (4 pedra, +15 vida máxima, nova). Cada receita mostra o ícone do item no painel.
- **Inventário UI**: grade de 20 slots (`ui/inventory_slot.tscn`/`.gd`) com ícone + contador, **drag-and-drop nativo do Godot** (`_get_drag_data`/`_can_drop_data`/`_drop_data`) pra reorganizar/empilhar. Substitui os contadores fixos de comida/minério de antes.
- **Inimigos**: 2 tipos, ambos usando `entities/enemy.gd` com exports diferentes — `enemy.tscn` (grunt roxo, mais forte/lento) e `enemy_fast.tscn` (vermelho/laranja, rápido e frágil). Perseguem, atacam por contato, têm flash de dano + som + morte com delay (áudio termina antes do `queue_free()`).
- **Morte/restart**: `GameState.player_died` → HUD mostra tela de game over, pausa (`get_tree().paused = true`), tecla R reinicia (`GameState.reset()` + `reload_current_scene()`); o jogador também toca a animação de morte na direção atual.
- **HUD**: barra de vida (vermelha) e fome (laranja) com cor própria, painel de inventário em grade (ver acima), tutorial que aparece e some sozinho, painel de crafting com ícones.
- **Áudio**: `AudioStreamPlayer` (jogador) / `AudioStreamPlayer2D` (inimigos/recursos) pra ataque, dano, comer, minerar, passos — sons aleatórios de um array por evento (Kenney `rpg-audio` + `impact-sounds`).
- **Cursor contextual**: autoload `CursorManager` troca o cursor (espada/picareta/seta) conforme o que está embaixo do mouse (raycast por ponto físico + grupos `enemies`/`resources`). Puramente visual.
- **Iluminação/sombra real**: addon **Lit** — `LitCanvasModulate` escurece a cena, tocha do jogador (`LitPointLight2D` anexado via script direto) emite luz com sombra (`shadow_enabled`), paredes (`CaveWall`, `OrganicWall`), fogueiras e tochas de chão emitem luz real com sombra.
- **Paredes orgânicas**: `world/organic_wall.gd` gera blobs de rocha em runtime via SmartShape2D (colisão + sombra automáticas).
- **Pós-processamento (clima estilo Don't Starve Together)**: `PostProcess` em `test_biome.tscn` usa `LitPostProcess` — dessaturação leve (`saturation=0.7`), contorno escuro sutil nos sprites, vinheta e grão de filme.
- **Profundidade visual**: sombra de contato (blob suave) embaixo de jogador/inimigos/recursos; feixes de luz sutis saindo da tocha do jogador.
- **Ambientação**: poças d'água, árvores, arbustos, flores, lápides, fogueiras e tochas de chão (`kenney_roguelike-rpg-pack`); **ruínas** (blocos de pedra quebrados, canto sudoeste do mapa), **ossos de dragão** (centerpiece), **entrada de caverna** decorativa, samambaias e cogumelos escuros (`rocky-area-objects`), e um "canto amaldiçoado" com **planta-olho** e ossadas (`cursed-land`) no canto nordeste. Tudo puramente visual (`Node2D` + `Sprite2D` com o shader do Lit, sem colisão) — ver `entities/decor/`.

## Assets (packs usados/disponíveis)

Kenney:
- `kenney_roguelike-characters`: só usado agora pelo hue-shift dos 2 inimigos (o jogador não usa mais esse pack).
- `kenney_roguelike-caves-dungeons`: chão de caverna, paredes, minério (`gem_ore.png`), também tem ladrilhos de água/gelo ainda não usados.
- `kenney_roguelike-rpg-pack`: água, árvores, arbustos, flores, lápides, fogueiras, tochas de chão. Ainda tem muito não usado: móveis, portas, mais terrenos (grama/deserto/neve), baús, tapetes.
- `kenney_rpg-audio` / `kenney_impact-sounds`: efeitos sonoros.
- `kenney_cursor-pixel-pack`: cursores.
- `kenney_fantasy-ui-borders` / `kenney_isometric-miniature-dungeon`: moldura do painel de inventário/slots.

Craftpix (adicionados nesta sessão, fonte em `raw_assets/` — **fora do git**, `.gitignore`d e com `.gdignore` pro editor não tentar importar; só o que foi extraído pra `assets/` entra no jogo):
- `swordsman-1-3-level` (180537): usado o **lvl1**. Sprites organizados por linha = direção (4 direções: down/up/left/right), com contagem de frames variável por animação — script de extração fatiou em `assets/craftpix_swordsman/lvl1/`. Níveis 2 e 3 (mais forte/detalhado) **não usados ainda** — dá pra plugar como upgrade visual de "level up" no futuro.
- `rocks-and-stones-top-down` (974061): usado pro novo recurso "pedra" (`assets/craftpix_rocks`). Tem Rock1–Rock6, cada um com 5 variações — só 3 usadas (`rock_a/b/c`), sobra bastante variedade pra mais nós ou pra decoração pura.
- `rocky-area-objects` (639143): usado ossos de dragão, entrada de caverna, samambaia, cogumelos escuros (`assets/craftpix_rocky_area`). Pack tem MUITO mais não usado: pérolas, pontes de liana, mais variações de cogumelo/entrada.
- `top-down-ruins` (934618): usado 3 peças de ruína (`assets/craftpix_ruins`). Tem 5 paletas de cor (azul-cinza/marrom-cinza/marrom/areia/neve/branco/água) com 5 peças cada — só a ponta do iceberg foi usada, dá pra montar uma ruína bem maior.
- `cursed-land-top-down-tileset` (958568): usado planta-olho e uma pilha de ossos como decoração pontual (`assets/craftpix_cursed_land`). **O tileset de chão (`Ground.png`, `bridges.png`) não foi integrado** — exigiria mexer no sistema de chão existente (`cave_floor.tscn`), que não foi investigado a fundo; ficou de fora por risco/tempo. Também tem props "Fetus" que foram deliberadamente evitados (potencialmente perturbadores).
- `basic-pixel-art-fantasy-icons-16x16` (994534): usado pros ícones do inventário/crafting (`assets/ui/icons`) — só 3 dos 120 ícones disponíveis (pedra, ferramenta, refeição); o resto do pack está livre pra outros itens/receitas futuras.
- `pixel-art-fantasy-2d-battlegrounds` (776320): **não integrado**. É uma cena parallax em camadas (céu, colinas, ruínas, chão) pensada como plano de fundo lateral/ilustrativo, não um tileset top-down — não combina com a perspectiva do jogo. Ficou só organizado em `raw_assets/` pra uso futuro (ex.: tela de menu).

## Convenções e armadilhas importantes do ambiente

1. **Bug de dessincronia do filesystem (bash/FUSE)**: a visão do projeto pelo terminal (bash) pode ficar desatualizada/truncada em relação ao que as ferramentas de arquivo realmente gravaram. Isso já corrompeu o índice do git uma vez. **Ritual obrigatório antes de todo `git add`/commit**: rodar `mv arquivo arquivo.bak && mv arquivo.bak arquivo` (round-trip) em cada arquivo alterado, depois conferir `cat`/`git diff` antes de commitar. Nunca confiar cegamente no `git status`/`diff` sem esse passo.
2. **Arquivos de lock do git presos (`.git/index.lock`, `.git/HEAD.lock`)**: depois de um `git commit`, os arquivos de lock às vezes ficam presos e nem `rm`/`mv` conseguem apagá-los (`Operation not permitted` — a pasta conectada bloqueia delete/rename por padrão). Solução: chamar a tool `allow_cowork_file_delete` pedindo permissão pra apagar o arquivo específico; depois disso `rm` funciona normalmente. Sem isso, todo `git add`/`commit` seguinte falha com "Unable to create '.git/index.lock': File exists".
3. **Anexar scripts de addons direto**: para nós de addons (Lit, SmartShape2D, Phantom Camera), sempre instanciar o tipo base genérico (`Node2D`, `CanvasLayer`, etc.) no `.tscn` e anexar o script via `script = ExtResource(...)`, em vez de usar `type="NomeDaClasse"`. O `class_name` desses addons não resolve de forma confiável nesse projeto.
4. Cores/atlas: para achar coordenadas exatas de tiles/frames em spritesheets, gerar um crop com grid + labels (col,row / índice) via PIL antes de cortar — economiza tentativa e erro. Também dá pra detectar frames vazios automaticamente via `Image.getbbox()` pra saber quantos frames cada animação/direção realmente tem num spritesheet com padding.
5. **Sem Godot instalado no sandbox**: não dá pra rodar `--headless` pra checar erros de verdade. A validação nesta sessão foi manual (revisão de sintaxe .tscn/.gd) + um script Python que confere se todo `ExtResource`/`SubResource` referenciado tem uma declaração correspondente no mesmo arquivo (pega erros de referência, não de lógica). Vale abrir o projeto no editor local e checar o console de erros antes de continuar.
6. **`git add` pode corromper o índice NO MEIO da operação** (`error: bad signature 0x00000000` / `fatal: index file corrupt`), e um `git commit` rodado logo depois **completa mesmo assim, só que gera um commit com a tree quebrada** (perde quase todos os arquivos rastreados — já aconteceu de um commit "sumir" com 828 arquivos e sobrar só 2). Sinal de alerta: depois de um commit, `git ls-tree -r HEAD --name-only | wc -l` cai um valor muito menor que o commit anterior, ou `git status` de repente lista pastas inteiras como `??` que já eram rastreadas. **Nunca confie num commit feito logo após um erro de índice.** Recuperação: `git ls-tree -r <hash> --name-only | wc -l` em cada commit recente pra achar o último bom; `rm .git/index` (com `allow_cowork_file_delete` se der "Operation not permitted"); `git reset --mixed <ultimo-bom-hash>` (mantém os arquivos no disco, só rebobina o branch); reconferir com `git show HEAD:arquivo | diff - arquivo` antes de recommitar. Fazer commits pequenos (poucos arquivos por vez) reduz o dano quando isso acontece.

## Possíveis próximos passos (não pedidos ainda, só ideias)

- Levar o Swordsman pro lvl2/lvl3 como "level up" visual ao craftar upgrades.
- Integrar o tileset de chão do cursed-land (`Ground.png`) como uma zona/POI diferenciada — não foi feito por risco de mexer no sistema de chão existente sem conseguir testar.
- Mais receitas de crafting usando os ícones sobrando do pack de UI.
- Baú físico no mundo (o inventário hoje é só "estoque global", sem objeto físico — foi decisão consciente da sessão, mas dá pra adicionar depois).
- Novos tipos de inimigo (precisaria de outro pack, os atuais são recolors do mesmo pack Kenney).
- Usar mais do `roguelike-rpg-pack` (móveis, mais terrenos) e do `top-down-ruins`/`rocky-area-objects` (ainda tem bastante sobrando) se fizer sentido pro bioma.
- Água atualmente só bloqueia — não há mecânica de nadar/pesca.

## Estado do git

Branch `main`, HEAD em `27b9f7e`. Working tree deve estar limpo (todas as mudanças da sessão foram commitadas, uma feature por commit — inclui também ajustes pós-feedback: personagem maior, inventário movido pra baixo em fileira horizontal, chão trocado pra variante clara/creme). Rodar `git log --oneline` pra ver o histórico completo (46 commits desde o protótipo inicial). Cada commit dessa sessão foi verificado com `git ls-tree -r <hash> --name-only | wc -l` pra garantir que a tree não estava corrompida (ver armadilha #6 acima).
