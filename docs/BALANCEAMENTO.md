# Balanceamento

## Método

`tools/balance_sim.gd` joga jornadas inteiras com o `Autopilot`, um jogador scriptado que gasta ouro em torres e armadilhas perto da estrada, melhora estruturas e escolhe caminhos e recompensas ao acaso. **Ele não usa o herói**, então funciona como um piso: um jogador humano, que luta, usa habilidades e escolhe melhorias com intenção, deve ir melhor.

```bash
SIM_RUNS=12 godot --headless --path . --script res://tools/balance_sim.gd
SIM_RUNS=12 SIM_MODS=hordes,swift_foes godot --headless --path . --script res://tools/balance_sim.gd
```

## Iterações

| Versão | Mudança | Vitórias do autopiloto |
|---|---|---|
| v1 | Valores iniciais | 100%, núcleo quase intacto |
| v2 | Vida +30% por camada, orçamento de ondas maior, menos ouro de onda | 100% |
| v3 | Vida +60% por camada, orçamento +70% por camada | 100%, mas o núcleo começou a sofrer no chefe |
| **v4 (atual)** | Ouro por abate cortado pela metade, elites dão ×2 de ouro | **25% (3/12)**, profundidade média de 5,2 de 6 |

A medição por encontro mostrou o problema da v1 a v3: as defesas **persistem** durante a jornada, e o ouro por abate fazia o forte chegar a 46–66 estruturas. O meio da jornada ficava trivial e só o chefe ameaçava. Com a economia apoiada no ouro das ondas, o núcleo sofre desde a primeira batalha e as derrotas se distribuem entre batalhas, elite e chefe (5 de 9 no chefe).

## Leitura e próximos ajustes

- O alvo inicial para a dificuldade padrão é um jogador médio vencer entre 30% e 50% das primeiras jornadas. O autopiloto sem herói em 25% é um piso razoável, mas **só testes com pessoas confirmam isso**.
- O chefe é o principal muro. Se for frustrante, reduzir o dano ao núcleo quando ele vaza (45) ou a frequência das invocações.
- Monitorar builds dominantes: rodar a simulação forçando conjuntos de melhorias (fácil de adicionar ao `Autopilot`) e comparar as taxas de vitória.
