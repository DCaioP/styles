//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.island

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Bar { modelData: perScreen.modelData }
            IslandWindow { modelData: perScreen.modelData }
        }
    }

    Launcher {}
}
