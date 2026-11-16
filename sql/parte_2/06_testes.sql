
-- Webdriver - Parte 2
-- sql/parte_2/06_testes.sql
-- Testes automatizados da Parte 2
-- SGBD: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Pre-requisito: Parte 1 (01 a 03) e Parte 2 (01 a 05).
--
-- PARTE A: executar como root.
-- Os testes sao registrados em tst_resultado. Os dados sao desfeitos
-- com ROLLBACK; o AUTO_INCREMENT pode avancar.
-- A tabela temporaria MEMORY preserva os resultados apos o ROLLBACK.
--
-- PARTE B: testes manuais com as contas proprias, no final do arquivo.
-- Os ids T01..T52 identificam os testes.

USE webdriver;

-- 0. Estrutura auxiliar
DROP PROCEDURE IF EXISTS tst_registrar;
DROP PROCEDURE IF EXISTS tst_executar;
DROP TEMPORARY TABLE IF EXISTS tst_resultado;

CREATE TEMPORARY TABLE tst_resultado(
    ordem      INT AUTO_INCREMENT PRIMARY KEY,
    teste      VARCHAR(10)  NOT NULL,
    descricao  VARCHAR(200) NOT NULL,
    esperado   VARCHAR(200) NOT NULL,
    obtido     VARCHAR(200) NOT NULL,
    status     VARCHAR(5)   NOT NULL
) ENGINE = MEMORY;

DELIMITER $$

-- Registra o resultado de um teste.
CREATE PROCEDURE tst_registrar(IN p_teste VARCHAR(10), IN p_descricao VARCHAR(200),
                               IN p_esperado VARCHAR(200), IN p_obtido VARCHAR(200))
BEGIN
    INSERT INTO tst_resultado (teste, descricao, esperado, obtido, status)
    VALUES (p_teste, p_descricao, COALESCE(p_esperado, 'NULL'), COALESCE(p_obtido, 'NULL'),
            IF(COALESCE(p_esperado, 'NULL') = COALESCE(p_obtido, 'NULL'), 'OK', 'FALHA'));
END $$

-- Executa um comando e registra o resultado ou erro esperado.
CREATE PROCEDURE tst_executar(IN p_teste VARCHAR(10), IN p_descricao VARCHAR(200),
                              IN p_comando TEXT, IN p_trecho_erro VARCHAR(100))
BEGIN
    DECLARE v_msg TEXT DEFAULT NULL;          -- Mensagens de erro do MySQL
    DECLARE v_obtido VARCHAR(200);
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    END;

    SET @tst_comando = p_comando;
    PREPARE tst_stmt FROM @tst_comando;
    EXECUTE tst_stmt;
    DEALLOCATE PREPARE tst_stmt;

    IF v_msg IS NULL THEN
        SET v_obtido = 'sem erro';
    ELSEIF p_trecho_erro IS NOT NULL AND LOCATE(p_trecho_erro, v_msg) > 0 THEN
        SET v_obtido = CONCAT('erro: ', p_trecho_erro);
    ELSE
        SET v_obtido = CONCAT('erro: ', LEFT(v_msg, 150));
    END IF;

    CALL tst_registrar(p_teste, p_descricao,
                       IF(p_trecho_erro IS NULL, 'sem erro', CONCAT('erro: ', p_trecho_erro)),
                       v_obtido);
END $$

DELIMITER ;

-- PARTE A: testes como root
START TRANSACTION;

-- A.1 atividades_recentes
SET @tst_obtido = (SELECT COLUMN_KEY FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = 'webdriver' AND TABLE_NAME = 'atividades_recentes' AND COLUMN_NAME = 'id_arquivo');
CALL tst_registrar('T01', 'atividades_recentes tem id_arquivo como PK', 'PRI', @tst_obtido);

SET @tst_obtido = (SELECT (SELECT COUNT(*) FROM mysql.tables_priv  WHERE Db = 'webdriver' AND Table_name = 'atividades_recentes')
          + (SELECT COUNT(*) FROM mysql.columns_priv WHERE Db = 'webdriver' AND Table_name = 'atividades_recentes'));
CALL tst_registrar('T02', 'Nenhum privilegio de tabela/coluna sobre atividades_recentes (so root)', '0', @tst_obtido);

SET @tst_obtido = (SELECT (SELECT COUNT(*) FROM mysql.db WHERE Db = 'webdriver'
               AND User IN ('ana.souza','bruno.lima','carla.mendes','diego.alves','elisa.rocha',
                            'fabio.nunes','gabriela.costa','henrique.dias','PapelUsuario','PapelEmpresa','PapelAdm'))
          + (SELECT COUNT(*) FROM mysql.user
             WHERE User IN ('ana.souza','bruno.lima','carla.mendes','diego.alves','elisa.rocha',
                            'fabio.nunes','gabriela.costa','henrique.dias','PapelUsuario','PapelEmpresa','PapelAdm')
               AND (Select_priv = 'Y' OR Insert_priv = 'Y' OR Update_priv = 'Y' OR Delete_priv = 'Y')));
CALL tst_registrar('T03', 'Nenhuma conta/role do projeto tem privilegio na base inteira ou global', '0', @tst_obtido);

-- A.2 Visões
SET @tst_obtido = (SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'webdriver');
CALL tst_registrar('T04', 'Existem as 14 visoes', '14', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM information_schema.COLUMNS c
     JOIN information_schema.VIEWS v ON v.TABLE_SCHEMA = c.TABLE_SCHEMA AND v.TABLE_NAME = c.TABLE_NAME
     WHERE c.TABLE_SCHEMA = 'webdriver' AND c.COLUMN_NAME LIKE 'id\_%');
CALL tst_registrar('T05', 'Nenhuma visao projeta coluna id_*', '0', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM information_schema.COLUMNS c
     JOIN information_schema.VIEWS v ON v.TABLE_SCHEMA = c.TABLE_SCHEMA AND v.TABLE_NAME = c.TABLE_NAME
     WHERE c.TABLE_SCHEMA = 'webdriver' AND c.COLUMN_NAME = 'senha_hash');
CALL tst_registrar('T06', 'Nenhuma visao projeta senha_hash', '0', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM information_schema.VIEW_TABLE_USAGE
     WHERE VIEW_SCHEMA = 'webdriver' AND TABLE_NAME = 'atividades_recentes');
CALL tst_registrar('T07', 'Nenhuma visao le atividades_recentes', '0', @tst_obtido);

-- A.3 Roles e contas
SET @tst_obtido = (SELECT COUNT(*) FROM mysql.user WHERE User IN ('PapelUsuario', 'PapelEmpresa', 'PapelAdm'));
CALL tst_registrar('T08', 'Existem as roles PapelUsuario, PapelEmpresa e PapelAdm', '3', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM mysql.user
     WHERE Host = '%' AND plugin = 'caching_sha2_password'
       AND User IN ('ana.souza','bruno.lima','carla.mendes','diego.alves','elisa.rocha',
                    'fabio.nunes','gabriela.costa','henrique.dias'));
CALL tst_registrar('T09', '8 contas proprias com caching_sha2_password (host %)', '8', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM mysql.role_edges WHERE FROM_USER = 'PapelUsuario');
CALL tst_registrar('T10', 'PapelUsuario atribuido a 6 contas', '6', @tst_obtido);

SET @tst_obtido = (SELECT GROUP_CONCAT(TO_USER ORDER BY TO_USER) FROM mysql.role_edges WHERE FROM_USER = 'PapelEmpresa');
CALL tst_registrar('T11', 'PapelEmpresa atribuido a ana.souza', 'ana.souza', @tst_obtido);

SET @tst_obtido = (SELECT GROUP_CONCAT(TO_USER ORDER BY TO_USER) FROM mysql.role_edges WHERE FROM_USER = 'PapelAdm');
CALL tst_registrar('T12', 'PapelAdm atribuido aos administradores', 'elisa.rocha,fabio.nunes', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM mysql.default_roles
     WHERE DEFAULT_ROLE_USER IN ('PapelUsuario', 'PapelEmpresa', 'PapelAdm'));
CALL tst_registrar('T13', 'Roles ativas ao conectar (SET DEFAULT ROLE): 9 pares conta-role', '9', @tst_obtido);

SET @tst_obtido = (SELECT Table_priv FROM mysql.tables_priv
     WHERE User = 'PapelUsuario' AND Db = 'webdriver' AND Table_name = 'vw_arquivos_usuario');
CALL tst_registrar('T14', 'PapelUsuario: SELECT, INSERT e UPDATE em vw_arquivos_usuario', 'Select,Insert,Update', @tst_obtido);

SET @tst_obtido = (SELECT GROUP_CONCAT(CONCAT(Table_name, ':', Table_priv) ORDER BY Table_name) FROM mysql.tables_priv
     WHERE User = 'PapelUsuario' AND Db = 'webdriver' AND Table_name LIKE 'vw\_historico\_%');
CALL tst_registrar('T15', 'PapelUsuario: historicos somente leitura',
    'vw_historico_operacoes:Select,vw_historico_versoes:Select', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM mysql.tables_priv
     WHERE User = 'PapelUsuario' AND Db = 'webdriver'
       AND (FIND_IN_SET('Delete', Table_priv) > 0 OR Table_name NOT LIKE 'vw\_%'));
CALL tst_registrar('T16', 'PapelUsuario: nenhum DELETE e nenhuma tabela base', '0', @tst_obtido);

SET @tst_obtido = (SELECT GROUP_CONCAT(Routine_name ORDER BY Routine_name) FROM mysql.procs_priv
     WHERE User = 'PapelUsuario' AND Db = 'webdriver');
CALL tst_registrar('T17', 'PapelUsuario: EXECUTE somente em carregar_arquivo', 'carregar_arquivo', @tst_obtido);

SET @tst_obtido = (SELECT GROUP_CONCAT(CONCAT(Table_name, ':', Table_priv) ORDER BY Table_name) FROM mysql.tables_priv
     WHERE User = 'PapelEmpresa' AND Db = 'webdriver');
CALL tst_registrar('T18', 'PapelEmpresa: somente SELECT nas visoes da empresa',
    'vw_empresa_arquivos:Select,vw_empresa_usuarios:Select', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM mysql.tables_priv
     WHERE User = 'PapelAdm' AND Db = 'webdriver' AND Table_priv = 'Select,Insert,Update,Delete'
       AND Table_name IN ('plano','instituicao','usuario','administrador','arquivo','compartilhamento',
                          'comentario','suporte','operacao_arquivo','historico_versionamento'));
CALL tst_registrar('T19', 'PapelAdm: SELECT, INSERT, UPDATE e DELETE nas 10 tabelas da Parte 1', '10', @tst_obtido);

SET @tst_obtido = (SELECT COUNT(*) FROM mysql.procs_priv
     WHERE Db = 'webdriver' AND Routine_name IN ('chavear', 'verificar_atividades'));
CALL tst_registrar('T20', 'chavear e verificar_atividades sem EXECUTE para nenhuma role/conta', '0', @tst_obtido);

-- Dados temporarios de teste
INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES
    ('tst_101_dias.txt', 'text/plain', 'somente proprietário', 10, CURDATE() - INTERVAL 101 DAY, '/tst/101', 'https://webdriver.exemplo.test/tst/101', 5),
    ('tst_100_dias.txt', 'text/plain', 'somente proprietário', 10, CURDATE() - INTERVAL 100 DAY, '/tst/100', 'https://webdriver.exemplo.test/tst/100', 5),
    ('tst_hoje.txt',     'text/plain', 'somente proprietário', 10, CURDATE(),                     '/tst/hoje', 'https://webdriver.exemplo.test/tst/hoje', 5);
SET @tst_101  = (SELECT id_arquivo FROM arquivo WHERE nome = 'tst_101_dias.txt');
SET @tst_100  = (SELECT id_arquivo FROM arquivo WHERE nome = 'tst_100_dias.txt');
SET @tst_hoje = (SELECT id_arquivo FROM arquivo WHERE nome = 'tst_hoje.txt');

-- A.4 Função dos 100 dias
CALL tst_registrar('T21', 'mais_de_100_dias: alterado ha 101 dias -> verdadeiro', '1', mais_de_100_dias(@tst_101));
CALL tst_registrar('T22', 'mais_de_100_dias: alterado ha exatamente 100 dias -> falso', '0', mais_de_100_dias(@tst_100));
CALL tst_registrar('T23', 'mais_de_100_dias: alterado hoje -> falso', '0', mais_de_100_dias(@tst_hoje));
CALL tst_registrar('T24', 'mais_de_100_dias: arquivo inexistente -> NULL', 'NULL', mais_de_100_dias(-1));

-- A.5 Procedures
INSERT INTO compartilhamento (id_arquivo, id_compartilhado, id_dono, data_compartilhamento) VALUES
    (@tst_hoje, 1, 5, CURDATE()),
    (@tst_hoje, 2, 5, CURDATE());

CALL conta_usuarios(@tst_hoje, @tst_total);
CALL tst_registrar('T25', 'conta_usuarios: dono + 2 compartilhados', '3', @tst_total);

CALL chavear(@tst_hoje);
SET @tst_obtido = (SELECT acesso FROM atividades_recentes WHERE id_arquivo = @tst_hoje);
CALL tst_registrar('T26', 'chavear: prioritario -> nao_prioritario', 'nao_prioritario', @tst_obtido);
CALL chavear(@tst_hoje);
SET @tst_obtido = (SELECT acesso FROM atividades_recentes WHERE id_arquivo = @tst_hoje);
CALL tst_registrar('T27', 'chavear de novo: nao_prioritario -> prioritario', 'prioritario', @tst_obtido);

CALL remover_acessos(@tst_hoje);
SET @tst_obtido = (SELECT COUNT(*) FROM compartilhamento WHERE id_arquivo = @tst_hoje);
CALL tst_registrar('T28', 'remover_acessos: nenhum compartilhamento restante', '0', @tst_obtido);
CALL conta_usuarios(@tst_hoje, @tst_total);
CALL tst_registrar('T29', 'remover_acessos: o proprietario continua com acesso (conta = 1)', '1', @tst_total);
SET @tst_obtido = (SELECT u.login FROM arquivo a JOIN usuario u ON u.id_usuario = a.id_usuario WHERE a.id_arquivo = @tst_hoje);
CALL tst_registrar('T30', 'remover_acessos: proprietario do arquivo inalterado', 'elisa.rocha', @tst_obtido);

CALL verificar_atividades();
SET @tst_obtido = (SELECT COUNT(*) FROM atividades_recentes WHERE ultima_versao <> CURDATE());
CALL tst_registrar('T31', 'verificar_atividades: todas as linhas com a data atual', '0', @tst_obtido);

CALL tst_executar('T32', 'carregar_arquivo: recusado para conta que nao e usuario da plataforma (root)',
    'CALL carregar_arquivo(''tst_root.pdf'', ''application/pdf'', ''somente proprietário'', 10, ''/tst/root'', ''https://webdriver.exemplo.test/tst/root'', ''v1'')',
    'carregar_arquivo: a conta conectada');

-- A.6 Triggers e Safe_security
CALL tst_executar('T33', 'safe_security: bloqueia extensao .exe na insercao',
    'INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_virus.exe'', ''application/octet-stream'', ''somente proprietário'', 10, CURDATE(), ''/tst/v'', ''https://webdriver.exemplo.test/tst/v'', 5)',
    'Safe_security');

CALL tst_executar('T34', 'safe_security: bloqueia tipo MIME executavel na insercao',
    'INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_relatorio.pdf'', ''application/x-msdownload'', ''somente proprietário'', 10, CURDATE(), ''/tst/m'', ''https://webdriver.exemplo.test/tst/m'', 5)',
    'Safe_security');

CALL tst_executar('T35', 'safe_security: permite arquivo comum',
    'INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_foto.png'', ''image/png'', ''somente proprietário'', 10, CURDATE(), ''/tst/f'', ''https://webdriver.exemplo.test/tst/f'', 5)',
    NULL);
SET @tst_foto = (SELECT id_arquivo FROM arquivo WHERE nome = 'tst_foto.png');

CALL tst_executar('T36', 'safe_security_atualizacao: bloqueia renomear para .exe',
    CONCAT('UPDATE arquivo SET nome = ''tst_foto.exe'' WHERE id_arquivo = ', @tst_foto),
    'Safe_security');

CALL tst_executar('T37', 'safe_security_atualizacao: bloqueia mudar o tipo para executavel',
    CONCAT('UPDATE arquivo SET tipo = ''application/x-sh'' WHERE id_arquivo = ', @tst_foto),
    'Safe_security');

CALL tst_executar('T38', 'safe_security_atualizacao: permite atualizacao comum',
    CONCAT('UPDATE arquivo SET permissoes_acesso = ''proprietário e compartilhados'' WHERE id_arquivo = ', @tst_foto),
    NULL);

SET @tst_obtido = (SELECT COUNT(*) FROM atividades_recentes WHERE id_arquivo = @tst_foto);
CALL tst_registrar('T39', 'registrar_operacao (pre-condicao): arquivo novo sem linha de controle', '0', @tst_obtido);
INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo)
VALUES ('carregar', CURDATE() - INTERVAL 3 DAY, CURTIME(), 5, @tst_foto);
SET @tst_obtido = (SELECT CAST(ultima_versao AS CHAR) FROM atividades_recentes WHERE id_arquivo = @tst_foto);
CALL tst_registrar('T40', 'registrar_operacao: cria a linha com a data da operacao',
    CAST(CURDATE() - INTERVAL 3 DAY AS CHAR), @tst_obtido);
INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo)
VALUES ('atualizar', CURDATE(), CURTIME(), 5, @tst_foto);
SET @tst_obtido = (SELECT CAST(ultima_versao AS CHAR) FROM atividades_recentes WHERE id_arquivo = @tst_foto);
CALL tst_registrar('T41', 'registrar_operacao: nova operacao atualiza a data', CAST(CURDATE() AS CHAR), @tst_obtido);

CALL chavear(@tst_foto);
INSERT INTO compartilhamento (id_arquivo, id_compartilhado, id_dono, data_compartilhamento)
VALUES (@tst_foto, 3, 5, CURDATE());
SET @tst_obtido = (SELECT acesso FROM atividades_recentes WHERE id_arquivo = @tst_foto);
CALL tst_registrar('T42', 'atualizar_acesso: novo compartilhamento marca o arquivo como prioritario', 'prioritario', @tst_obtido);

-- A.7 Limite de espaço por usuario
INSERT INTO plano (nome, duracao, espaco_por_usuario) VALUES ('tst_plano_1000_bytes', 1, 1000);
SET @tst_plano = LAST_INSERT_ID();
INSERT INTO instituicao (nome, causa_social, endereco, id_plano, data_aquisicao)
VALUES ('tst_instituicao', 'teste', 'endereço de teste', @tst_plano, CURDATE());
SET @tst_inst = LAST_INSERT_ID();
INSERT INTO usuario (login, senha_hash, data_ingresso, email, id_instituicao)
VALUES ('tst.limite', 'hash-ficticio-de-teste', CURDATE(), 'tst.limite@exemplo.test', @tst_inst);
SET @tst_user = LAST_INSERT_ID();

CALL tst_executar('T43', 'limite de espaco: 600 de 1000 bytes -> permitido',
    CONCAT('INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_a.txt'', ''text/plain'', ''somente proprietário'', 600, CURDATE(), ''/tst/a'', ''https://webdriver.exemplo.test/tst/a'', ', @tst_user, ')'),
    NULL);
SET @tst_a = (SELECT id_arquivo FROM arquivo WHERE nome = 'tst_a.txt');

CALL tst_executar('T44', 'limite de espaco: +500 bytes (1100 > 1000) -> bloqueado',
    CONCAT('INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_b.txt'', ''text/plain'', ''somente proprietário'', 500, CURDATE(), ''/tst/b'', ''https://webdriver.exemplo.test/tst/b'', ', @tst_user, ')'),
    'Limite de espaco');

CALL tst_executar('T45', 'limite de espaco: +400 bytes (exatamente 1000) -> permitido',
    CONCAT('INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_c.txt'', ''text/plain'', ''somente proprietário'', 400, CURDATE(), ''/tst/c'', ''https://webdriver.exemplo.test/tst/c'', ', @tst_user, ')'),
    NULL);

CALL tst_executar('T46', 'limite de espaco: aumentar arquivo de 600 para 700 (1100) -> bloqueado',
    CONCAT('UPDATE arquivo SET tamanho = 700 WHERE id_arquivo = ', @tst_a),
    'Limite de espaco');

CALL tst_executar('T47', 'limite de espaco: reduzir arquivo de 600 para 500 -> permitido',
    CONCAT('UPDATE arquivo SET tamanho = 500 WHERE id_arquivo = ', @tst_a),
    NULL);

UPDATE plano SET espaco_por_usuario = 500 WHERE id_plano = @tst_plano;
CALL tst_executar('T48', 'limite de espaco: acima do limite, alterar so permissoes -> permitido',
    CONCAT('UPDATE arquivo SET permissoes_acesso = ''proprietário e compartilhados'' WHERE id_arquivo = ', @tst_a),
    NULL);

CALL tst_executar('T49', 'limite de espaco: usuario sem instituicao nao tem limite (10 GB)',
    'INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_grande_1.iso'', ''application/x-iso9660-image'', ''somente proprietário'', 10737418240, CURDATE(), ''/tst/g1'', ''https://webdriver.exemplo.test/tst/g1'', 5)',
    NULL);

CALL tst_executar('T50', 'limite de espaco: instituicao sem plano nao tem limite (10 GB)',
    'INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_grande_2.iso'', ''application/x-iso9660-image'', ''somente proprietário'', 10737418240, CURDATE(), ''/tst/g2'', ''https://webdriver.exemplo.test/tst/g2'', 8)',
    NULL);

CALL tst_executar('T51', 'limite de espaco: usuario do plano Basico (5 GB) com +10 GB -> bloqueado',
    'INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES (''tst_grande_3.iso'', ''application/x-iso9660-image'', ''somente proprietário'', 10737418240, CURDATE(), ''/tst/g3'', ''https://webdriver.exemplo.test/tst/g3'', 3)',
    'Limite de espaco');

-- Desfaz os dados de teste
ROLLBACK;

SET @tst_obtido = (SELECT (SELECT COUNT(*) FROM arquivo WHERE nome LIKE 'tst\_%')
          + (SELECT COUNT(*) FROM usuario WHERE login LIKE 'tst.%')
          + (SELECT COUNT(*) FROM plano   WHERE nome LIKE 'tst\_%'));
CALL tst_registrar('T52', 'ROLLBACK: nenhum dado de teste ficou na base', '0', @tst_obtido);

-- Resultado
SELECT teste, descricao, esperado, obtido, status FROM tst_resultado ORDER BY ordem;
SELECT status, COUNT(*) AS quantidade FROM tst_resultado GROUP BY status;

DROP PROCEDURE IF EXISTS tst_registrar;
DROP PROCEDURE IF EXISTS tst_executar;

-- PARTE B: testes manuais com as contas proprias
-- Abrir uma conexao para cada conta (Workbench: nova conexao; Codespace:
-- docker exec -it webdriver-mysql mysql -u <login> -p webdriver).
-- Senhas: README, secao "Credenciais ficticias de teste".
-- Esperados apos executar os scripts 01-03 e 01-05, sem os scripts 04 e 07.
--
-- TB01 ana.souza (PapelUsuario + PapelEmpresa)
--   SELECT * FROM vw_arquivos_usuario;
--     esperado: relatorio_anual_2025.pdf, logo_instituto.png, ata_reuniao_marco.txt; sem colunas id
--   SELECT * FROM vw_historico_operacoes;   -- esperado: operacoes dos 3 arquivos acima
--   SELECT * FROM vw_empresa_usuarios;      -- esperado: ana.souza e bruno.lima
--   SELECT * FROM vw_empresa_arquivos;      -- esperado: 3 arquivos (ana: 2, bruno: 1)
-- TB02 ana.souza: UPDATE pela visao
--   UPDATE vw_arquivos_usuario SET permissoes_acesso = 'somente proprietário'
--   WHERE nome = 'logo_instituto.png';      -- esperado: 1 linha alterada
-- TB03 ana.souza: historico somente leitura
--   DELETE FROM vw_historico_operacoes;     -- esperado: erro 1142 (DELETE negado)
-- TB04 ana.souza: acesso negado as tabelas base
--   SELECT * FROM arquivo;                  -- esperado: erro 1142
--   SELECT * FROM atividades_recentes;      -- esperado: erro 1142
-- TB05 ana.souza: carregar_arquivo
--   CALL carregar_arquivo('plano_acao.pdf', 'application/pdf', 'somente proprietário', 51200,
--        '/armazenamento/u1/plano_acao.pdf', 'https://webdriver.exemplo.test/arquivos/plano_acao',
--        'Versão inicial do plano de ação.');
--     esperado: arquivo_carregado = plano_acao.pdf; aparece nas visoes de arquivos e historico
--   CALL carregar_arquivo('instalador.exe', 'application/octet-stream', 'somente proprietário', 10,
--        '/x', 'https://webdriver.exemplo.test/x', 'x');
--     esperado: erro 1644 Safe_security (nada e gravado)
-- TB06 carla.mendes (somente PapelUsuario)
--   SELECT * FROM vw_arquivos_usuario;      -- esperado: video_campanha.mp4, relatorio_anual_2025.pdf, planilha_doacoes.csv
--   SELECT * FROM vw_empresa_usuarios;      -- esperado: erro 1142 (sem PapelEmpresa)
-- TB07 elisa.rocha (PapelAdm)
--   SELECT * FROM vw_adm_usuarios;          -- esperado: 8 usuarios, sem ids e sem senha_hash
--   SELECT * FROM arquivo;                  -- esperado: permitido (toda a base)
--   SELECT * FROM atividades_recentes;      -- esperado: erro 1142 (somente root)
--   CALL chavear(1);                        -- esperado: erro 1370 (sem EXECUTE)
