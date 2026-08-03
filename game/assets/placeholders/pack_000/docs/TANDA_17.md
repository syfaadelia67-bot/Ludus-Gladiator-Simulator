# Tanda 17 — Cierre del Pack 000

Esta tanda no agrega arte nuevo.

Agrega:

- `MANIFEST_FINAL.md`
- índice completo de carpetas;
- resumen de licencias;
- checklist de cierre;
- script PowerShell de auditoría.

## Auditoría

Desde la carpeta `game`:

```powershell
powershell -ExecutionPolicy Bypass -File `
  ".\assets\placeholders\pack_000\tools\audit_pack_000.ps1"
```

El script revisa:

- archivos vacíos;
- extensiones inesperadas;
- nombres con espacios o mayúsculas;
- nombres repetidos;
- PNG idénticos por SHA-256;
- firma PNG inválida.

La detección de duplicados idénticos es informativa: algunos elementos pueden ser duplicados intencionales y deben revisarse manualmente.
