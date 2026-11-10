"""Operacoes do Webdriver (CRUD) e regras de acesso.

Regras (decisoes registradas do projeto):
- acesso a um arquivo = proprietario + usuarios com quem foi compartilhado;
- carregar: quem carrega vira o proprietario;
- atualizar e comentar: quem tem acesso;
- remover e compartilhar: so o proprietario; ninguem compartilha consigo mesmo;
- carregar, atualizar e remover gravam a operacao (e a versao) na mesma transacao.
Todos os comandos usam parametros (%s), nunca concatenacao de valores.
"""

from datetime import datetime

import bcrypt

from banco import ErroWebdriver, consultar, executar, transacao


def agora():
    momento = datetime.now().replace(microsecond=0)
    return momento.date(), momento.time()


# ----------------------------------------------------------------------
# usuarios
# ----------------------------------------------------------------------
def buscar_usuario(con, login):
    linhas = consultar(con, "SELECT id_usuario, login FROM usuario WHERE login = %s", (login,))
    if not linhas:
        raise ErroWebdriver(f"Usuario '{login}' nao encontrado.")
    return linhas[0]


def cadastrar_usuario(con, login, email, senha, id_instituicao=None):
    if not login or not email:
        raise ErroWebdriver("Login e e-mail sao obrigatorios.")
    if len(senha) < 8:
        raise ErroWebdriver("A senha deve ter pelo menos 8 caracteres.")
    senha_hash = bcrypt.hashpw(senha.encode(), bcrypt.gensalt(rounds=12)).decode()  # nunca a senha em texto
    data, _ = agora()
    id_usuario, _ = executar(
        con,
        "INSERT INTO usuario (login, senha_hash, data_ingresso, email, id_instituicao) VALUES (%s, %s, %s, %s, %s)",
        (login, senha_hash, data, email, id_instituicao),
    )
    return id_usuario


def listar_instituicoes(con):
    return consultar(con, "SELECT id_instituicao, nome FROM instituicao ORDER BY nome")


def listar_administradores(con):
    return consultar(
        con,
        "SELECT ad.id_administrador, u.login FROM administrador ad "
        "JOIN usuario u ON u.id_usuario = ad.id_usuario ORDER BY u.login",
    )


# ----------------------------------------------------------------------
# arquivos
# ----------------------------------------------------------------------
def listar_arquivos(con, id_usuario, termo=""):
    """Arquivos do usuario e compartilhados com ele, filtrados pelo nome."""
    return consultar(
        con,
        "SELECT a.id_arquivo, a.nome, a.tipo, a.tamanho, a.data_ultima_modificacao, a.id_usuario, "
        "u.login AS proprietario "
        "FROM arquivo a JOIN usuario u ON u.id_usuario = a.id_usuario "
        "WHERE (a.id_usuario = %s OR a.id_arquivo IN "
        "(SELECT id_arquivo FROM compartilhamento WHERE id_compartilhado = %s)) "
        "AND a.nome LIKE %s ORDER BY a.nome",
        (id_usuario, id_usuario, f"%{termo}%"),
    )


def _arquivo(con, id_arquivo):
    linhas = consultar(con, "SELECT id_arquivo, nome, id_usuario FROM arquivo WHERE id_arquivo = %s", (id_arquivo,))
    if not linhas:
        raise ErroWebdriver("Arquivo nao encontrado.")
    return linhas[0]


def _exigir_acesso(con, id_usuario, id_arquivo):
    if not any(a["id_arquivo"] == id_arquivo for a in listar_arquivos(con, id_usuario)):
        raise ErroWebdriver("Voce nao tem acesso a este arquivo.")


def _exigir_dono(con, id_usuario, id_arquivo):
    if _arquivo(con, id_arquivo)["id_usuario"] != id_usuario:
        raise ErroWebdriver("Somente o proprietario pode fazer esta operacao.")


def carregar_arquivo(con, id_usuario, nome, tipo, permissoes, tamanho, localizacao, url, conteudo):
    """Arquivo + operacao 'carregar' + 1a versao, na mesma transacao."""
    if int(tamanho) < 0:
        raise ErroWebdriver("O tamanho nao pode ser negativo.")
    data, hora = agora()
    with transacao(con):
        id_arquivo, _ = executar(
            con,
            "INSERT INTO arquivo (nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, "
            "localizacao, url, id_usuario) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (nome, tipo, permissoes, int(tamanho), data, localizacao, url, id_usuario),
        )
        executar(con, "INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo) "
                      "VALUES ('carregar', %s, %s, %s, %s)", (data, hora, id_usuario, id_arquivo))
        executar(con, "INSERT INTO historico_versionamento (data, hora, operacao, conteudo_mudado, id_usuario, "
                      "id_arquivo) VALUES (%s, %s, 'carregar', %s, %s, %s)",
                 (data, hora, conteudo, id_usuario, id_arquivo))
    return id_arquivo


def atualizar_arquivo(con, id_usuario, id_arquivo, novo_nome, novo_tamanho, descricao):
    """Arquivo + data + operacao 'atualizar' + nova versao, na mesma transacao."""
    _exigir_acesso(con, id_usuario, id_arquivo)
    if int(novo_tamanho) < 0:
        raise ErroWebdriver("O tamanho nao pode ser negativo.")
    data, hora = agora()
    with transacao(con):
        executar(con, "UPDATE arquivo SET nome = %s, tamanho = %s, data_ultima_modificacao = %s "
                      "WHERE id_arquivo = %s", (novo_nome, int(novo_tamanho), data, id_arquivo))
        executar(con, "INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo) "
                      "VALUES ('atualizar', %s, %s, %s, %s)", (data, hora, id_usuario, id_arquivo))
        executar(con, "INSERT INTO historico_versionamento (data, hora, operacao, conteudo_mudado, id_usuario, "
                      "id_arquivo) VALUES (%s, %s, 'atualizar', %s, %s, %s)",
                 (data, hora, descricao, id_usuario, id_arquivo))


def remover_arquivo(con, id_usuario, id_arquivo):
    """Operacao 'remover' + exclusao; os dependentes saem em cascata."""
    _exigir_dono(con, id_usuario, id_arquivo)
    data, hora = agora()
    with transacao(con):
        executar(con, "INSERT INTO operacao_arquivo (tipo_operacao, data, hora, id_usuario, id_arquivo) "
                      "VALUES ('remover', %s, %s, %s, %s)", (data, hora, id_usuario, id_arquivo))
        executar(con, "DELETE FROM arquivo WHERE id_arquivo = %s", (id_arquivo,))


# ----------------------------------------------------------------------
# compartilhamento, comentario e suporte
# ----------------------------------------------------------------------
def compartilhar(con, id_usuario, id_arquivo, login_destino):
    _exigir_dono(con, id_usuario, id_arquivo)
    destino = buscar_usuario(con, login_destino)
    if destino["id_usuario"] == id_usuario:
        raise ErroWebdriver("O proprietario nao compartilha o arquivo consigo mesmo.")
    data, _ = agora()
    executar(con, "INSERT INTO compartilhamento (id_arquivo, id_compartilhado, id_dono, data_compartilhamento) "
                  "VALUES (%s, %s, %s, %s)", (id_arquivo, destino["id_usuario"], id_usuario, data))


def remover_compartilhamento(con, id_usuario, id_arquivo, login_destino):
    _exigir_dono(con, id_usuario, id_arquivo)
    destino = buscar_usuario(con, login_destino)
    _, linhas = executar(con, "DELETE FROM compartilhamento WHERE id_arquivo = %s AND id_compartilhado = %s",
                         (id_arquivo, destino["id_usuario"]))
    if linhas == 0:
        raise ErroWebdriver(f"O arquivo nao estava compartilhado com '{login_destino}'.")


def comentar(con, id_usuario, id_arquivo, texto):
    _exigir_acesso(con, id_usuario, id_arquivo)
    if not texto:
        raise ErroWebdriver("O comentario nao pode ser vazio.")
    data, hora = agora()
    executar(con, "INSERT INTO comentario (conteudo, data, hora, id_usuario, id_arquivo) VALUES (%s, %s, %s, %s, %s)",
             (texto, data, hora, id_usuario, id_arquivo))


def abrir_suporte(con, id_usuario, id_administrador, descricao, id_arquivo=None):
    """Suporte com ou sem arquivo relacionado (o arquivo precisa ser acessivel)."""
    if id_arquivo is not None:
        _exigir_acesso(con, id_usuario, id_arquivo)
    data, hora = agora()
    id_suporte, _ = executar(
        con,
        "INSERT INTO suporte (data, hora, descricao, id_usuario, id_administrador, id_arquivo) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        (data, hora, descricao, id_usuario, id_administrador, id_arquivo),
    )
    return id_suporte


# ----------------------------------------------------------------------
# consultas (somente leitura)
# ----------------------------------------------------------------------
def listar_operacoes(con, id_usuario, id_arquivo):
    _exigir_acesso(con, id_usuario, id_arquivo)
    return consultar(con, "SELECT o.tipo_operacao, o.data, o.hora, u.login AS usuario FROM operacao_arquivo o "
                          "JOIN usuario u ON u.id_usuario = o.id_usuario WHERE o.id_arquivo = %s "
                          "ORDER BY o.data, o.hora", (id_arquivo,))


def listar_versoes(con, id_usuario, id_arquivo):
    _exigir_acesso(con, id_usuario, id_arquivo)
    return consultar(con, "SELECT h.data, h.hora, h.operacao, h.conteudo_mudado, u.login AS usuario "
                          "FROM historico_versionamento h JOIN usuario u ON u.id_usuario = h.id_usuario "
                          "WHERE h.id_arquivo = %s ORDER BY h.data, h.hora", (id_arquivo,))
