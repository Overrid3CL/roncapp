# Expo HAS CHANGED

Read the exact versioned docs at https://docs.expo.dev/versions/v54.0.0/ before writing any code.

## Code Search (Semble)

Use `semble search` to find code por descripción natural en vez de grep:

```bash
semble search "auth flow" ./
semble search "offline sync" ./
semble search "audio recording" ./ --top-k 10
```

Use `semble find-related` con file_path + line para descubrir código relacionado:

```bash
semble find-related src/lib/supabase.ts 15 ./
```

Path default es `./` cuando se omite. Git URLs también aceptados.
Si `semble` no esta en PATH, usar `uvx --from "semble[mcp]" semble`.

### Workflow

1. Empezar con `semble search` para encontrar chunks relevantes.
2. Inspeccionar archivos completos solo si el chunk retornado no es suficiente.
3. Opcionalmente usar `semble find-related` con `file_path` y `line` de un resultado para descubrir implementaciones relacionadas.
4. Usar grep solo cuando se necesiten matches literales exhaustivos o confirmación rapida de un string exacto.
