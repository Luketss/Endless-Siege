# Arquitetura

## Engine: Godot 4 vs. Unity

| Critério | Godot 4.3 | Unity 6 |
|---|---|---|
| 3D estilizado em PC | Renderizador Forward+ (Vulkan/D3D12), sombras, SSAO, glow e névoa suficientes para estilo low-poly; fallback de compatibilidade (OpenGL) para máquinas fracas | Superior em 3D de alta fidelidade (HDRP), shaders e VFX Graph |
| Ferramentas de edição | Editor leve, cenas em texto, iteração rápida | Ferramentas mais maduras, Asset Store enorme |
| Produtividade para equipe pequena | GDScript simples; o projeto inteiro roda e é testado headless em CI | C# robusto, mas o projeto é mais pesado para CI |
| Licença / custo comercial | MIT, sem royalties nem taxas | Planos pagos acima de certa receita e histórico recente de mudanças de licença |
| Publicação na Steam (Windows/Linux/Deck) | Exportação nativa Windows e Linux; Steamworks via GodotSteam (GDExtension) | Exportação madura; Steamworks.NET/Facepunch |
| Riscos | Ecossistema menor; Steamworks depende de plugin da comunidade | Custo e dependência de licença; projeto mais pesado |

**Recomendação: Godot 4.** Para um indie 3D estilizado, com equipe pequena e foco em sistemas (TD + roguelike), pesam mais a iteração rápida, os testes automatizados headless, a ausência de royalties e o build de Linux/Steam Deck nativo. A desvantagem real é o ecossistema menor, mitigado aqui por arte procedural no protótipo e pela integração Steamworks via GodotSteam (planejada; ver [BUILD_E_STEAM.md](BUILD_E_STEAM.md)).

## Camadas

```
data/*.json ─► core/ (simulação pura, determinística, testável) ◄─ autopilot (testes/balanceamento)
                  ▲ comandos do herói/construção      │ eventos (hit, death, synergy, wave_cleared…)
                  │                                    ▼
game/ (mundo 3D, herói, câmera, construção, renderização, efeitos)    ui/ (HUD, painéis, menus)
                              autoload/ (Settings, Profile, Sfx, Music)
```

- **`scripts/core/`**: regras sem nós nem renderização (`RefCounted`).
  - `BattleSim`: batalha em tempo real (inimigos, torres, armadilhas, projéteis, zonas, herói, efeitos das melhorias). Passo fixo de 1/60 s, RNG com seed. Emite eventos para a apresentação.
  - `MapDef` / `PathLine` / `BuildRules`: geometria do mapa, linha de visão, validação de posicionamento livre.
  - `RunMods`: soma os efeitos de melhorias, sinergias e desafios (`stat()` / `flag()`). Novas melhorias costumam ser só dados.
  - `WaveDirector`, `Journey`, `UpgradePool`: geração reproduzível por seed das ondas, da jornada e das recompensas.
  - `RunState` / `RunFlow`: estado da jornada e regras entre encontros (loja, eventos, descanso, recompensas).
  - `SafeStore`: persistência JSON com checksum, escrita atômica e backup.
  - `Autopilot`: jogador scriptado usado só em testes e balanceamento.
- **`scripts/game/`**: camada 3D.
  - `WorldBuilder`: monta terreno, estrada, platôs, rampas, obstáculos e colisores a partir do mapa.
  - `BattleView` + `Models` + `FX`: renderização com pooling de inimigos, projéteis e efeitos.
  - `HeroController` (CharacterBody3D), `CameraRig` (SpringArm3D no ombro, mira assistida), `BuildController` (fantasma, alcance, atalhos).
  - `game.gd`: máquina de estados da jornada e da batalha.
- **`scripts/ui/`**: HUD, mapa da jornada, cartas de melhoria, loja e eventos, configurações com remapeamento, menu e resultado.
- **`scripts/autoload/`**: `Settings` (vídeo, áudio, input e idioma), `Profile` (essência, desbloqueios, jornada salva), `Sfx` e `Music` (música dinâmica em duas camadas que acompanha a intensidade da onda).

### Dados configuráveis (`data/`)

| Arquivo | Conteúdo |
|---|---|
| `structures.json` | custo, alcance, cadência, dano, tipo de dano, área, efeitos, cor, desbloqueio |
| `enemies.json` | vida, velocidade, armadura, ouro, dano ao núcleo, habilidades (divisão, feitiço, aura), fases do chefe |
| `upgrades.json` | raridade, marcadores, `stats` (somados) e `flags` (comportamentos) |
| `synergies.json` | marcadores exigidos e bônus |
| `journey.json`, `events.json` | estrutura da jornada, pesos dos encontros, eventos com custos e recompensas |
| `unlocks.json`, `modifiers.json`, `heroes.json`, `balance.json` | progressão permanente, desafios, herói, economia e escalas |
| `maps/forest.json` | estrada, platôs, obstáculos, muralhas, núcleo e spawns |

Adicionar um inimigo, uma torre ou uma melhoria numérica exige apenas dados (mais um modelo em `Models` para a aparência e textos em `tools/translations_source.py`). Comportamentos novos entram como uma `flag` lida em um ponto de gancho da `BattleSim`.

### Reprodutibilidade, saves e falhas

- Seeds por nó (`RunState.node_seed`): ondas, recompensas, lojas e eventos não dependem da ordem de jogo, e o teste `test_waves_deterministic_and_progressive` garante isso.
- Perfil (`user://profile.json`), configurações (`settings.json`) e jornada em andamento (`run.json`) passam pelo `SafeStore`: checksum MD5, gravação em `.tmp` com renomeação e `.bak` do último save válido. Arquivo corrompido cai no backup e, se o backup também falhar, nos padrões, com aviso no menu (coberto por teste).
- A jornada é salva no mapa entre encontros. "Salvar e sair" durante uma batalha retoma do início daquele encontro.

### Desempenho

- Inimigos, projéteis e efeitos não usam física: são dados na simulação e nós visuais reaproveitados (pooling por tipo).
- Uma grade espacial de 4 m acelera mira, colisão de projéteis e áreas.
- Materiais e malhas são compartilhados (cache em `Art`), e a opção "efeitos baixos" desliga partículas e números de dano.
- O herói é o único corpo físico dinâmico. O mundo usa colisores estáticos simples.

### Ferramentas de depuração

- `Tab` mostra o alcance de todas as torres; mirar numa estrutura mostra seu alcance, dano, cadência, abates e dano causado.
- `tools/screenshot.gd` captura cenas reais para revisão visual. `tools/balance_sim.gd` simula jornadas inteiras.
- Todos os testes rodam headless (`tools/run_tests.sh`), inclusive cenas e input do herói.
