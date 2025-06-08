# Style – VSCode & JetBrains

Este repositório centraliza os arquivos que uso para customizar o **Visual Studio Code** e as IDEs da **JetBrains**. A ideia é manter consistência visual no meu ambiente de trabalho, com temas, estilos e ajustes que tornam o dia a dia mais fluido e menos poluído e lindão.

---

## Estrutura do repositório

``` Bash

├── vscode/
│   ├── custom.css        # Estilos personalizados para o VSCode
│   └── ...
├── jetbrains/
│   ├── tema.icls         # Temas customizados para JetBrains
│   └── ...
└── README.md

```

## Rodando o VSCode com suporte a estilos personalizados no Linux

Para aplicar estilos customizados no VSCode (por exemplo, via extensão _Custom CSS and JS Loader_), é necessário rodar o VSCode com permissões elevadas e acesso ao ambiente gráfico. No Arch Linux, uso o seguinte comando:

``` zsh
sudo --preserve-env=DISPLAY,WAYLAND_DISPLAY,XDG_RUNTIME_DIR,DBUS_SESSION_BUS_ADDRESS,XAUTHORITY \
     code --no-sandbox --user-data-dir=/tmp/vscode-root

```

Isso evita os erros comuns de sandbox e permissões ao tentar injetar CSS ou JS no VSCode.
Uso com cautela: é só pra configurar estilo, não pra codar como root.

---

## Aplicando temas nas IDEs JetBrains

1. Copie os arquivos `.icls` para o diretório de temas da sua IDE:

``` zsh
 ~/.config/JetBrains/<NomeDaIDE>/colors/

```

1. Depois, é só ir em:
    `File > Settings > Editor > Color Scheme`
    e selecionar o tema.

---

## Observação

Esse repositório é pessoal. Se você caiu aqui por acaso e gostou de algo, pode usar à vontade, mas lembre-se: gosto visual é algo muito específico. O que funciona pra mim pode te incomodar.
