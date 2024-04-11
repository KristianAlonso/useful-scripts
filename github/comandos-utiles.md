### Transferir multiples incidencias desde un repositorio a otro

Ver: [Bulk migrate issues with the GitHub CLI](https://jloh.co/posts/bulk-migrate-issues-github-cli/)

Powershell:

```powershell
gh issue list -s all -L 500 --json number --jq '.[] | .number' | ForEach-Object  {"gh issue transfer $PSItem https://github.com/aliaddo/erp"} | Invoke-Expression
```

> **Nota**
> 1. Se requiere tener instalada la [GitHub CLI](https://github.com/cli/cli)
> 2. Máximo se pueden transferir 60 incidencias, luego aparece el error `GraphQL: Validation failed: was submitted too quickly (transferIssue)` y hay que esperar 30 segundos para ejecutar el comando nuevamente

### Enlaces de referencia
+ jq lang: https://jqlang.github.io/jq/manual/#basic-filters
+ Everything you wanted to know about arrays: https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-arrays?view=powershell-7.4#pipeline
+ Run String as Command in PowerShell: https://java2blog.com/run-string-as-command-powershell/