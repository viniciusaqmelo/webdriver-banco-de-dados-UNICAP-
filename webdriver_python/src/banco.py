"""Conexao com o MySQL.

As credenciais ficam no arquivo .env (nunca no codigo). O .env esta no
.gitignore; o modelo sem senha e o .env.example.
"""

import os
from contextlib import contextmanager

import mysql.connector
from dotenv import load_dotenv

load_dotenv()


class ErroWebdriver(Exception):
    """Erro com mensagem pronta para mostrar ao usuario."""


# Codigos de erro do MySQL -> mensagem clara
MENSAGENS = {
    1045: "Usuario ou senha do MySQL invalidos (confira o .env).",
    1048: "Campo obrigatorio nao informado.",
    1049: "A base webdriver nao existe (execute os scripts sql/parte_1).",
    1062: "Registro duplicado (login, e-mail ou compartilhamento ja existente).",
    1451: "Operacao recusada: o registro esta sendo usado por outros dados.",
    1452: "Referencia invalida: o registro relacionado nao existe.",
    2003: "Nao foi possivel conectar ao MySQL (confira se o servidor esta ligado).",
    3819: "Valor recusado por uma regra (CHECK) do banco.",
}


def mensagem_erro(erro) -> str:
    codigo = getattr(erro, "errno", None)
    if codigo == 1644:  # SIGNAL dos triggers da Parte 2 (Safe_security, limite de espaco)
        return f"Operacao recusada pelo banco: {erro.msg}"
    return MENSAGENS.get(codigo, f"Erro no banco de dados: {erro}")


def conectar():
    """Abre a conexao usando os dados do .env."""
    try:
        return mysql.connector.connect(
            host=os.getenv("DB_HOST", "127.0.0.1"),
            port=int(os.getenv("DB_PORT", "3306")),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME", "webdriver"),
            autocommit=True,
        )
    except mysql.connector.Error as erro:
        raise ErroWebdriver(mensagem_erro(erro)) from None


@contextmanager
def transacao(con):
    """START TRANSACTION ... COMMIT; ROLLBACK se qualquer passo falhar."""
    con.start_transaction()
    try:
        yield
        con.commit()
    except Exception:
        con.rollback()
        raise


def executar(con, sql, parametros=()):
    """INSERT/UPDATE/DELETE parametrizado. Devolve (id gerado, linhas afetadas)."""
    cursor = con.cursor()
    try:
        cursor.execute(sql, parametros)
        return cursor.lastrowid, cursor.rowcount
    except mysql.connector.Error as erro:
        raise ErroWebdriver(mensagem_erro(erro)) from None
    finally:
        cursor.close()


def consultar(con, sql, parametros=()):
    """SELECT parametrizado. Devolve uma lista de dicionarios."""
    cursor = con.cursor(dictionary=True)
    try:
        cursor.execute(sql, parametros)
        return cursor.fetchall()
    except mysql.connector.Error as erro:
        raise ErroWebdriver(mensagem_erro(erro)) from None
    finally:
        cursor.close()
