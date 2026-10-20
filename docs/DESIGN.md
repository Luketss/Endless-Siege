# Design do jogo (MVP)

Todos os números vêm de `data/*.json`; esta página resume os valores atuais.

## Loop

1. **Nova jornada** (escolha de desafios, se desbloqueados) → mapa da jornada com 7 camadas.
2. Escolha de um nó ligado ao atual. O tipo e a recompensa provável aparecem antes da escolha.
3. **Batalha** (3 ondas): fase de construção livre → `G` inicia a onda → herói e defesas lutam → ouro por abate e por onda → suprimentos aparecem no campo depois de cada onda (o herói coleta com `F`).
4. Ao vencer, **escolha 1 de 3 melhorias** (ou pule e receba ouro). As defesas, o ouro, a vida do núcleo e o nível da heroína persistem até o fim da jornada.
5. Mercador (comprar melhorias e reparar), Evento (risco/recompensa), Acampamento (repara 40%), Elite (ondas com elites e melhoria rara ou melhor).
6. **Chefe** na última camada. Vitória ao derrotá-lo; derrota se o núcleo chegar a 0.
7. **Essência** é concedida proporcionalmente ao progresso e gasta no **Santuário**.

## Estruturas

| Estrutura | Custo | Função |
|---|---|---|
| Torre de Flechas | 60 | 9 de dano físico, 1,25/s, alcance 13; atinge voadores |
| Canhão | 100 | 24 de dano em área (2,6 m), 0,55/s; não atinge voadores |
| Pináculo Gélido | 90 | 5 de gelo + resfriar (−35% de velocidade por 2,2 s); atinge voadores |
| Estandarte de Guerra* | 85 | Aura de 6,5 m: +18% de dano e +12% de cadência às torres |
| Espinhos | 40 | Na estrada: 7 de dano a cada 0,8 s em todos os inimigos sobre ela |
| Placa de Mola | 70 | Lança até 6 inimigos 7 m para trás (recarga de 4 s) |
| Poço de Piche* | 50 | −50% de velocidade e óleo (fogo +50%) |

\* desbloqueável no Santuário. Torres sobem até o nível 3 (+45% de dano, +10% de alcance e +10% de cadência por nível). Vender devolve 70% do investido. Torres em platôs ganham +20% de alcance. Obstáculos altos e muralhas bloqueiam a linha de visão.

**Posicionamento livre** com grade de 0,5 m. Torres ficam fora da estrada, sem colidir com obstáculos ou outras estruturas, longe do núcleo e sem ficar na borda dos platôs. Armadilhas (2×2 m) ficam inteiras sobre a estrada. O fantasma fica verde ou vermelho, com o motivo da recusa.

## Inimigos

| Inimigo | Introdução | Comportamento |
|---|---|---|
| Brutamonte | camada 0 | básico, em grupos |
| Corredor | camada 0 | rápido (6,2 m/s), atravessa defesas |
| Fogo-fátuo | camada 1 | **voador**: voa direto ao núcleo, ignora a estrada e as armadilhas |
| Bruto Blindado | camada 2 | armadura 5 (reduz dano físico; elementos ignoram) |
| Divisor | camada 2 | divide-se em 2 fragmentos ao morrer |
| Feiticeiro | camada 3 | **desativa estruturas** num raio de 5,5 m por 3 s a cada 7 s |
| Guardião | camada 3 | **aura**: aliados próximos recebem 35% menos dano |
| Elite (qualquer) | elites / camada 3+ | ×2,6 de vida, maior, +2 de armadura, mais ouro |

A vida cresce 60% por camada e o orçamento das ondas 70% por camada e 40% por onda. Feiticeiros e guardiões chegam com escolta, formando combinações em vez de apenas números maiores.

**Dragão Ancestral (chefe):** 2600 de vida base, armadura 4.
- Fase 1: pisão a cada 8 s (desativa estruturas num raio de 7 m e fere o herói).
- Fase 2, a 66%: +4 de armadura, invoca 6 brutamontes a cada 9 s.
- Fase 3, a 33%: fúria (+60% de velocidade), pisão a cada 4 s, invoca corredores.
- Se chegar ao núcleo, causa 45 de dano.

## Herói: Patrulheira

110 de vida, regeneração após 4 s sem dano. Morte não é derrota: renasce em 7 s.

| Ação | Efeito |
|---|---|
| LMB | Flecha 13 de dano, 0,42 s, 10% de crítico, mira assistida no inimigo mais próximo da mira |
| Q — Chuva de Flechas | 8 golpes de 9 numa área de 4,2 m no ponto mirado; recarga de 11 s |
| E — Rajada Concussiva | Cone de 6,5 m / 70°: 16 de dano e empurra 5 m pela estrada (sinergia com espinhos); recarga de 8 s |
| Espaço — Esquiva | Rolamento de 6 m, invulnerável; recarga de 1,4 s |
| F | Coleta suprimentos |

Ganha XP com abates e sobe de nível (+10% de dano e +12 de vida por nível), mantendo o nível durante a jornada.

Inimigos que encostam nela atacam com uma preparação de 0,4 s (animação de golpe e anel vermelho no chão). O dano só sai se ela continuar ao alcance no fim da preparação, então se afastar ou esquivar evita o golpe; depois o inimigo espera 1,2 s para atacar de novo.

## Herói: Guerreiro (desbloqueio no Santuário, 30 de essência)

170 de vida, 6,6 m/s, regeneração de 3/s. Segura a estrada no corpo a corpo enquanto as torres fazem o resto.

| Ação | Efeito |
|---|---|
| LMB | Golpe de espada de 24 de dano em arco de 140° e 3,2 m, a cada 0,55 s; acerta todos os inimigos terrestres no arco |
| Q — Impacto no Chão | 28 de dano num raio de 4,5 m ao redor dele, inclusive voadores; atordoa por 1,4 s (exceto o chefe); recarga de 10 s |
| E — Investida de Escudo | Avança 8 m em 0,3 s, invulnerável; 20 de dano e empurra 4 m pela estrada quem estiver na faixa; recarga de 8 s |
| Espaço — Esquiva | Igual à da Patrulheira |

O golpe básico não alcança voadores, então a defesa antiaérea depende das torres e do Impacto.

## Melhorias (28)

| Raridade | Melhorias |
|---|---|
| Comum (10) | Flechas Afiadas, Pólvora Pesada, Congelamento Profundo, Visão Longa, Recarga Rápida, Caçador de Recompensas, Núcleo Reforçado, Espinhos Serrilhados, Vigor, Mestre Construtor |
| Rara (9) | **Flechas Perfurantes**, **Projéteis Incendiários** (chão em chamas), **Estilhaçar** (resfriados explodem), **Reação em Cadeia** (armadilhas ativam vizinhas), Olhar Aguçado, **Empaladores** (mola + espinhos), **Mancha de Óleo**, **Sanguessuga Elemental** (herói cura com mortes elementais), **Formação** (torres próximas) |
| Épica (5) | **Gelo Condutor** (raios a partir do gelo), **Críticos Voláteis** (críticos explodem), **Ricochete**, **Estandartes de Batalha**, **Dinheiro Sangrento** (mais ouro, mais inimigos) |
| Lendária (4)* | **Saraivada de Meteoros**, **Sobrecarga** (nova elétrica a cada 8 tiros), **Inverno Eterno** (congelamento total), **Engenheiro de Armadilhas** (armadilhas atingem voadores) |

\* desbloqueáveis. As raridades altas mudam o **comportamento** (perfurar, explodir, encadear, congelar), não só os números. Os raros e épicos são, em sua maioria, comportamentos novos.

## Sinergias

**Por marcadores** (`data/synergies.json`), ativadas automaticamente e mostradas no HUD, no mapa e nas cartas ("Ativa sinergia: X"):

| Sinergia | Requisito | Bônus |
|---|---|---|
| Piromaníaco | 2 Fogo | queimaduras +50% |
| Permafrost | 2 Gelo | resfriar +0,8 s |
| Supercondutor | Gelo + Raio | raio contra resfriados +30% |
| Sabotador | 2 Armadilha | recarga de armadilhas −20% |
| Atirador de Elite | 2 Crítico | dano crítico +60% |
| Cinético | Empurrão + 2 Armadilha | espinhos +30% |
| Estrategista | Suporte + 2 Torre | torres +12% de dano |
| Aproveitador | 2 Economia | recompensas de onda +30% |

**Interações entre cartas e estruturas**, com feedback visual ("ESTILHAÇO!", "EMPALADO!", "SUPERCONDUÇÃO!"…):
- Gelo + eletricidade: resfriados sofrem +50% de raio, e o Gelo Condutor encadeia raios.
- Fogo + óleo: inimigos com óleo sofrem +50% de fogo, ou ×2 com Mancha de Óleo, e queimam pelo dobro do tempo.
- Empurrão + espinhos: quem cai sobre espinhos sofre dano de impacto, ×3 com Empaladores. A Rajada do herói também lança inimigos.
- Críticos + ricochete ou explosão.
- Suporte + torres ofensivas: Estandarte, Formação e Estandartes de Batalha recompensam o posicionamento.

## Jornada, eventos e progressão

- **Jornada:** 7 camadas (2–3 nós nas intermediárias), com pelo menos uma elite e um mercador garantidos e um acampamento ou mercador antes do chefe.
- **Eventos:** Altar Sombrio (vida do núcleo por melhoria rara), Mercador Errante, Mapa Antigo (ouro agora, batalha mais difícil depois), Arsenal Abandonado, Poço Amaldiçoado (aposta).
- **Essência:** 1 por onda, 4 por batalha, 8 por elite, 30 pelo chefe, +20 pela vitória, multiplicada pelos desafios ativos.
- **Santuário:** desbloqueia Estandarte, Piche, relíquias lendárias e desafios. Desbloqueios ampliam as opções, nunca dão atributos permanentes.
- **Desafios:** Hordas (+40% de inimigos), Núcleo de Vidro (−50 de vida), Inimigos Velozes (+20%), Escassez (−30% de ouro). Cada um rende +30–40% de essência.
