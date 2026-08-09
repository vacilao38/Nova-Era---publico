# Metodo - Resumo de Sessao por Legenda

Use este metodo para transformar arquivos `.srt` gerados automaticamente em notas de evento coerentes para o vault de **Nova Era**.

## Objetivo
Criar uma nota de evento em `6 Historia`, com resumo competente da sessao, links Obsidian para personagens, locais e conceitos, correcao de nomes/frases da legenda automatica e atualizacao da timeline.

## Fluxo

1. **Confirmar o arquivo e a sessao**
   - Verificar nome, tamanho e duracao do `.srt`.
   - Confirmar se o nome do arquivo bate com a sessao real.
   - Ler inicio e fim da legenda para identificar recap, gancho inicial e encerramento.

2. **Ler o contexto anterior**
   - Consultar `6 Historia/Nova Era - Linha do Tempo.md`.
   - Consultar a visao cronologica do arco atual.
   - Ler as notas imediatamente anteriores da mesma pasta/arco.
   - Identificar ganchos pendentes que a nova sessao pode resolver.

3. **Extrair a sessao em blocos**
   - Dividir a legenda por blocos de tempo.
   - Separar conversa de mesa, recap, roleplay, exploracao, combate, revelacoes e gancho final.
   - Buscar termos-chave com `rg`: nomes de personagens, locais, itens, divindades, inimigos, conceitos e faccoes.

4. **Corrigir a transcricao automatica**
   - Corrigir nomes usando o vault como fonte: personagens, locais, conceitos, itens e deuses.
   - Tratar palavras deformadas pela legenda automaticamente.
   - Nao cravar como fato o que ainda e inferencia; usar "sugere", "pode indicar", "possivelmente".

5. **Criar a nota do evento**
   - Salvar em `6 Historia/eventos/<arco>/<mini-arco>/`.
   - Usar estrutura:
     - titulo
     - Projeto / Tipo / Sessao / Data
     - `## local`
     - `## Conteudo`
     - `## Topicos`
     - `## Pendencias e ganchos`
     - `## Conexoes`
   - Usar links Obsidian para personagens, locais, conceitos e eventos: `[[Nome]]`.
   - Usar alias quando necessario: `[[mane|Deus da Lua]]`.

6. **Atualizar cronologias**
   - Adicionar o evento em `6 Historia/Nova Era - Linha do Tempo.md` como embed:
     - `![[Nome do evento]]`
   - Atualizar a visao cronologica do arco atual com um paragrafo curto e/ou linha na tabela consolidada.
   - Corrigir notas anteriores quando a nova informacao resolve contradicoes.

7. **Revisar links e consistencia**
   - Checar links que ja existem no vault.
   - Manter links futuros quando forem bons pontos de criacao futura.
   - Conferir grafias recorrentes: [[Blanck]], [[Navi]], [[Scann]], [[Aurélia]], [[Odr]], [[Desk]], [[Círculo Dourado]], [[Sofandi]].
   - Confirmar que pendencias relevantes continuam registradas.

## Cuidados especificos de Nova Era
- Sempre cruzar eventos com a pasta `6 Historia` antes de resumir.
- Preservar incertezas de lore como incertezas.
- Destacar mudancas de status: aliancas, inimigos derrotados, objetos obtidos, permissoes, revelacoes, traicoes e ganchos.
- Quando aparecerem braceletes numerados, relacionar com o [[Círculo Dourado]] se a caligrafia/refino combinar com o Palacio Real, mas como hipotese se nao houver confirmacao.
- Ao final, informar quais arquivos foram criados/alterados.
