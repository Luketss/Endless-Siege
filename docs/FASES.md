# Fases de desenvolvimento

Cada fase indica o critério de conclusão, como reproduzir e o estado atual. "✅" significa implementado e coberto por teste automatizado ou verificado em execução.

## Fase 1: Protótipo de combate ✅

- **Critério:** movimentação, câmera, inimigos seguindo o caminho, ataques e vida da base.
- **Entregue:** herói (WASD, câmera no ombro, tiro), inimigos pela estrada, núcleo com vida, derrota.
- **Testes:** `test_enemy_walks_the_road_and_leaks`, `test_defeat_when_core_destroyed`, `test_hero_and_build_input`.
- **Reproduzir:** F5 → Nova jornada → Batalha → `G`.

## Fase 2: Tower Defense ✅

- **Critério:** construção, posicionamento, economia, torres e armadilhas.
- **Entregue:** posicionamento livre validado (estrada, colisão, terreno, linha de visão), 4 torres e 3 armadilhas, melhorar, vender, modos de alvo, ouro por abate, por onda e por suprimentos.
- **Testes:** `test_build.gd` (15 testes: posicionamento, platôs, custo, venda, linha de visão, cada torre e armadilha).

## Fase 3: Combate e IA ✅

- **Critério:** herói com habilidades, inimigos especializados e chefe.
- **Entregue:** Chuva de Flechas, Rajada, esquiva, níveis; voador, blindado, divisor, feiticeiro (desativa torres), guardião (aura), elites; Dragão Ancestral com 3 fases.
- **Testes:** `test_hero_*`, `test_warden_*`, `test_hexer_*`, `test_splitter_*`, `test_boss_phases`.

## Fase 4: Roguelike ✅

- **Critério:** melhorias aleatórias, raridades, sinergias e eventos.
- **Entregue:** 28 melhorias, 4 raridades, 8 sinergias por marcadores mais interações, 5 eventos, loja e acampamento.
- **Testes:** `test_roguelike.gd` (raridade, exclusões, sinergias, perfurar, estilhaçar, empalar, cadeia, chão em chamas, sobrecarga, determinismo da jornada).

## Fase 5: Progressão ✅ (básica)

- **Critério:** desbloqueios, jornadas, recompensas e salvamento.
- **Entregue:** essência, Santuário (4 desbloqueios), desafios, jornada salva entre encontros, saves com checksum e backup.
- **Testes:** `test_progression.gd` (corrupção de save, serialização, essência, jornadas completas).

## Fase 6: Polimento ⏳ (parcial)

| Feito | Pendente |
|---|---|
| Interface completa (HUD, jornada, cartas, configurações, remapeamento, PT/EN) | **Identidade visual própria**: hoje usamos packs CC0 de Kenney/Quaternius (bons para protótipo e teste, mas genéricos) |
| Modelos 3D animados CC0 para heroína, inimigos, chefe, torres e cenário (`data/visuals.json`, com fallback procedural) | Modelos para armadilhas, núcleo e portal; animação de ataque dos inimigos contra a heroína |
| Efeitos visuais (explosões, faíscas, números, raios, anéis) e feedback de sinergias | **Áudio gravado** e música composta (hoje sintetizados; a API de música dinâmica já existe) |
| Música dinâmica em duas camadas | Medição de desempenho em hardware real e perfis gráficos |
| Opções de qualidade (sombras, efeitos, FPS) | **Balanceamento com jogadores reais** |
| Balanceamento inicial por simulação | Tutorial interativo (hoje são dicas na primeira batalha) |

## Fase 7: Distribuição ⏳ (preparada)

| Feito | Pendente |
|---|---|
| Builds de Windows e Linux pela CLI e pela CI | Executar e testar o build de Windows em máquina Windows |
| Modelos de upload SteamPipe | IDs de app/depot, integração GodotSteam, conquistas, Steam Cloud |
| Checklist da loja | Página da loja, trailer, cápsulas, requisitos mínimos medidos |
| Suporte a controle (layout Xbox, menus pelo D-pad) | Teste em Steam Deck real |

## Próximo conteúdo (depois de validar o núcleo)

1. Mago (o Guerreiro já está pronto; heróis são definidos em `data/heroes.json` e as habilidades ficam em `BattleSim`).
2. Novos biomas e mapas (ruínas, fortalezas, cavernas) com desafios ambientais.
3. Estruturas de atração ou agrupamento (iscas) e armadilhas elementais adicionais.
4. Mais eventos, relíquias e chefes.
