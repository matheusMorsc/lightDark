# Light in the Dark — Plano de Produção (24 meses até Early Access)

Base fixa e persistente na superfície (lado Stardew) + dungeons procedurais com risco crescente e loot (lado roguelite). Progressão: cumprir objetivos nas runs (matar boss N vezes, ajudar NPCs, coletar recursos) libera o próximo bioma, que libera novas dungeons — ~6 biomas na visão final, **EA lançado com 3**.

---

## 1. Premissas

| Item | Valor |
|---|---|
| Dedicação | 30h/semana ≈ 120h/mês ≈ **~2.880h suas em 24 meses** |
| Arte | **À mão (você + amigo)**, estilo Don't Starve/Hades; todo o pixel art atual vira placeholder até a arte final entrar |
| Orçamento | Moderado+ (detalhado na §8 — cai bastante com a arte in-house) |
| Engine | Godot 4.7, 2D puro, perspectiva Don't Starve-like (migração já feita) |
| Equipe | Dupla — você (código/design/áudio/integração) + amigo (arte) — com IA como copiloto |
| Idiomas no EA | PT-BR + EN |

**Distribuição das SUAS horas (guia, não camisa de força):** código 55% (~1.580h), design/conteúdo 20% (~580h), integração de arte 10% (~290h), áudio 5% (~140h), marketing/gestão/playtest 10% (~290h). A arte corre em **trilha paralela do seu amigo** — o cronograma da §4 assume ~10–15h/semana dele; alinhem esse número logo, porque é a variável que mais mexe nas datas.

**Regra graybox (vale o projeto inteiro):** nenhum sistema espera arte. Combate, bosses, salas e itens nascem com formas geométricas/placeholder pixel (cápsula colorida + triângulo de direção, mesmos nomes de animação `attack_down`, `walk_left`...), e a arte final substitui apenas o nó "Visual" — a âncora nos pés e a estrutura de nós estável garantem troca indolor. Reservar passe de game feel pós-arte (T7), pois frames de antecipação mudam o timing.

**O que já existe e é reaproveitado direto:** loop de sobrevivência (vida, fome, inventário, craft), combate básico, coleta, inimigos com IA de perseguição, iluminação Lit, Y-sort e perspectiva prontos, 18 props de dungeon, tileset de dungeon, `WorldLayers` desenhado (doc de migração §8), `HeightSprite`/`DropShadow`. Isso é ~3–4 meses de trabalho que você não vai repetir.

---

## 2. Pilares de design (imprimir e colar na parede)

1. **A base é o "porto seguro"** — persistente, customizável, onde todo progresso permanente mora.
2. **A run é descartável** — gerada por seed, tensa, com escolha risco×recompensa a cada andar.
3. **Morrer atrasa, nunca pune de verdade** — a dungeon é expedição de coleta, não teste de sobrevivência; morte custa no máximo parte do loot solto da run, jamais base ou progresso.
4. **Cada bioma é um contrato claro** — objetivos visíveis (boss ×N, NPCs, recursos) que destravam o próximo (mesmo mundo, nova região — ver decisão abaixo).
5. **Escopo é inimigo nº 1** — nada entra no jogo sem passar pela Definition of Done da §7.

**Loop macro:** preparar na base → descer (run) → arriscar descer mais fundo ou extrair → voltar com loot → melhorar base/equipamento/desbloquear → objetivo do bioma completo → novo bioma na superfície → novas dungeons → repete.

> **Decisão de arquitetura (registrada em jul/2026):** o mundo é ÚNICO e
> persistente — não existe "base do bioma 2" nem "base do bioma 3".
> Progredir (cumprindo os contratos do pilar 4) libera novas REGIÕES
> conectadas ao mesmo mapa — mais recursos, inimigos, NPCs, quests e novas
> dungeons — mas a base que o jogador constrói continua sendo sempre a
> mesma, num só lugar. "Novo bioma na superfície" no loop macro acima
> significa "nova região explorável", nunca "nova base pra recomeçar".
> Tecnicamente: `WorldLayers` gerencia N regiões de superfície (`RegionDef`
> .tres em `world/regions/`) + N mapas de run, todas coexistindo — **já
> implementado em jul/2026**. A região 1 é sempre a base de verdade
> (estruturas, save, ponto de morte/respawn); regiões 2+ nascem sob
> demanda ao cruzar uma borda (`entities/region_edge.gd`) e ficam vivas
> escondidas pelo resto da sessão. Limitação de v1: só a posição na base
> persiste entre sessões (detalhe em `docs/funcionalidades.md`). Região 2
> hoje é só um graybox de teste — falta desenhar o conteúdo real dela.
>
> **Raids na base (novo, ainda sem mecânica desenhada):** runs não servem
> só pra progredir — a base pode sofrer invasões ocasionais de inimigos, e
> o que se traz das runs (equipamento, estruturas defensivas) é o que
> prepara o jogador pra defendê-la. Gatilho, frequência e quem ataca ainda
> não foram definidos; entra no design quando o sistema for desenhado.
>
> **Árvore de progressão permanente (registrada jul/2026):** o "matar boss
> → ganhar essência" agora alimenta uma árvore de upgrades permanentes
> (Combate, Exploração, Construção, Magia), implementada em
> `UpgradeTracker`/`UpgradeDef` — ver `docs/funcionalidades.md` pro estado
> atual. A branch Construção é onde entra a cadeia de estações (Workbench
> → Forge → Alchemy Table → Research Table): cada estação é um upgrade que
> desbloqueia uma `StructureDef` nova, não um sistema paralelo de custo em
> madeira/pedra. Um **Portal** de atalho (fast-travel entre regiões
> distantes do mesmo mundo) é uma estação tardia dessa mesma cadeia — e é
> importante não confundir com o Talismã: o Talismã continua sendo a
> ÚNICA entrada pra uma run, o Portal é só conveniência de deslocamento
> pela superfície, e só faz sentido depois que existir mais de uma região.

---

## 3. Cronograma — 8 trimestres

> Regra de ouro: **todo mês fecha com uma build jogável.** Se um trimestre atrasar, corta-se conteúdo (inimigos, salas, side-quests), nunca o marco.

### T1 (meses 1–3) — Fundação técnica
O trimestre mais importante. Nada de conteúdo novo; só sistemas que tudo depois usa.

- `WorldLayers`: troca de camadas superfície↔dungeon com fade, spawn points, player/HUD persistentes.
- **Save system v1**: base persistente (estruturas colocadas, inventário, progresso de objetivos) em JSON/Resource. Runs não salvam (roguelite = permadeath da run, simplifica tudo).
- **Procgen v1**: gerador de andares por **salas prefab costuradas** (12–15 salas desenhadas à mão por bioma, conectadas por corredores em grafo; seed determinística). Mais controlável e barato que geração célula-a-célula, e o `dungeon_tileset.tres` + props já servem.
- **Run Manager**: estado da run (mapa atual, seed), morte leve (volta pra base com metade da vida, nada se perde). ~~Extração voluntária (escada/corda)~~ — descartada, ver §6: só se sai ganhando ou morrendo.
- Alçapão funcional na superfície usando o prop `trapdoor` (Area2D + prompt).
- **Marco T1:** descer da base, jogar 2 andares gerados, morrer ou extrair, voltar pra base com o estado correto. Feio, mas funcional.

### T2 (meses 4–6) — Vertical slice
Transformar o esqueleto em 20 minutos que representam o jogo final. É aqui que se decide a identidade visual.

- **Identidade de arte v1 (com seu amigo)**: style guide da arte à mão — paleta, peso de linha, resolução de trabalho (desenhar em 2–4× e reduzir), teste de coerência DENTRO do jogo: 1 personagem + 1 inimigo + 3 props + 1 trecho de chão pintado, sob a iluminação Lit. É o experimento que valida o visual do projeto inteiro; o resto continua placeholder.
- **Boss 1** em graybox primeiro (moveset, arena no andar 3, 2 fases, telegraphs claros); arte à mão entra quando o moveset travar.
- **Meta-progressão v1**: 2–3 estações na base (forja melhora arma, cozinha buffa comida, oficina desbloqueia gadgets) alimentadas por loot da dungeon.
- 4 inimigos do bioma 1 com variações reais (ranged, tanque, rápido, enxame) — evoluir o `enemy.gd` pra máquina de estados simples.
- Risco crescente: andares mais fundos = mais inimigos/elite + melhor loot (multiplicador simples por profundidade).
- **Áudio base**: pipeline de SFX (packs + Audacity/jsfxr), ~30 sons essenciais; 2 músicas licenciadas (tema da base, tema da dungeon 1).
- **Marco T2:** vertical slice — base → run → boss 1 → extração → upgrade visível na base. Mostrável a estranhos.

### T3 (meses 7–9) — Pipeline de conteúdo + NPCs
Antes de produzir os biomas 2 e 3, tornar a produção de conteúdo barata.

- **Data-driven tudo**: itens, receitas, inimigos, loot tables e objetivos de bioma viram `Resource`s (.tres) editáveis — adicionar um item novo deve custar minutos, não horas.
- **Sistema de NPCs v1**: NPCs resgatáveis na dungeon que passam a morar na base (o gancho "ajudando NPCs" da sua ideia). Cada NPC = 1 serviço (loja, missões, dicas de seed) + 3–4 falas. Sem romance/agenda estilo Stardew — corte consciente.
- **Diretor de encontros (modelo Hades)**: na montagem do grafo de salas, injeta salas roteirizadas de NPC conforme flags de quest, prioridade e pesos — os mesmos NPCs reaparecem em pontos reconhecíveis pra progredir quests. É um sistema pequeno em cima das salas prefab: sala marcada como "de NPC" + tabela de condições.
- **Diálogo estilo visual novel**: caixa de texto + retratos desenhados à mão (a primeira vitrine pública da arte final), fila de falas, escolhas simples, condições por flag. Retratos em alta resolução convivem com o mundo em placeholder sem conflito — UI é outro registro visual.
- **Objetivos de bioma** como sistema: tela de progresso (boss 2/3, NPCs 1/2, recurso 40/100), evento de desbloqueio do bioma seguinte.
- Construção de base expandida: paredes/piso/decoração colocáveis (grid + ghost preview), usando o sistema WallPiece do doc de migração.
- **Marco T3:** bioma 1 100% "contratável" — dá pra cumprir todos os objetivos e ver o portal do bioma 2 abrir.

### T4 (meses 10–12) — Bioma 2 + validação externa
Primeiro teste real do pipeline: quanto custa um bioma?

- **Bioma 2 completo** (superfície + dungeon): 12–15 salas prefab, 5 inimigos, boss 2, ~20 itens/receitas, 15 props, 1 NPC, 2 músicas. Meta: **≤ 250h suas** + ~175h de arte do amigo em trilha paralela (§4) — o pipeline do T3 existe pra isso.
- Mecânica-assinatura do bioma 2 (ex.: escuridão total + gestão de luz — casa com o Lit e com o nome do jogo).
- **Playtest fechado** (10–15 pessoas, itch.io com senha): observar, não defender. 2 rodadas.
- **Steam page no ar** no mês 12 (capsule art do seu amigo — é a peça de arte mais importante do marketing) — wishlists começam a contar cedo.
- **Marco T4:** 2 biomas jogáveis de ponta a ponta + página Steam pública.

### T5 (meses 13–15) — Bioma 3 + demo pública
- **Bioma 3 completo** (mesmo pacote do bioma 2; meta ≤ 220h suas com pipeline maduro; arte do bioma 3 já em produção desde o T4 pela trilha paralela).
- **Demo pública** (bioma 1 completo, ~45 min) preparada para **Steam Next Fest** — o maior gerador de wishlists disponível a custo zero.
- Trilha: +3 faixas (bioma 3, boss theme genérico, tema de morte/retorno).
- **Marco T5:** demo estável na Steam + inscrição no Next Fest mais próximo.

### T6 (meses 16–18) — Sistemas de lançamento
O trimestre "chato" que separa protótipo de produto.

- Menus completos, settings (vídeo/áudio/rebind de teclas), suporte a controle, save slots, pause.
- **Localização EN** (encomendada — 3ª encomenda) + sistema de tradução (CSV/gettext do Godot).
- Balanceamento sério: curvas de dano/vida/custo em planilha, economia de loot (quanto tempo até cada upgrade).
- Performance: pooling de VFX, `VisibleOnScreenEnabler2D` em tudo, teste em notebook fraco.
- Onboarding: primeiros 15 minutos guiados (tutorial diegético na base).
- **Marco T6:** "EA-ready" — um estranho instala, entende e joga 2h sem travar nem se perder.

### T7 (meses 19–21) — Polish + marketing
- **Game feel pass**: screenshake, hit-stop, partículas, knockback com `HeightSprite.hop()`, sons de UI — 1 mês inteiro só disso; é o que faz reviews dizerem "gostoso de jogar".
- **Trailer** (encomendado ou feito com capturas + editor — 4ª encomenda opcional).
- Beta fechado maior (30–50 pessoas), telemetria simples (onde morrem, onde desistem).
- Conteúdo de lançamento: eventos raros nas runs, 1 NPC extra, achievements Steam.
- **Marco T7:** release candidate + trailer no ar + meta de wishlists (referência da indústria: 7–10 mil wishlists = lançamento EA saudável; abaixo de 3 mil, considerar adiar 1 trimestre e fazer mais Next Fest/festivais).

### T8 (meses 22–24) — Lançamento Early Access
- Mês 22: correções do beta, passe final de balanceamento e localização.
- Mês 23: build de lançamento congelada, press kit, contato com curadores/creators BR e gringos, roadmap público pós-EA (biomas 4–6).
- Mês 24: **lançamento EA com 3 biomas**, patch de emergência na primeira semana, ciclo de updates mensais.

### Pós-EA (anos 3+) — sem pressa, com receita
Bioma 4 (~4 meses cada, com pipeline maduro), bioma 5, bioma 6 + endgame (dungeon infinita pós-boss final, NG+), 1.0. Cada bioma novo é um beat de marketing e um pico de vendas.

---

## 4. Plano de arte (à mão, em dupla — pixel como placeholder)

**Por que funciona com o que já temos:** Don't Starve e Hades são jogos de arte à mão, e a perspectiva implementada (billboards ancorados nos pés, Y-sort, chão plano) funciona identicamente com sprites desenhados. Nada do código muda; mudam os imports (filtro *linear* em vez de *nearest* para a arte final; nearest continua nos placeholders pixel).

**Regra de registro visual (a decisão estética central):** um registro por camada de significado. O *playfield* (ambiente, inimigos, itens no chão) será 100% arte à mão — misturar pixel e traço no mesmo plano não funciona. UI, retratos de diálogo, ícones de inventário, menus e mapa podem (e vão) usar o traço à mão desde cedo, convivendo com o mundo em placeholder sem conflito — CrossCode e o próprio Hades provam o padrão.

**Pipeline da dupla:**

1. Style guide primeiro (T2): paleta, peso de linha, proporções, resolução de trabalho (desenhar 2–4× e reduzir), luz neutra pra funcionar sob o Lit.
2. **Animação por rig/cutout (Skeleton2D do Godot), não frame a frame** — personagens e bosses desenhados em peças (tronco, braços, cabeça) e animados na engine, exatamente como Don't Starve/Hades. Corta o custo de animação em 3–5× e permite reusar animações entre criaturas de esqueleto parecido. Frame a frame só para VFX e detalhes.
3. Toda arte entra pelo padrão já estabelecido: origem nos pés, sombra de contato, occluder na base.
4. Você faz a integração (import, rig, materiais Lit); seu amigo desenha.

**Custo por bioma** (horas do seu amigo, assumindo rig/cutout):

| Asset | Qtd | Horas |
|---|---|---|
| Chão pintado + paredes (superfície + dungeon) | 2 conjuntos | 35h |
| Props/decoração | ~15 | 30h |
| Inimigos (peças + rig; anims reusadas) | 5 | 50h |
| Boss (peças, rig, telegraphs) | 1 | 25h |
| NPC + retrato VN (2–3 expressões) | 1 | 15h |
| Itens/ícones | ~20 | 12h |
| VFX desenhados | ~8 | 10h |
| **Total por bioma** | | **~175h** |

Custos únicos fora dos biomas: style guide + testes (~25h), rig do player com todas as anims (~40h), UI completa (~30h), capsule art Steam (~15h). A 10–15h/semana do seu amigo, um bioma leva ~3–4 meses de arte — compatível com o cronograma se a arte do bioma N+1 começar enquanto você programa o bioma N (por isso a regra graybox existe).

**Plano B honesto:** se a trilha de arte atrasar 2+ meses, as opções em ordem são: reduzir inimigos por bioma (5→4), reusar rigs com re-skin, e só em último caso encomendar peças pontuais no estilo do style guide.

---

## 5. Plano de áudio

**SFX (~140h total):** base de packs (Kenney, Sonniss GDC bundles gratuitos, itch) + edição no Audacity; jsfxr/ChipTone para UI e feedbacks; alvo de ~30 sons no T2, ~120 no lançamento. Regra: nenhuma ação do player sem som a partir do T7.

**Música (licenciada/encomendada, não composta por você):**

| Faixa | Quando | Fonte |
|---|---|---|
| Tema da base (calmo, loop 2–3min) | T2 | Licença ou encomenda |
| Dungeon bioma 1 | T2 | idem |
| Dungeon biomas 2 e 3 + superfícies | T4–T5 | idem |
| Boss theme (1 genérico + variações) | T5 | encomenda |
| Título/morte/vitória (stingers) | T6 | idem |

~9–10 faixas no EA. Encomenda típica: US$ 150–400/faixa com compositor indie; licenças (ex.: catálogos como Ovani, bundles do Humble) saem por fração disso com identidade menor. Sugestão: licenciar a maioria, **encomendar só tema principal + boss theme**.

---

## 6. Design da run (referência rápida)

- **Propósito da run:** expedição de coleta — materiais específicos viram ferramentas que destravam a exploração do bioma atual; materiais raros de boss movem a progressão geral. A run serve à base, não o contrário. Também prepara o jogador pra defender a base das raids ocasionais de inimigos (ver decisão na §2).
- **Estrutura:** cada mapa termina em 2–3 portais de escolha (estilo Hades) que decidem o viés do próximo mapa, ou — a cada `BOSS_EVERY` mapas — numa arena de boss. Elite rooms e salas de tesouro opcionais = escolha risco×recompensa.
- **Semi-roteirizada (modelo Hades):** o diretor de encontros injeta salas de NPC/evento conforme flags de quest e pesos — familiaridade dentro da variação. Aleatoriedade pura só no layout e nos encontros comuns.
- **Risco crescente:** por mapa, +HP/dano de inimigos, +chance de elite, melhor tabela de loot. Modificadores de seed visíveis antes de entrar ("mapas inundados", "escuridão densa") a partir do T5.
- **Morte (leve):** morrer na run acorda o jogador em casa com metade da vida, fome reposta a 50% no mínimo. A base nunca é afetada — nada de bolsa/loot solto a perder, o "custo" é só o tempo da run.
- **Sem extração voluntária (registrado jul/2026):** dentro da run só se sai ganhando (derrotar o boss abre um portal de saída) ou morrendo. Não existe escada/corda de volta a qualquer momento — plano anterior descartado.
- **Objetivos de bioma (o "contrato"):** matar boss ×N (N=2–3), resgatar X NPCs, entregar Y recursos ao NPC construtor → abre a passagem para a nova região do próximo bioma (mesmo mundo — ver decisão na §2).

---

## 7. Definition of Done — bioma

Um bioma só está "pronto" quando: superfície explorável com 3+ pontos de interesse; dungeon com 12+ salas prefab e mecânica-assinatura; 4–5 inimigos + 1 boss com 2 fases (arte final, não graybox); 15+ itens/receitas novos, incluindo a cadeia material→ferramenta→área nova do bioma; 1 NPC resgatável com retrato VN e sala roteirizada no diretor de encontros; 2 músicas + SFX completos; objetivos de desbloqueio configurados; 2 sessões de playtest sem bug bloqueante; performance ok no hardware de referência.

---

## 8. Orçamento estimado (R$)

Com a arte in-house, o orçamento encolhe e muda de destino:

| Item | Faixa |
|---|---|
| Ferramentas de arte (Clip Studio/Krita, mesa digitalizadora se precisar) | 500–2.500 |
| Música (2 encomendas: tema principal + boss theme; ~7 licenças) | 2.500–5.000 |
| Localização EN (~15–20k palavras — diálogos VN pesam aqui) | 2.000–4.500 |
| Steam Direct | ~600 |
| Trailer (se encomendado; dá pra fazer em casa) | 0–4.000 |
| Playtests/festivais/imprevistos (~20%) | 1.500–3.500 |
| **Total** | **~R$ 7–20 mil** |

A sobra em relação ao teto "moderado+" vira colchão — ou remuneração simbólica da dupla. Formalizem cedo, por escrito, a divisão de propriedade/receita entre você e seu amigo; é a causa nº 1 de morte de projetos em dupla.

---

## 9. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Procgen virar buraco sem fundo | Salas prefab + grafo simples; proibido "gerador orgânico perfeito" no ano 1 |
| Scope creep (farming, pesca, romance...) | Tudo que não está nos pilares vai pra lista "pós-1.0"; revisão trimestral |
| Trilha de arte do amigo atrasar/parar | Regra graybox (código nunca espera arte); style guide cedo; ritmo combinado em horas/semana; Plano B da §4 |
| Registro visual incoerente (pixel × traço) | Um registro por camada (§4): playfield 100% à mão, UI/retratos à mão desde o T3, pixel só como placeholder |
| Sociedade em dupla sem acordo | Divisão de propriedade/receita por escrito antes do T3 |
| Burnout | 30h é teto, não meta; 1 semana de folga por trimestre; build jogável mensal dá senso de progresso |
| Wishlists baixas no T7 | Critério objetivo (§T7): <3 mil = adia EA 1 trimestre, +1 Next Fest |
| Save corrompido em EA | Save versionado + backup automático dos 3 últimos; testar migração entre versões desde T6 |

---

## 10. Resumo executivo

| Trimestre | Entrega |
|---|---|
| T1 | Loop base↔dungeon procedural funcional |
| T2 | Vertical slice com boss 1 e identidade de arte |
| T3 | Pipeline de conteúdo + NPCs + objetivos de bioma |
| T4 | Bioma 2 + playtest + Steam page |
| T5 | Bioma 3 + demo + Next Fest |
| T6 | Sistemas de lançamento (menus, EN, controle, balance) |
| T7 | Polish, trailer, beta, wishlists |
| T8 | **Lançamento Early Access (3 biomas)** |
| Pós-EA | Biomas 4–6, endgame, 1.0 |
