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
- arquivos pessoais chamados `Anotações pedro.md`.

Os registros públicos da Elder e sua história ocorrida em sessão continuam incluídos na forma curada que já existe nesta versão. Como a origem contém versões mais extensas e privadas desses mesmos arquivos, todo o ramo Pedro/Elder é protegido contra sobrescrita automática.

## Contribuições do Ruan (branch `correcoes-ruan`)

Esta branch traz de volta material que só existia no vault local do Ruan, para revisão:

- **`9 Planejamento/Alfheim/`** — propostas de worldbuilding para as três Grandes Casas de Alfheim (Brensver, Lumína, Vakker): o mecanismo de licença mágica dos Vakker, o teste de sangue e reconhecimento de linhagem, a divisão de autoridade entre as três Casas, e as pendências levantadas em sessão de planejamento com o Pedro sobre esse mecanismo (camada de autorização, testes para não-magos, divergência feiticeiro/mago, magia selvagem). Tudo marcado como rascunho — nada é canon até validação do mestre.
- **10 correções de sessão** reconciliadas com a base pública: grafia `Floorn→Florn` e `Bresnver→Brensver`, o erro "Blanck bêbada quase mata Scann" corrigido para "Elder bêbada" em `Arco de Vanaheim - Visão Cronológica.md`, data do Festival dos Vagalumes (18/05→17/05) e outras datas já fechadas, e a afiliação do Florn aos Quatro Ventos incorporada em `Florn.md` (marcada `#suspeita`, ainda sem fonte de sessão confirmada).

Fora do escopo desta branch, de propósito: notas pessoais e relações da Blanck, e os arquivos de prompt/contexto de trabalho do Ruan — não são relevantes para o restante da mesa.
