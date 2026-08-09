# Nova Era — versão para o Ruan

Este repositório contém a versão compartilhável do vault **NOVA ERA MANAGE - Pinheral**. Ele é atualizado a partir de `C:\Users\Rogerin\Documents\nvera\NOVA ERA MANAGE` sem publicar arquivos ocultos, backups, fontes brutas ou as notas pessoais de Pedro/Elder.

## Para o Ruan

Clone uma vez:

```powershell
git clone URL_DO_REPOSITORIO "NOVA ERA MANAGE - Pinheral"
```

Para receber a versão mais recente:

```powershell
git pull --ff-only
```

## Sincronização do proprietário

- `Automacao/Sincronizar-Vault-Ruan.ps1` copia mudanças permitidas, reflete exclusões já gerenciadas e pode criar/enviar commits.
- `Automacao/Observar-Vault-Ruan.ps1` observa o vault de origem e agrupa cada salvamento em um commit automático.
- `Automacao/Instalar-AutoSync-Ruan.ps1` registra o observador para iniciar junto com o Windows; se o Agendador de Tarefas não estiver disponível, usa a pasta de Inicialização do usuário.

O estado interno da sincronização fica dentro de `.git` e nunca é publicado. Na primeira execução, arquivos curados que existem apenas nesta versão são preservados.

## Limites de privacidade

O filtro exclui:

- qualquer arquivo ou pasta oculta da origem;
- pastas `notas - <jogador>`;
- cânone privado, planejamento, mecânicas, arquivos e materiais de apoio ainda privados da Elder;
- ideias pessoais, análises privadas, backups, exportações e fontes brutas de WhatsApp.

Os registros públicos da Elder e sua história ocorrida em sessão continuam incluídos na forma curada que já existe nesta versão. Como a origem contém versões mais extensas e privadas desses mesmos arquivos, todo o ramo Pedro/Elder é protegido contra sobrescrita automática.
