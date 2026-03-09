# Changesets

Este diretório é gerenciado pelo [Changesets](https://github.com/changesets/changesets).

## Como usar

1. Após sua feature/fix, rode:
   ```bash
   pnpm changeset
   ```
2. Descreva a mudança (patch | minor | major) e gere o arquivo `.md`
3. Commite junto com a feature
4. Na release, rode:
   ```bash
   pnpm changeset version   # bump versions + atualiza CHANGELOG.md
   pnpm changeset publish   # publica (se aplicável)
   ```

O workflow de release no GitHub Actions faz isso automaticamente via PR de release.
