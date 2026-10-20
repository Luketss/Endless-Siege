# Créditos de arte e áudio

Todos os modelos 3D e sons importados são **CC0 1.0 (domínio público)**: uso comercial livre, sem exigência de atribuição. Mesmo assim, o jogo credita os autores. Cada pasta mantém o arquivo de licença original do pacote.

| Pasta | Pacote | Autor | Origem | Licença |
|---|---|---|---|---|
| `models/kenney_td/` | Tower Defense Kit 2.1 | Kenney | https://kenney.nl/assets/tower-defense-kit | CC0 |
| `models/kenney_nature/` | Nature Kit | Kenney | https://kenney.nl/assets/nature-kit | CC0 |
| `models/kenney_castle/` | Castle Kit | Kenney | https://kenney.nl/assets/castle-kit | CC0 |
| `models/quaternius/monsters/` | Animated Monster Pack | Quaternius | https://opengameart.org/content/lowpoly-animated-monsters | CC0 |
| `models/quaternius/rpg/` | RPG Characters (Nov 2020) | Quaternius | https://opengameart.org/content/lowpoly-rpg-characters | CC0 |
| `models/quaternius/knight/` | Animated Knight | Quaternius | https://opengameart.org/content/lowpoly-animated-knight | CC0 (declarada na página; o zip não traz arquivo de licença) |
| `models/quaternius/cute/` | Cute Animated Monsters (Aug 2020) | Quaternius | https://opengameart.org/content/textured-cute-monster-pack | CC0 (declarada na página; o zip não traz arquivo de licença) |

## Onde cada modelo é usado

| Elemento do jogo | Modelo |
|---|---|
| Patrulheira (heroína) | RPG Characters · Ranger |
| Guerreiro | RPG Characters · Warrior |
| Brutamonte | Animated Monster Pack · Skeleton |
| Corredor | Cute Monsters · GreenDemon |
| Bruto Blindado | Animated Knight · KnightCharacter |
| Fogo-fátuo (voador) | Animated Monster Pack · Bat |
| Divisor / Fragmento | Animated Monster Pack · Slime |
| Feiticeiro | RPG Characters · Cleric |
| Guardião | Cute Monsters · Tree |
| Dragão Ancestral (chefe) | Animated Monster Pack · Dragon |
| Torre de Flechas / Canhão / Pináculo Gélido | Tower Defense Kit (peças de torre, balista, canhão, cristais) |
| Estandarte de Guerra | Castle Kit (base hexagonal + bandeira) |
| Projéteis de flecha e canhão | Tower Defense Kit (munições) |
| Árvores, rochas e detalhes do cenário | Nature Kit, Tower Defense Kit |
| Muralhas | Castle Kit |

Continuam procedurais (feitos por código): armadilhas, núcleo de cristal, portal, efeitos visuais, sons e música.

## Como trocar ou adicionar arte

As referências ficam em `data/visuals.json` (caminho, escala, rotação, altura da barra de vida e nomes das animações). Se um arquivo faltar, o jogo usa o modelo procedural correspondente. `tools/inspect_models.gd` lista tamanhos e animações dos modelos importados, e `tools/model_lineup.gd` renderiza todos lado a lado com uma régua de 1,8 m para calibrar as escalas.

## Áudio

Pasta `audio/kenney/`, com os arquivos `License_*.txt` originais. Todos são CC0, da Kenney (https://kenney.nl).

| Pacote | Usado em |
|---|---|
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | cliques, voltar, erro, melhoria, sinergia, gelo |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | construção, golpes, críticos, dano na heroína, mortes, sino do núcleo |
| [RPG Audio](https://kenney.nl/assets/rpg-audio) | moedas, espinhos, mola, esquiva |
| [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | disparo do canhão, explosões, pisão do chefe |
| [Digital Audio](https://kenney.nl/assets/digital-audio) | maldição do feiticeiro, subida de nível |

O arco, as torres de flecha e as vinhetas musicais (início e fim de onda, vitória, derrota) continuam sintetizados em `scripts/autoload/sfx.gd`, assim como a música.
