TARGET = Oxidane

CONFIG += sailfishapp_qml

OTHER_FILES += qml/Oxidane.qml \
    qml/cover/CoverPage.qml \
    qml/pages/FirstPage.qml \
    qml/pages/SecondPage.qml \
    rpm/Oxidane.changes.in \
    rpm/Oxidane.spec \
    translations/*.ts \
    Oxidane.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 256x256


CONFIG += sailfishapp_i18n


TRANSLATIONS += translations/Oxidane.ts

DISTFILES += \
    qml/pages/button.py
