"""Webdriver - menu de linha de comando.

Execute a partir da raiz do projeto:  python src/main.py
Os arquivos sao escolhidos pelo numero da lista (os ids nao aparecem).
"""

import crud
from banco import ErroWebdriver, conectar


def escolher(itens, rotulo):
    """Mostra uma lista numerada e devolve o item escolhido (ou None)."""
    if not itens:
        print("Nenhum registro disponivel.")
        return None
    for numero, item in enumerate(itens, start=1):
        print(f"  {numero}. {rotulo(item)}")
    opcao = input("Numero (0 para cancelar): ").strip()
    if not opcao.isdigit() or not 1 <= int(opcao) <= len(itens):
        return None
    return itens[int(opcao) - 1]


def descrever_arquivo(a):
    return f"{a['nome']} ({a['tipo']}, {a['tamanho']} bytes) - proprietario: {a['proprietario']}"


def escolher_arquivo(con, usuario, somente_meus=False):
    arquivos = crud.listar_arquivos(con, usuario["id_usuario"])
    if somente_meus:
        arquivos = [a for a in arquivos if a["id_usuario"] == usuario["id_usuario"]]
    arquivo = escolher(arquivos, descrever_arquivo)
    return arquivo["id_arquivo"] if arquivo else None


def mostrar(linhas):
    if not linhas:
        print("  (nenhum registro)")
    for linha in linhas:
        print("  " + " | ".join(str(valor) for valor in linha.values()))


MENU = """
=========== Webdriver ===========
Usuario atuante: {usuario}
 1. Identificar usuario (login)
 2. Cadastrar usuario
 3. Carregar arquivo
 4. Buscar arquivos
 5. Atualizar arquivo
 6. Remover arquivo
 7. Compartilhar arquivo
 8. Remover compartilhamento
 9. Comentar arquivo
10. Abrir suporte
11. Ver operacoes de um arquivo
12. Ver historico de versoes de um arquivo
 0. Sair"""


def main():
    try:
        con = conectar()
    except ErroWebdriver as erro:
        print(f"Erro: {erro}")
        return
    print("Conectado ao MySQL.")
    usuario = None

    while True:
        print(MENU.format(usuario=usuario["login"] if usuario else "(nenhum)"))
        opcao = input("Opcao: ").strip()
        if opcao == "0":
            print("Ate logo.")
            break
        if opcao not in ("1", "2") and usuario is None:
            print("Identifique primeiro o usuario (opcao 1).")
            continue
        try:
            if opcao == "1":
                usuario = crud.buscar_usuario(con, input("Login: ").strip())
                print(f"Operando como {usuario['login']}.")

            elif opcao == "2":
                login = input("Login: ").strip()
                email = input("E-mail: ").strip()
                senha = input("Senha (min. 8 caracteres): ")
                instituicao = escolher(crud.listar_instituicoes(con), lambda i: i["nome"])
                crud.cadastrar_usuario(con, login, email, senha,
                                       instituicao["id_instituicao"] if instituicao else None)
                print("Usuario cadastrado (senha guardada como hash bcrypt).")

            elif opcao == "3":
                nome = input("Nome do arquivo: ").strip()
                crud.carregar_arquivo(
                    con, usuario["id_usuario"], nome,
                    input("Tipo (ex.: application/pdf): ").strip(),
                    input("Permissoes de acesso: ").strip() or "somente proprietário",
                    input("Tamanho em bytes: ").strip(),
                    f"/armazenamento/{usuario['login']}/{nome}",
                    input("URL: ").strip(),
                    input("Conteudo da versao inicial: ").strip(),
                )
                print("Arquivo carregado (arquivo, operacao e versao na mesma transacao).")

            elif opcao == "4":
                arquivos = crud.listar_arquivos(con, usuario["id_usuario"], input("Trecho do nome (Enter = todos): "))
                for a in arquivos:
                    print("  " + descrever_arquivo(a))
                if not arquivos:
                    print("  (nenhum arquivo)")

            elif opcao == "5":
                id_arquivo = escolher_arquivo(con, usuario)
                if id_arquivo:
                    crud.atualizar_arquivo(con, usuario["id_usuario"], id_arquivo,
                                           input("Novo nome: ").strip(), input("Novo tamanho em bytes: ").strip(),
                                           input("Descricao da mudanca: ").strip())
                    print("Arquivo atualizado (nova versao registrada).")

            elif opcao == "6":
                id_arquivo = escolher_arquivo(con, usuario, somente_meus=True)
                if id_arquivo and input("Confirma a remocao? (s/n): ").strip().lower() == "s":
                    crud.remover_arquivo(con, usuario["id_usuario"], id_arquivo)
                    print("Arquivo removido.")

            elif opcao in ("7", "8"):
                id_arquivo = escolher_arquivo(con, usuario, somente_meus=True)
                if id_arquivo:
                    login = input("Login do outro usuario: ").strip()
                    if opcao == "7":
                        crud.compartilhar(con, usuario["id_usuario"], id_arquivo, login)
                        print("Arquivo compartilhado.")
                    else:
                        crud.remover_compartilhamento(con, usuario["id_usuario"], id_arquivo, login)
                        print("Compartilhamento removido.")

            elif opcao == "9":
                id_arquivo = escolher_arquivo(con, usuario)
                if id_arquivo:
                    crud.comentar(con, usuario["id_usuario"], id_arquivo, input("Comentario: ").strip())
                    print("Comentario registrado.")

            elif opcao == "10":
                descricao = input("Descricao do problema: ").strip()
                adm = escolher(crud.listar_administradores(con), lambda a: a["login"])
                if adm:
                    id_arquivo = None
                    if input("Relacionar um arquivo? (s/n): ").strip().lower() == "s":
                        id_arquivo = escolher_arquivo(con, usuario)
                    crud.abrir_suporte(con, usuario["id_usuario"], adm["id_administrador"], descricao, id_arquivo)
                    print("Suporte registrado.")

            elif opcao in ("11", "12"):
                id_arquivo = escolher_arquivo(con, usuario)
                if id_arquivo:
                    listar = crud.listar_operacoes if opcao == "11" else crud.listar_versoes
                    mostrar(listar(con, usuario["id_usuario"], id_arquivo))

            else:
                print("Opcao invalida.")
        except ErroWebdriver as erro:
            print(f"Erro: {erro}")
        except ValueError:
            print("Erro: informe um numero valido.")

    con.close()


if __name__ == "__main__":
    main()
