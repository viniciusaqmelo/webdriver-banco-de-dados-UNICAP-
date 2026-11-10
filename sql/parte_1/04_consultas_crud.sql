-- =====================================================================
-- Webdriver - Parte 1
-- sql/parte_1/04_consultas_crud.sql : inserir, buscar, atualizar e remover
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
--
-- Pre-requisito: executar 01, 02 e 03 antes deste script.
-- Se a Parte 2 ja tiver sido instalada, os triggers tambem atuam aqui
-- (registrar_operacao, atualizar_acesso, safe_security e limite de espaco).
-- Entidade principal do CRUD: arquivo (A31). As operacoes auxiliares
-- cobrem compartilhamento, comentario, suporte e consultas de apoio.
-- As instrucoes estao em blocos independentes e numerados; execute-as
-- na ordem para que os IDs citados nos comentarios correspondam.
-- =====================================================================

USE webdriver;

-- =====================================================================
-- C - INSERIR
-- =====================================================================

-- C1. Carregar um novo arquivo (RN21): arquivo + operacao "carregar"
--     + 1a versao, na mesma transacao. Usuario 4 (diego.alves).
START TRANSACTION;

INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario)
VALUES ('cronograma_oficinas.pdf', 'application/pdf', 'proprietário e compartilhados', 102400,
        CURDATE(), '/armazenamento/u4/cronograma_oficinas.pdf', 'https://webdriver.exemplo.test/arquivos/7', 4);

SET @id_novo_arquivo = LAST_INSERT_ID();   -- esperado: 7

INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo)
VALUES ('carregar', CURDATE(), CURTIME(), 4, @id_novo_arquivo);

INSERT INTO historico_versionamento (data, hora, operacao, conteudo_mudado, id_usuario, id_arquivo)
VALUES (CURDATE(), CURTIME(), 'carregar', 'Versão inicial do cronograma das oficinas.', 4, @id_novo_arquivo);

COMMIT;

-- C2. Compartilhar o novo arquivo com o usuario 1 (id_dono = proprietario).
--     A aplicacao valida antes que id_dono <> id_compartilhado (A10).
INSERT INTO compartilhamento (id_arquivo, id_compartilhado, id_dono, data_compartilhamento)
VALUES (@id_novo_arquivo, 1, 4, CURDATE());

-- C3. Comentar o arquivo (usuario 1 tem acesso pelo compartilhamento C2).
INSERT INTO comentario (conteudo, data, hora, id_usuario, id_arquivo)
VALUES ('Posso incluir a oficina de reciclagem na segunda semana?', CURDATE(), CURTIME(), 1, @id_novo_arquivo);

-- C4. Abrir um suporte sem arquivo relacionado (id_arquivo opcional).
INSERT INTO suporte (data, hora, descricao, id_usuario, id_administrador, id_arquivo)
VALUES (CURDATE(), CURTIME(), 'Gostaria de alterar o e-mail cadastrado.', 2, 2, NULL);

-- =====================================================================
-- R - BUSCAR
-- =====================================================================

-- R1. Buscar um arquivo pelo id, com o login do proprietario.
SELECT a.id_arquivo, a.nome, a.tipo, a.tamanho, a.data_ultima_modificacao,
       a.localizacao, a.url, u.login AS proprietario
FROM arquivo a
JOIN usuario u ON u.id_usuario = a.id_usuario
WHERE a.id_arquivo = 1;

-- R2. Buscar arquivos pelo nome (busca parcial).
SELECT id_arquivo, nome, tipo, data_ultima_modificacao
FROM arquivo
WHERE nome LIKE '%relatorio%';

-- R3. Listar os arquivos de um proprietario (usuario 1).
SELECT id_arquivo, nome, tipo, tamanho, data_ultima_modificacao
FROM arquivo
WHERE id_usuario = 1
ORDER BY nome;

-- R4. Arquivos a que um usuario tem acesso (RN16 = proprietario + compartilhados).
--     Usuario 3 (carla.mendes).
SELECT a.id_arquivo, a.nome, 'proprietário' AS forma_de_acesso
FROM arquivo a
WHERE a.id_usuario = 3
UNION
SELECT a.id_arquivo, a.nome, 'compartilhado' AS forma_de_acesso
FROM arquivo a
JOIN compartilhamento c ON c.id_arquivo = a.id_arquivo
WHERE c.id_compartilhado = 3
ORDER BY id_arquivo;

-- R5. Proprietario e usuarios com acesso a um arquivo (arquivo 1).
SELECT u.login, 'proprietário' AS papel
FROM arquivo a
JOIN usuario u ON u.id_usuario = a.id_usuario
WHERE a.id_arquivo = 1
UNION ALL
SELECT u.login, 'compartilhado' AS papel
FROM compartilhamento c
JOIN usuario u ON u.id_usuario = c.id_compartilhado
WHERE c.id_arquivo = 1;

-- R6. Historico de versoes de um arquivo, da mais recente para a mais antiga.
SELECT h.id_historico, h.data, h.hora, h.operacao, u.login AS alterado_por, h.conteudo_mudado
FROM historico_versionamento h
JOIN usuario u ON u.id_usuario = h.id_usuario
WHERE h.id_arquivo = 1
ORDER BY h.data DESC, h.hora DESC;

-- R7. Operacoes registradas sobre um arquivo.
SELECT o.id_operacao, o.tipo_operacao, o.data, o.hora, u.login AS executada_por
FROM operacao_arquivo o
JOIN usuario u ON u.id_usuario = o.id_usuario
WHERE o.id_arquivo = 1
ORDER BY o.data, o.hora;

-- R8. Comentarios de um arquivo, com o autor.
SELECT c.id_comentario, c.data, c.hora, u.login AS autor, c.conteudo
FROM comentario c
JOIN usuario u ON u.id_usuario = c.id_usuario
WHERE c.id_arquivo = 1
ORDER BY c.data, c.hora;

-- R9. Suportes com solicitante, administrador responsavel e arquivo (se houver).
SELECT s.id_suporte, s.data, s.hora, s.descricao,
       sol.login AS solicitante,
       adm_u.login AS administrador,
       a.nome AS arquivo_relacionado
FROM suporte s
JOIN usuario sol        ON sol.id_usuario = s.id_usuario
JOIN administrador adm  ON adm.id_administrador = s.id_administrador
JOIN usuario adm_u      ON adm_u.id_usuario = adm.id_usuario
LEFT JOIN arquivo a     ON a.id_arquivo = s.id_arquivo
ORDER BY s.data, s.hora;

-- R10. Usuarios com sua instituicao e o plano da instituicao.
SELECT u.id_usuario, u.login, u.email, i.nome AS instituicao, p.nome AS plano, i.data_aquisicao
FROM usuario u
LEFT JOIN instituicao i ON i.id_instituicao = u.id_instituicao
LEFT JOIN plano p       ON p.id_plano = i.id_plano
ORDER BY u.id_usuario;

-- R11. Arquivos de uma instituicao (pelos proprietarios vinculados a ela).
SELECT i.nome AS instituicao, a.id_arquivo, a.nome AS arquivo, u.login AS proprietario
FROM arquivo a
JOIN usuario u     ON u.id_usuario = a.id_usuario
JOIN instituicao i ON i.id_instituicao = u.id_instituicao
WHERE i.id_instituicao = 1;

-- =====================================================================
-- U - ATUALIZAR
-- =====================================================================

-- U1. Atualizar um arquivo (RN22): metadados + data_ultima_modificacao
--     + operacao "atualizar" + nova versao, na mesma transacao.
--     Usuario 2 (bruno.lima) tem acesso ao arquivo 1 por compartilhamento (A34).
START TRANSACTION;

UPDATE arquivo
SET nome = 'relatorio_anual_2025_v2.pdf',
    tamanho = 2621440,
    data_ultima_modificacao = CURDATE()
WHERE id_arquivo = 1;

INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo)
VALUES ('atualizar', CURDATE(), CURTIME(), 2, 1);

INSERT INTO historico_versionamento (data, hora, operacao, conteudo_mudado, id_usuario, id_arquivo)
VALUES (CURDATE(), CURTIME(), 'atualizar', 'Incluído o anexo com a prestação de contas.', 2, 1);

COMMIT;

-- U2. Atualizar o e-mail de um usuario.
UPDATE usuario
SET email = 'bruno.lima.novo@exemplo.test'
WHERE id_usuario = 2;

-- U3. Instituicao 4 adere ao plano 1 (id_plano e data_aquisicao juntos - A32).
UPDATE instituicao
SET id_plano = 1,
    data_aquisicao = CURDATE()
WHERE id_instituicao = 4;

-- U4. Editar o texto de um comentario.
UPDATE comentario
SET conteudo = 'Revisei os números da seção 3 e da seção 4; agora estão corretos.'
WHERE id_comentario = 1;

-- =====================================================================
-- D - REMOVER
-- =====================================================================

-- D1. Remover o acesso de um usuario a um arquivo (remove o compartilhamento).
DELETE FROM compartilhamento
WHERE id_arquivo = 1 AND id_compartilhado = 3;

-- D2. Remover um comentario.
DELETE FROM comentario
WHERE id_comentario = 4;

-- D3. Remover um arquivo (RN23). Somente o proprietario pode remover (A34,
--     validado pela aplicacao). Em cascata, sao removidos compartilhamentos,
--     comentarios, operacoes e historico do arquivo; suporte.id_arquivo vira NULL.
--     Limitacao conhecida (RN24): o registro da remocao tambem e apagado.

-- D3.a Antes: dependentes do arquivo 3
SELECT
    (SELECT COUNT(*) FROM compartilhamento        WHERE id_arquivo = 3) AS compartilhamentos,
    (SELECT COUNT(*) FROM comentario              WHERE id_arquivo = 3) AS comentarios,
    (SELECT COUNT(*) FROM operacao_arquivo        WHERE id_arquivo = 3) AS operacoes,
    (SELECT COUNT(*) FROM historico_versionamento WHERE id_arquivo = 3) AS versoes,
    (SELECT COUNT(*) FROM suporte                 WHERE id_arquivo = 3) AS suportes_ligados;

-- D3.b Remocao
DELETE FROM arquivo
WHERE id_arquivo = 3;

-- D3.c Depois: dependentes devem estar zerados e o suporte 1 sem arquivo
SELECT
    (SELECT COUNT(*) FROM compartilhamento        WHERE id_arquivo = 3) AS compartilhamentos,
    (SELECT COUNT(*) FROM comentario              WHERE id_arquivo = 3) AS comentarios,
    (SELECT COUNT(*) FROM operacao_arquivo        WHERE id_arquivo = 3) AS operacoes,
    (SELECT COUNT(*) FROM historico_versionamento WHERE id_arquivo = 3) AS versoes;

SELECT id_suporte, descricao, id_arquivo
FROM suporte
WHERE id_suporte = 1;

-- D4. Tentativa de remover um usuario que possui arquivos.
--     Resultado esperado: ERRO 1451 (restricao de chave estrangeira), pois
--     usuario possui ON DELETE RESTRICT (A31). Mantido comentado para que o
--     script rode ate o fim; descomente para demonstrar.
-- DELETE FROM usuario WHERE id_usuario = 1;
