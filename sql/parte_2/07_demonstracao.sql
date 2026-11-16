-- Webdriver - Parte 2
-- 07_demonstracao.sql - Roteiro de demonstracao

-- Executar apos os scripts 01 a 05.
-- Este roteiro altera dados. Para repetir, recrie a base.
-- Parte A: executar como root.
-- Parte B: testar com as contas indicadas no README.

USE webdriver;

-- A. Demonstracao como root

-- A1. Funcao mais_de_100_dias
-- Verifica se os arquivos possuem mais de 100 dias.
-- Esperado: 1 para os 6 arquivos de teste.
SELECT id_arquivo, nome, data_ultima_modificacao,
       mais_de_100_dias(id_arquivo) AS mais_de_100_dias
FROM arquivo;

-- A2. Conta_usuarios
-- Conta os usuarios com acesso a cada arquivo.
-- Esperado: arquivo 1 = 3, arquivo 2 = 1, arquivo 6 = 2.
CALL conta_usuarios(1, @total); SELECT @total;
CALL conta_usuarios(2, @total); SELECT @total;
CALL conta_usuarios(6, @total); SELECT @total;

-- A3. Chavear
-- Alterna a prioridade do arquivo.
-- Esperado: arquivo 2 muda para nao_prioritario e retorna.
CALL chavear(2);
CALL chavear(2);

-- A4. Safe_security
-- Impede a insercao de arquivos executaveis.
-- Teste comentado para nao interromper a demonstracao.
-- Esperado: erro 1644.
-- INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario)
-- VALUES ('instalador.exe', 'application/x-msdownload', 'somente proprietário', 1048576,
--         CURDATE(), '/armazenamento/u4/instalador.exe', 'https://webdriver.exemplo.test/arquivos/x', 4);

-- A5. Registrar_operacao
-- Insere um arquivo e registra sua operacao.
-- Esperado: nova atividade com acesso prioritario.
START TRANSACTION;
INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario)
VALUES ('oficina_reciclagem.pdf', 'application/pdf', 'proprietário e compartilhados', 204800,
        CURDATE(), '/armazenamento/u4/oficina_reciclagem.pdf', 'https://webdriver.exemplo.test/arquivos/7', 4);
SET @id_novo = LAST_INSERT_ID();
INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo)
VALUES ('carregar', CURDATE(), CURTIME(), 4, @id_novo);
INSERT INTO historico_versionamento (data, hora, operacao, conteudo_mudado, id_usuario, id_arquivo)
VALUES (CURDATE(), CURTIME(), 'carregar', 'Versão inicial do roteiro da oficina de reciclagem.', 4, @id_novo);
COMMIT;
SELECT * FROM atividades_recentes WHERE id_arquivo = @id_novo;

-- Verifica a data do arquivo criado.
-- Esperado: 0 (falso).
SELECT mais_de_100_dias(@id_novo) AS mais_de_100_dias;

-- A6. Atualizar_acesso
-- Atualiza a prioridade apos um compartilhamento.
-- Esperado: acesso volta a prioritario.
CALL chavear(@id_novo);
INSERT INTO compartilhamento (id_arquivo, id_compartilhado, id_dono, data_compartilhamento)
VALUES (@id_novo, 1, 4, CURDATE());
SELECT * FROM atividades_recentes WHERE id_arquivo = @id_novo;

-- A6b. Safe_security na atualizacao (P9)
-- Impede alterar um arquivo para executavel.
-- Esperado: erro 1644.
-- UPDATE arquivo SET nome = 'oficina_reciclagem.exe' WHERE id_arquivo = @id_novo;

-- A6c. Limite de espaco (P6)
-- Impede ultrapassar o limite do plano Basico.
-- Esperado: erro 1644.
-- INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario)
-- VALUES ('backup_completo.zip', 'application/zip', 'somente proprietário', 10737418240,
--         CURDATE(), '/armazenamento/u3/backup_completo.zip', 'https://webdriver.exemplo.test/arquivos/backup', 3);

-- A7. Remover_acessos
-- Remove compartilhamentos sem excluir o proprietario.
-- Esperado: 2 acessos removidos; total passa a 1.
CALL remover_acessos(1);
SELECT id_arquivo, id_usuario AS proprietario FROM arquivo WHERE id_arquivo = 1;
CALL conta_usuarios(1, @total); SELECT @total;

-- A8. Verificar_atividades
-- Atualiza as datas da tabela atividades_recentes.
-- Esperado: 7 registros atualizados.
CALL verificar_atividades();
SELECT * FROM atividades_recentes;

-- B. Demonstracao das views e roles

-- Executar em conexoes separadas no MySQL Workbench.
-- Credenciais disponiveis no README.
-- Testes consideram a Parte A ja executada.

-- B1. Usuario ana.souza (PapelUsuario + PapelEmpresa)
-- Visualiza arquivos proprios, compartilhados e da empresa.

--   SELECT * FROM webdriver.vw_arquivos_usuario;
--     esperado: relatorio_anual_2025.pdf, logo_instituto.png (dela),
--               ata_reuniao_marco.txt e oficina_reciclagem.pdf (compartilhados); sem ids
--   SELECT * FROM webdriver.vw_historico_operacoes;     -- somente leitura
--   SELECT * FROM webdriver.vw_empresa_usuarios;
--     esperado: ana.souza e bruno.lima (Instituto Vida Verde)
--   SELECT * FROM webdriver.vw_empresa_arquivos;
--     esperado: arquivos de ana e bruno
--   UPDATE webdriver.vw_arquivos_usuario SET permissoes_acesso = 'somente proprietário'
--     WHERE nome = 'logo_instituto.png';                 -- esperado: 1 linha alterada
--   DELETE FROM webdriver.vw_historico_operacoes;        -- esperado: erro (DELETE negado: historico so leitura)
--   SELECT * FROM webdriver.arquivo;                     -- esperado: erro 1142 (tabela base)
--   SELECT * FROM webdriver.atividades_recentes;         -- esperado: erro 1142 (so root)
--   CALL webdriver.carregar_arquivo('plano_acao.pdf', 'application/pdf', 'somente proprietário',
--        51200, '/armazenamento/u1/plano_acao.pdf',
--        'https://webdriver.exemplo.test/arquivos/plano_acao', 'Versão inicial do plano de ação.');
--     esperado: arquivo carregado em nome de ana.souza (P5); aparece em vw_arquivos_usuario

-- B2. Usuario carla.mendes (PapelUsuario)
-- Visualiza apenas seus arquivos e compartilhamentos.

--   SELECT * FROM webdriver.vw_arquivos_usuario;
--     esperado: video_campanha.mp4 (dela) e planilha_doacoes.csv (compartilhado);
--               relatorio_anual_2025.pdf NAO aparece mais (acesso removido em A7)
--   SELECT * FROM webdriver.vw_empresa_usuarios;         -- esperado: erro 1142 (sem PapelEmpresa)

-- B3. Usuario elisa.rocha (PapelAdm)
-- Possui acesso administrativo, respeitando as restricoes.

--   SELECT * FROM webdriver.vw_adm_usuarios;             -- todos os usuarios, sem ids
--   SELECT * FROM webdriver.arquivo;                     -- permitido (toda a base)
--   SELECT * FROM webdriver.atividades_recentes;         -- esperado: erro 1142 (so root)
--   CALL webdriver.chavear(1);                           -- esperado: erro 1370 (sem EXECUTE)
