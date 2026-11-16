
    -- Webdriver - Parte 2
    -- Triggers do sistema.
    -- Executar após o arquivo 02_funcao_procedures.sql.

    USE webdriver;

    DROP TRIGGER IF EXISTS limite_espaco_insercao;
    DROP TRIGGER IF EXISTS limite_espaco_atualizacao;
    DROP TRIGGER IF EXISTS safe_security;
    DROP TRIGGER IF EXISTS safe_security_atualizacao;
    DROP TRIGGER IF EXISTS registrar_operacao;
    DROP TRIGGER IF EXISTS atualizar_acesso;

    DELIMITER $$

    -- Impede a inserção de arquivos executáveis no drive.
    CREATE TRIGGER safe_security
    BEFORE INSERT ON arquivo
    FOR EACH ROW
    BEGIN
        IF eh_executavel(NEW.nome, NEW.tipo) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Safe_security: arquivos executaveis nao podem ser inseridos no drive.';
        END IF;
    END $$

    -- Verifica se um arquivo está sendo alterado para executável.
    CREATE TRIGGER safe_security_atualizacao
    BEFORE UPDATE ON arquivo
    FOR EACH ROW
    BEGIN
        IF eh_executavel(NEW.nome, NEW.tipo) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Safe_security: um arquivo nao pode ser alterado para executavel.';
        END IF;
    END $$

    -- Verifica o limite de espaço do usuário ao inserir um arquivo.
    CREATE TRIGGER limite_espaco_insercao
    BEFORE INSERT ON arquivo
    FOR EACH ROW
    FOLLOWS safe_security
    BEGIN
        IF excede_espaco(NEW.id_usuario, NULL, NEW.tamanho) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Limite de espaco: os arquivos do proprietario ultrapassariam o espaco por usuario do plano.';
        END IF;
    END $$

    -- Verifica o limite quando o arquivo aumenta ou muda de proprietário.
    CREATE TRIGGER limite_espaco_atualizacao
    BEFORE UPDATE ON arquivo
    FOR EACH ROW
    FOLLOWS safe_security_atualizacao
    BEGIN
        IF (NEW.tamanho > OLD.tamanho OR NEW.id_usuario <> OLD.id_usuario)
        AND excede_espaco(NEW.id_usuario, OLD.id_arquivo, NEW.tamanho) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Limite de espaco: os arquivos do proprietario ultrapassariam o espaco por usuario do plano.';
        END IF;
    END $$

    -- Atualiza o registro de atividades após uma operação no arquivo.
    CREATE TRIGGER registrar_operacao
    AFTER INSERT ON operacao_arquivo
    FOR EACH ROW
    BEGIN
        INSERT INTO atividades_recentes (id_arquivo, ultima_versao, acesso)
        VALUES (NEW.id_arquivo, NEW.data, 'prioritario')
        ON DUPLICATE KEY UPDATE ultima_versao = NEW.data;
    END $$

    -- Atualiza o acesso quando um arquivo é compartilhado.
    CREATE TRIGGER atualizar_acesso
    AFTER INSERT ON compartilhamento
    FOR EACH ROW
    BEGIN
        INSERT INTO atividades_recentes (id_arquivo, ultima_versao, acesso)
        SELECT a.id_arquivo, a.data_ultima_modificacao, 'prioritario'
        FROM arquivo a
        WHERE a.id_arquivo = NEW.id_arquivo
        ON DUPLICATE KEY UPDATE acesso = 'prioritario';
    END $$

    DELIMITER ;
