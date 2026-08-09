# Relatório de extração

## Diagnóstico
- O PDF possui texto extraível: sim, há operadores de texto em streams decodificadas.
- OCR obrigatório: não para esta primeira versão.
- Observação: o PDF usa object streams; por isso o script expande ObjStm antes de reconstruir a ordem das páginas.
- Tabelas e colunas podem exigir revisão manual, porque o texto de PDF nem sempre preserva layout.
- A extração por página fica cacheada em _extração/paginas para reruns rápidos.

## Métricas
- Bytes do PDF: 18016094
- Objetos PDF brutos: 1270
- Objetos expandidos: 18197
- Streams detectadas: 844
- Streams com FlateDecode: 684
- Páginas detectadas: 314
- Páginas com texto extraído: 289
- Notas Markdown encontradas: 368
- Notas individuais de magia em arquivo: 272
- Cabeçalhos de magia detectados: 341

## Problemas de extração
- Nenhum problema de stream registrado.

## Tabelas para revisar
- Nenhuma tabela candidata foi convertida automaticamente.
