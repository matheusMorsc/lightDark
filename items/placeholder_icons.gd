class_name PlaceholderIcons
extends RefCounted
## Ícones geométricos gerados em RUNTIME (32×32, retângulos coloridos) pra
## dar identidade visual própria a itens sem sprite ainda — registrado
## jul/2026 depois de perceber que Espada/Lança/Martelo reaproveitavam o
## MESMO `recipe_tool.png` genérico e ficavam indistinguíveis no
## inventário, justo quando cada uma ganhou um moveset diferente.
##
## Por que gerar em código em vez de desenhar um .png: escrever arquivo
## binário novo dentro do projeto não é confiável neste ambiente (já deu
## problema numa sessão anterior); um `Image` construído na hora com
## `fill_rect` não depende disso e ainda fica fácil de ajustar aqui mesmo.
## Só entra em uso se o `.tres` do item deixar `icon` vazio (null) — ver
## `ItemDB._ready()`; assim que a arte de verdade existir, basta setar
## `icon` no `.tres` que o placeholder para de ser usado sozinho.

const SIZE := 32

static func weapon_icon(kind: String) -> ImageTexture:
	match kind:
		"lanca":
			return _lance_icon()
		"martelo":
			return _hammer_icon()
		_:
			return _sword_icon()

## Mesma ideia do weapon_icon, mas pra poções da Mesa de Alquimia (jul/2026):
## nenhum ícone de frasco existe em assets/ui/icons ainda, e as 3 poções
## precisam ser distinguíveis entre si (diferente do Amuleto Vital, item
## único que pôde reaproveitar essencia_icon sem ambiguidade). Mesmo
## frasco/silhueta pras 3, só muda a cor do líquido por canal — vermelho
## (ataque), azul (defesa), amarelo (velocidade), convenção comum de RPG.
## Usado só se `RecipeDef.icon` estiver vazio, ver hud.gd::_build_recipe_row.
static func potion_icon(channel: String) -> ImageTexture:
	match channel:
		"attack":
			return _potion_icon(Color(0.85, 0.2, 0.2))
		"defense":
			return _potion_icon(Color(0.25, 0.45, 0.9))
		_:
			return _potion_icon(Color(0.85, 0.75, 0.15))

## Frasco: gargalo curto + rolha + corpo arredondado (aproximado por faixas
## que alargam) cheio da cor do líquido, com um brilho de vidro fixo.
static func _potion_icon(liquid: Color) -> ImageTexture:
	var img := _blank_image()
	img.fill_rect(Rect2i(13, 2, 6, 4), Color(0.45, 0.3, 0.18))
	img.fill_rect(Rect2i(12, 6, 8, 4), Color(0.75, 0.8, 0.85, 0.6))
	img.fill_rect(Rect2i(9, 10, 14, 6), liquid)
	img.fill_rect(Rect2i(7, 16, 18, 10), liquid)
	img.fill_rect(Rect2i(10, 12, 3, 3), Color(1, 1, 1, 0.35))
	return ImageTexture.create_from_image(img)

static func _blank_image() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)

## Lâmina fina e comprida + guarda larga + cabo curto — silhueta
## "cruz estreita", pra não se confundir com o bloco largo do martelo.
static func _sword_icon() -> ImageTexture:
	var img := _blank_image()
	img.fill_rect(Rect2i(14, 2, 4, 20), Color(0.82, 0.85, 0.92))
	img.fill_rect(Rect2i(8, 21, 16, 3), Color(0.85, 0.7, 0.25))
	img.fill_rect(Rect2i(13, 24, 6, 7), Color(0.45, 0.3, 0.18))
	return ImageTexture.create_from_image(img)

## Cabo comprido (ocupa quase o ícone inteiro) + ponta triangular fina no
## topo (aproximada por 3 retângulos que estreitam) — silhueta "longa e
## pontuda", oposta ao martelo (curto e largo no topo).
static func _lance_icon() -> ImageTexture:
	var img := _blank_image()
	img.fill_rect(Rect2i(14, 8, 4, 22), Color(0.5, 0.35, 0.2))
	img.fill_rect(Rect2i(10, 6, 12, 3), Color(0.8, 0.83, 0.9))
	img.fill_rect(Rect2i(12, 3, 8, 3), Color(0.8, 0.83, 0.9))
	img.fill_rect(Rect2i(14, 0, 4, 3), Color(0.8, 0.83, 0.9))
	return ImageTexture.create_from_image(img)

## Cabeça grande e pesada no topo (mais larga que a lâmina/ponta das
## outras duas) + cabo curto — silhueta "top-heavy", lê como "pesado" de
## longe mesmo em 24×24 na hotbar.
static func _hammer_icon() -> ImageTexture:
	var img := _blank_image()
	img.fill_rect(Rect2i(6, 3, 20, 11), Color(0.38, 0.38, 0.42))
	img.fill_rect(Rect2i(13, 14, 6, 16), Color(0.45, 0.3, 0.18))
	return ImageTexture.create_from_image(img)
