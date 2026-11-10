"""Testes do Webdriver no MySQL real.

Pre-requisito: MySQL no ar, .env preenchido e os scripts sql/parte_1/01, 02 e 03
executados. Rode a partir da raiz do projeto:  pytest -v
Os testes criam registros com nomes "teste_pytest..." e os apagam no final.
"""

import subprocess
import sys
from pathlib import Path

import bcrypt
import pytest

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "src"))

import crud  # noqa: E402
from banco import ErroWebdriver, conectar, consultar, executar  # noqa: E402

ARQUIVO = dict(tipo="application/pdf", permissoes="somente proprietário", tamanho=1024,
               localizacao="/armazenamento/teste_pytest", url="https://webdriver.exemplo.test/teste_pytest",
               conteudo="Versão inicial (teste).")


def limpar(con):
    executar(con, "DELETE FROM suporte WHERE descricao LIKE 'teste_pytest%'")
    executar(con, "DELETE FROM arquivo WHERE nome LIKE 'teste_pytest%'")   # dependentes saem em cascata
    executar(con, "DELETE FROM usuario WHERE login = 'teste.pytest'")


@pytest.fixture
def con():
    conexao = conectar()
    limpar(conexao)
    yield conexao
    limpar(conexao)
    conexao.close()


def usuario(con, login):
    return crud.buscar_usuario(con, login)["id_usuario"]


def contar(con, tabela, id_arquivo):
    return consultar(con, f"SELECT COUNT(*) AS n FROM {tabela} WHERE id_arquivo = %s", (id_arquivo,))[0]["n"]


# ----------------------------------------------------------------------
def test_conexao_e_dados_de_teste(con):
    """Conecta pelo .env e encontra os usuarios do 03_insert_dados_teste.sql."""
    assert consultar(con, "SELECT COUNT(*) AS n FROM usuario")[0]["n"] >= 8


def test_cadastrar_usuario_guarda_hash_bcrypt(con):
    crud.cadastrar_usuario(con, "teste.pytest", "teste.pytest@exemplo.test", "Senha2026")
    senha_hash = consultar(con, "SELECT senha_hash FROM usuario WHERE login = 'teste.pytest'")[0]["senha_hash"]
    assert senha_hash != "Senha2026"
    assert bcrypt.checkpw(b"Senha2026", senha_hash.encode())


def test_login_duplicado_e_recusado(con):
    with pytest.raises(ErroWebdriver):
        crud.cadastrar_usuario(con, "ana.souza", "outro@exemplo.test", "Senha2026")


def test_carregar_grava_arquivo_operacao_e_versao(con):
    diego = usuario(con, "diego.alves")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_carregar.pdf", **ARQUIVO)
    assert contar(con, "arquivo", id_arquivo) == 1
    assert contar(con, "operacao_arquivo", id_arquivo) == 1
    assert contar(con, "historico_versionamento", id_arquivo) == 1


def test_carregar_desfaz_tudo_se_um_passo_falhar(con):
    """A versao sem conteudo falha no 3o INSERT: o arquivo e a operacao sao desfeitos (ROLLBACK)."""
    diego = usuario(con, "diego.alves")
    with pytest.raises(ErroWebdriver):
        crud.carregar_arquivo(con, diego, "teste_pytest_rollback.pdf", **{**ARQUIVO, "conteudo": None})
    assert consultar(con, "SELECT COUNT(*) AS n FROM arquivo WHERE nome = 'teste_pytest_rollback.pdf'")[0]["n"] == 0


def test_buscar_mostra_proprios_e_compartilhados(con):
    diego, ana = usuario(con, "diego.alves"), usuario(con, "ana.souza")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_busca.pdf", **ARQUIVO)
    assert id_arquivo not in [a["id_arquivo"] for a in crud.listar_arquivos(con, ana)]
    crud.compartilhar(con, diego, id_arquivo, "ana.souza")
    assert id_arquivo in [a["id_arquivo"] for a in crud.listar_arquivos(con, ana, "teste_pytest")]


def test_atualizar_por_usuario_compartilhado(con):
    diego, ana = usuario(con, "diego.alves"), usuario(con, "ana.souza")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_atualizar.pdf", **ARQUIVO)
    crud.compartilhar(con, diego, id_arquivo, "ana.souza")
    crud.atualizar_arquivo(con, ana, id_arquivo, "teste_pytest_atualizado.pdf", 2048, "Segunda versão.")
    assert contar(con, "historico_versionamento", id_arquivo) == 2
    assert consultar(con, "SELECT nome FROM arquivo WHERE id_arquivo = %s", (id_arquivo,))[0]["nome"] \
        == "teste_pytest_atualizado.pdf"


def test_sem_acesso_nao_atualiza_nem_comenta(con):
    diego, carla = usuario(con, "diego.alves"), usuario(con, "carla.mendes")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_acesso.pdf", **ARQUIVO)
    with pytest.raises(ErroWebdriver):
        crud.atualizar_arquivo(con, carla, id_arquivo, "x.pdf", 1, "tentativa")
    with pytest.raises(ErroWebdriver):
        crud.comentar(con, carla, id_arquivo, "sem acesso")


def test_regras_de_compartilhamento(con):
    diego, ana = usuario(con, "diego.alves"), usuario(con, "ana.souza")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_compartilhar.pdf", **ARQUIVO)
    with pytest.raises(ErroWebdriver):
        crud.compartilhar(con, diego, id_arquivo, "diego.alves")      # consigo mesmo
    with pytest.raises(ErroWebdriver):
        crud.compartilhar(con, ana, id_arquivo, "carla.mendes")       # quem compartilha nao e o dono
    crud.compartilhar(con, diego, id_arquivo, "ana.souza")
    crud.remover_compartilhamento(con, diego, id_arquivo, "ana.souza")
    assert contar(con, "compartilhamento", id_arquivo) == 0


def test_remover_somente_pelo_dono_e_em_cascata(con):
    diego, ana = usuario(con, "diego.alves"), usuario(con, "ana.souza")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_remover.pdf", **ARQUIVO)
    crud.compartilhar(con, diego, id_arquivo, "ana.souza")
    crud.comentar(con, ana, id_arquivo, "Comentário de teste.")
    with pytest.raises(ErroWebdriver):
        crud.remover_arquivo(con, ana, id_arquivo)                    # ana so tem compartilhamento
    crud.remover_arquivo(con, diego, id_arquivo)
    for tabela in ("arquivo", "compartilhamento", "comentario", "operacao_arquivo", "historico_versionamento"):
        assert contar(con, tabela, id_arquivo) == 0, tabela


def test_suporte_com_e_sem_arquivo(con):
    diego = usuario(con, "diego.alves")
    adm = crud.listar_administradores(con)[0]["id_administrador"]
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_suporte.pdf", **ARQUIVO)
    crud.abrir_suporte(con, diego, adm, "teste_pytest sem arquivo")
    crud.abrir_suporte(con, diego, adm, "teste_pytest com arquivo", id_arquivo)
    linhas = consultar(con, "SELECT descricao, id_arquivo FROM suporte WHERE descricao LIKE 'teste_pytest%' "
                            "ORDER BY descricao")
    assert [l["id_arquivo"] for l in linhas] == [id_arquivo, None]


def test_operacoes_e_versoes_do_arquivo(con):
    diego = usuario(con, "diego.alves")
    id_arquivo = crud.carregar_arquivo(con, diego, "teste_pytest_historico.pdf", **ARQUIVO)
    assert [o["tipo_operacao"] for o in crud.listar_operacoes(con, diego, id_arquivo)] == ["carregar"]
    assert [v["operacao"] for v in crud.listar_versoes(con, diego, id_arquivo)] == ["carregar"]


def test_menu_de_ponta_a_ponta():
    """Roda o main.py como o usuario: identifica, carrega, busca e sai."""
    entradas = "\n".join([
        "1", "diego.alves",
        "3", "teste_pytest_menu.pdf", "application/pdf", "", "1024", "https://webdriver.exemplo.test/x", "v1",
        "4", "teste_pytest",
        "1", "ninguem",
        "0",
    ]) + "\n"
    saida = subprocess.run([sys.executable, str(RAIZ / "src" / "main.py")], input=entradas,
                           capture_output=True, text=True, cwd=RAIZ, timeout=60).stdout
    con = conectar()
    limpar(con)
    con.close()
    assert "Operando como diego.alves." in saida
    assert "Arquivo carregado" in saida
    assert "teste_pytest_menu.pdf" in saida
    assert "Erro: Usuario 'ninguem' nao encontrado." in saida      # erro tratado, menu continua
    assert "Ate logo." in saida
