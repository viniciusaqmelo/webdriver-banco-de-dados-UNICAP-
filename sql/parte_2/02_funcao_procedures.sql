
USE webdriver;

DROP FUNCTION IF EXISTS mais_de_100_dias;
DROP PROCEDURE IF EXISTS verificar_atividades;
DROP PROCEDURE IF EXISTS conta_usuarios;
DROP PROCEDURE IF EXISTS chavear;
DROP PROCEDURE IF EXISTS remover_acessos;
DROP FUNCTION IF EXISTS eh_executavel;
DROP FUNCTION IF EXISTS excede_espaco;
DROP PROCEDURE IF EXISTS carregar_arquivo;

DELIMITER $$


CREATE FUNCTION mais_de_100_dias(p_id_arquivo INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_ultima_alteracao DATE;

    SELECT data_ultima_modificacao INTO v_ultima_alteracao
    FROM arquivo
    WHERE id_arquivo = p_id_arquivo;

    RETURN DATEDIFF(CURDATE(), v_ultima_alteracao) > 100;
END $$


CREATE PROCEDURE verificar_atividades()
BEGIN
    UPDATE atividades_recentes
    SET ultima_versao = CURDATE()
    WHERE id_arquivo > 0;   -- todas as linhas (filtro por chave: safe updates)

    SELECT ROW_COUNT() AS linhas_atualizadas;
END $$


CREATE PROCEDURE conta_usuarios(IN p_id_arquivo INT, OUT p_total INT)
BEGIN
    SELECT COUNT(*) INTO p_total
    FROM (
        SELECT id_usuario AS id_usuario
        FROM arquivo
        WHERE id_arquivo = p_id_arquivo
        UNION                                   
        SELECT id_compartilhado
        FROM compartilhamento
        WHERE id_arquivo = p_id_arquivo
    ) AS usuarios_com_acesso;

    SELECT p_total AS total_usuarios;
END $$


CREATE PROCEDURE chavear(IN p_id_arquivo INT)
BEGIN
    DECLARE v_acesso VARCHAR(15);

    SELECT acesso INTO v_acesso
    FROM atividades_recentes
    WHERE id_arquivo = p_id_arquivo;

    IF v_acesso = 'prioritario' THEN
        UPDATE atividades_recentes SET acesso = 'nao_prioritario' WHERE id_arquivo = p_id_arquivo;
    ELSEIF v_acesso = 'nao_prioritario' THEN
        UPDATE atividades_recentes SET acesso = 'prioritario' WHERE id_arquivo = p_id_arquivo;
    END IF;

    SELECT id_arquivo, acesso FROM atividades_recentes WHERE id_arquivo = p_id_arquivo;
END $$


CREATE PROCEDURE remover_acessos(IN p_id_arquivo INT)
BEGIN
    DELETE FROM compartilhamento
    WHERE id_arquivo = p_id_arquivo;

    SELECT ROW_COUNT() AS acessos_removidos;
END $$


CREATE FUNCTION eh_executavel(p_nome VARCHAR(255), p_tipo VARCHAR(100))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    RETURN LOWER(p_tipo) IN ('application/x-msdownload',
                             'application/x-msdos-program',
                             'application/x-executable',
                             'application/vnd.microsoft.portable-executable',
                             'application/x-msi',
                             'application/x-sh',
                             'application/x-bat')
        OR (LOCATE('.', p_nome) > 0
            AND LOWER(SUBSTRING_INDEX(p_nome, '.', -1)) IN
                ('exe', 'bat', 'cmd', 'com', 'msi', 'sh', 'bin', 'scr', 'ps1', 'vbs', 'jar', 'apk'));
END $$


CREATE FUNCTION excede_espaco(p_id_usuario INT, p_id_arquivo_ignorado INT, p_tamanho_novo BIGINT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_limite  BIGINT DEFAULT NULL;
    DECLARE v_ocupado BIGINT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_limite = NULL;

    SELECT p.espaco_por_usuario INTO v_limite
    FROM usuario u
    JOIN instituicao i ON i.id_instituicao = u.id_instituicao
    JOIN plano p       ON p.id_plano = i.id_plano
    WHERE u.id_usuario = p_id_usuario;

    IF v_limite IS NULL THEN
        RETURN FALSE;                           -- sem instituicao ou sem plano
    END IF;

    SELECT COALESCE(SUM(a.tamanho), 0) INTO v_ocupado
    FROM arquivo a
    WHERE a.id_usuario = p_id_usuario
      AND a.id_arquivo <> COALESCE(p_id_arquivo_ignorado, 0);

    RETURN v_ocupado + p_tamanho_novo > v_limite;
END $$


CREATE PROCEDURE carregar_arquivo(
    IN p_nome               VARCHAR(255),
    IN p_tipo               VARCHAR(100),
    IN p_permissoes_acesso  VARCHAR(100),
    IN p_tamanho            BIGINT,
    IN p_localizacao        VARCHAR(255),
    IN p_url                VARCHAR(500),
    IN p_conteudo_inicial   TEXT)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_id_arquivo INT;

    -- 1. Identifica o proprietario pela conta conectada (fora da transacao)
    SELECT u.id_usuario INTO v_id_usuario
    FROM usuario u
    WHERE u.login = SUBSTRING_INDEX(USER(), '@', 1);

    IF v_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'carregar_arquivo: a conta conectada nao corresponde a um usuario da plataforma.';
    END IF;

    -- 2. Transacao: arquivo + operacao + 1a versao (RN21)
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;                           -- devolve o erro original
        END;

        START TRANSACTION;

        INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao,
                             localizacao, url, id_usuario)
        VALUES (p_nome, p_tipo, p_permissoes_acesso, p_tamanho, CURDATE(),
                p_localizacao, p_url, v_id_usuario);
        SET v_id_arquivo = LAST_INSERT_ID();

        INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo)
        VALUES ('carregar', CURDATE(), CURTIME(), v_id_usuario, v_id_arquivo);

        INSERT INTO historico_versionamento (data, hora, operacao, conteudo_mudado, id_usuario, id_arquivo)
        VALUES (CURDATE(), CURTIME(), 'carregar', p_conteudo_inicial, v_id_usuario, v_id_arquivo);

        COMMIT;
    END;

    -- Retorno sem id (ids ocultos para o usuario)
    SELECT p_nome AS arquivo_carregado, 'carregar' AS operacao_registrada;
END $$

DELIMITER ;
