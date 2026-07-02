# JetBrains IDEs Aliases
# Similar ao "code ." do VS Code

# Aliases para abrir projetos no diretório atual
alias pycharm.="pycharm ."
alias webstorm.="webstorm ."
alias idea.="idea ."
alias datagrip.="datagrip ."
alias goland.="goland ."
alias clion.="clion ."
alias rider.="rider ."

# Aliases mais curtos (opcionais)
alias py.="pycharm ."
alias ws.="webstorm ."
alias ij.="idea ."
alias dg.="datagrip ."
alias go.="goland ."
alias cl.="clion ."
alias rd.="rider ."

# Função para abrir múltiplos projetos
open_in_jetbrains() {
    local ide=$1
    shift
    if [ $# -eq 0 ]; then
        $ide .
    else
        for dir in "$@"; do
            $ide "$dir" &
        done
    fi
}

# Aliases para a função
alias pycharm_multi="open_in_jetbrains pycharm"
alias webstorm_multi="open_in_jetbrains webstorm"
alias idea_multi="open_in_jetbrains idea"
