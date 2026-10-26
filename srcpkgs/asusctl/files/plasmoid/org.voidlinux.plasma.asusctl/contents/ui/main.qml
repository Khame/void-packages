import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ─────────────────────────────────────────────────────────────
    // UWAGA / TODO: dokładny format wyjścia "asusctl profile -l" i
    // "asusctl -s" (show-supported) nie był zweryfikowany na Twoim
    // sprzęcie. Parsowanie poniżej (parseProfileOutput) jest zgadywane
    // na podstawie typowego stylu CLI Rusta (linie postaci
    // "  Balanced (active)" albo podobnie). Odpal ręcznie
    // `asusctl profile -l` w terminalu, wklej mi wynik, dopasuję regex.
    // Do tego czasu widget i tak DZIAŁA do ustawiania profili/limitu/
    // podświetlenia — tylko podświetlenie aktywnego profilu może się
    // nie zaznaczać poprawnie dopóki nie poprawimy parsera.
    // ─────────────────────────────────────────────────────────────

    property string currentProfile: "?"
    property int chargeLimit: 80
    property bool chargeLimitKnown: false

    Plasmoid.icon: "battery-060"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        function run(cmd, onDone) {
            if (connectedSources.indexOf(cmd) !== -1) {
                return; // już w locie
            }
            if (onDone) {
                root._pending[cmd] = onDone;
            }
            connectSource(cmd);
        }

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const cb = root._pending[sourceName];
            delete root._pending[sourceName];
            if (cb) {
                cb(data["stdout"] || "", data["stderr"] || "", data["exit code"]);
            }
        }
    }

    // mapa callbacków per-komenda (JS object, nie QML property bo mapa dowolnych kluczy)
    property var _pending: ({})

    function refreshProfile() {
        exec.run("asusctl profile -l", function (stdout, stderr, code) {
            if (code !== 0) {
                root.currentProfile = "błąd: " + stderr.trim();
                return;
            }
            root.currentProfile = parseActiveProfile(stdout);
        });
    }

    function parseActiveProfile(stdout) {
        // Szuka linii zawierającej "active"/"*" obok nazwy profilu.
        // Dopasuj to po zobaczeniu prawdziwego outputu.
        const lines = stdout.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const l = lines[i];
            if (/active/i.test(l) || l.indexOf("*") !== -1) {
                const m = l.match(/(Balanced|Performance|Quiet)/i);
                if (m) return m[1];
            }
        }
        // fallback: pierwsza znaleziona nazwa profilu w ogóle
        const m2 = stdout.match(/(Balanced|Performance|Quiet)/i);
        return m2 ? m2[1] : "nieznany";
    }

    function setProfile(name) {
        exec.run("asusctl profile -P " + name, function (stdout, stderr, code) {
            refreshProfile();
        });
    }

    function cycleProfile() {
        exec.run("asusctl profile -n", function () { refreshProfile(); });
    }

    function setChargeLimit(val) {
        exec.run("asusctl -c " + val, function (stdout, stderr, code) {
            if (code === 0) root.chargeLimitKnown = true;
        });
    }

    function setKbdBright(level) {
        // level: off|low|med|high
        exec.run("asusctl -k " + level, function () {});
    }

    function ledModeNext() {
        exec.run("asusctl led-mode -n", function () {});
    }

    function ledModePrev() {
        exec.run("asusctl led-mode -p", function () {});
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refreshProfile()
    }
    Component.onCompleted: root.refreshProfile()

    // ── reprezentacja skrócona (ikona w tacce) ──
    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            source: root.Plasmoid.icon
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── pełna reprezentacja (popup) ──
    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.margins: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: "Profil zasilania: " + root.currentProfile
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Button {
                text: "Cichy"
                onClicked: root.setProfile("Quiet")
            }
            PlasmaComponents3.Button {
                text: "Zbalansowany"
                onClicked: root.setProfile("Balanced")
            }
            PlasmaComponents3.Button {
                text: "Wydajność"
                onClicked: root.setProfile("Performance")
            }
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            text: "Cykl profili (jak Fn+F5)"
            onClicked: root.cycleProfile()
        }

        PlasmaCore.SvgItem {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            elementId: "horizontal-line"
            svg: PlasmaCore.Svg { imagePath: "widgets/line" }
        }

        PlasmaComponents3.Label {
            text: "Limit ładowania baterii"
        }
        RowLayout {
            Layout.fillWidth: true
            QQC2.Slider {
                id: chargeSlider
                Layout.fillWidth: true
                from: 20
                to: 100
                stepSize: 5
                value: root.chargeLimit
                onPressedChanged: {
                    if (!pressed) {
                        root.chargeLimit = Math.round(value);
                        root.setChargeLimit(root.chargeLimit);
                    }
                }
            }
            PlasmaComponents3.Label {
                text: Math.round(chargeSlider.value) + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
            }
        }
        PlasmaComponents3.Label {
            visible: !root.chargeLimitKnown
            opacity: 0.7
            font.pixelSize: Kirigami.Units.smallSpacing * 6
            text: "Wartość początkowa to domyślne 80% — przesuń suwak, żeby ustawić realny limit."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        PlasmaCore.SvgItem {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            elementId: "horizontal-line"
            svg: PlasmaCore.Svg { imagePath: "widgets/line" }
        }

        PlasmaComponents3.Label {
            text: "Podświetlenie klawiatury"
        }
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Button { text: "Wył."; onClicked: root.setKbdBright("off") }
            PlasmaComponents3.Button { text: "Nisko"; onClicked: root.setKbdBright("low") }
            PlasmaComponents3.Button { text: "Średnio"; onClicked: root.setKbdBright("med") }
            PlasmaComponents3.Button { text: "Wysoko"; onClicked: root.setKbdBright("high") }
        }

        PlasmaComponents3.Label {
            text: "Tryb Aura (RGB)"
        }
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Button {
                text: "◀ Poprzedni"
                Layout.fillWidth: true
                onClicked: root.ledModePrev()
            }
            PlasmaComponents3.Button {
                text: "Następny ▶"
                Layout.fillWidth: true
                onClicked: root.ledModeNext()
            }
        }
    }
}
