# Builds (Windows/Linux) e Steam

## Status

| Item | Status |
|---|---|
| Preset Windows Desktop (x86_64) | ✅ exporta (`build/windows/EndlessSiege.exe` + `.pck`), validado em Linux; **não foi executado em Windows** |
| Preset Linux (x86_64) | ✅ exporta e roda (testado com renderização via Xvfb) |
| CI exportando os dois e publicando artefatos | ✅ `.github/workflows/ci.yml` |
| Ícone embutido no .exe | ⚠️ exige `rcedit` configurado no editor (em Linux a exportação avisa e segue sem ícone) |
| Assinatura de código Windows | ⏳ pendente (certificado necessário) |
| Integração Steamworks (conquistas, overlay, nuvem) | ⏳ pendente: planejada via GodotSteam |
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
- **Pendente para o selo "Verificado":** suporte a controle (gamepad). O mapa de entrada é centralizado em `Settings.DEFAULT_BINDINGS`, então basta adicionar eventos de joystick e um modo de mira por analógico. Também falta testar o texto em 1280×800.

## Integração Steamworks (próximo passo)

1. Adicione o [GodotSteam GDExtension](https://godotsteam.com/) para 4.3 em `addons/godotsteam/`.
2. Crie `steam_appid.txt` com o App ID (só para desenvolvimento, não envie no depot).
3. Crie um autoload `SteamService` que inicialize com `Steam.steamInitEx()` apenas quando o recurso `steam` estiver presente (`OS.has_feature("steam")`, já definido nos presets) e que **não quebre o jogo offline** se a Steam não estiver aberta.
4. Ganchos sugeridos: conquistas em `Profile.finish_run` (primeira vitória, desafios) e Steam Cloud para `user://profile.json` e `user://run.json` (configure Auto-Cloud no Steamworks).

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
