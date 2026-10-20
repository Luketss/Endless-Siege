# Builds (Windows/Linux) e Steam

## Status

| Item | Status |
|---|---|
| Preset Windows Desktop (x86_64) | ✅ exporta (`build/windows/EndlessSiege.exe` + `.pck`), validado em Linux; **não foi executado em Windows** |
| Preset Linux (x86_64) | ✅ exporta e roda (testado com renderização via Xvfb) |
| CI exportando os dois e publicando artefatos | ✅ `.github/workflows/ci.yml` |
| Ícone embutido no .exe | ⚠️ exige `rcedit` configurado no editor (em Linux a exportação avisa e segue sem ícone) |
| Assinatura de código Windows | ⏳ pendente (certificado necessário) |
| Integração Steamworks | ✅ ponte `SteamService` com 10 conquistas, que só funciona com o GodotSteam instalado. ⏳ Falta adicionar o plugin, configurar o App ID e cadastrar as conquistas no Steamworks |
| Scripts de upload SteamPipe | ✅ modelos em `steam/scripts/` (faltam os IDs de app e depots) |

## Gerar os builds

1. Instale o Godot 4.3 e os **export templates** (Editor → Gerenciar Templates de Exportação).
2. Para o ícone do Windows: baixe o [rcedit](https://github.com/electron/rcedit/releases) e configure em Editor → Configurações do Editor → Exportação → Windows → rcedit (no Linux/macOS também é preciso configurar o `wine`).
3. Rode:

```bash
GODOT=/caminho/godot tools/export_all.sh
# ou pelo editor: Projeto → Exportar → Windows Desktop / Linux
```

Saída: `build/windows/` e `build/linux/`. Cada um tem o executável e o `.pck`; os dois arquivos precisam ficar juntos.

## Steam Deck

- Use o build de **Linux** (nativo). A interface escala com a resolução (padrão de 1920×1080 com `canvas_items`/`expand`), e o 1280×800 do Deck funciona com a escala da interface ajustável.
- **Controle:** layout fixo em `Settings.PAD_BINDINGS` (analógicos, gatilhos, D-pad), câmera no analógico direito com resposta quadrática e mira assistida, dicas na tela que seguem o último dispositivo, e navegação de menus pelo autoload `PadFocus`. O remapeamento do controle fica com o Steam Input.
- **Pendente para o selo "Verificado":** testar em um Deck real e conferir o tamanho do texto em 1280×800.

## Integração Steamworks

O autoload `SteamService` (`scripts/autoload/steam_service.gd`) só fala com a Steam se o singleton `Steam` do GodotSteam existir e `steamInitEx()` funcionar. Sem isso, cada chamada não faz nada: o jogo roda offline, no editor e em builds sem DRM.

As conquistas são definidas em `data/achievements.json` e avaliadas por `Achievements.check` ao fim de cada jornada. Elas ficam salvas no perfil local (Santuário → Conquistas) e são repassadas para a Steam, inclusive as ganhas offline, que sincronizam na próxima abertura com a Steam.

Para ativar:

1. Adicione o [GodotSteam GDExtension](https://godotsteam.com/) para 4.3 em `addons/godotsteam/`.
2. Crie `steam_appid.txt` com o App ID. Ele serve só para desenvolvimento e não vai no depot.
3. No Steamworks, crie as conquistas com os **mesmos nomes de API** das chaves do JSON: `first_victory`, `halfway`, `fortress`, `challenger`, `blade_master`, `arcanist`, `frostbitten`, `synergist`, `legend` e `slayer`. Os textos em PT/EN estão nas chaves `ACH_*` de `tools/translations_source.py`.
4. Configure o Auto-Cloud para `user://profile.json` e `user://run.json`.
5. Opcional: chame `SteamService.presence("steam_display", "#InBattle")` para mostrar a rich presence aos amigos (é preciso definir os tokens no Steamworks).

## Upload pelo SteamPipe

1. Preencha `AppID` e os `DepotID` em `steam/scripts/*.vdf`.
2. Gere os builds em `build/`.
3. Rode `steamcmd +login <usuario> +run_app_build ../steam/scripts/app_build.vdf +quit` (a partir da pasta do `steamcmd`, ajustando o caminho).
4. No Steamworks, publique o build num branch de testes (`beta`) antes do `default`.

## Checklist da página da loja

- Cápsulas e capturas: `tools/screenshot.gd` gera bases em 1920×1080, mas a arte final substituirá os placeholders.
- Trailer (gameplay real), descrição curta e longa em PT/EN, marcadores (Tower Defense, Roguelike, Ação, 3D, Estratégia).
- Requisitos mínimos: medir em hardware real (pendente).
- Classificação etária e política de privacidade (o jogo é offline e não coleta dados).
