# Knook Ita

<p align="center">
  <img src="Sources/AppShell/Resources/AppIcon.png" alt="Knook Ita" width="128">
</p>

<p align="center">
  <strong>Fork italiano di knook per pause schermo su macOS, local-first e senza account</strong>
</p>

Knook Ita e un fork di [knook](https://github.com/preetsuthar17/knook) mantenuto in italiano e adattato per un uso piu diretto su macOS. Vive nella barra menu, non mostra icona nel Dock, salva i dati in locale e aiuta a rispettare pause brevi e lunghe durante il lavoro.

Questo fork parte dalla base `v0.3.1` dell'app originale e aggiunge localizzazione italiana, identita app separata, overlay di blocco piu solido, icona macOS corretta, opzioni per sfondo macOS, migrazione completa dai dati del progetto originale e aggiornamenti puntati al fork `manuvarru/knook`.

> Knook Ita e in sviluppo attivo. Alcuni dettagli di distribuzione, firma e notarizzazione possono ancora cambiare.

[Avvio rapido](#avvio-rapido) · [Cosa cambia dal progetto originale](#cosa-cambia-dal-progetto-originale) · [Funzionalita](#funzionalita) · [Privacy e migrazione](#privacy-e-migrazione) · [Sviluppo](#sviluppo) · [Licenza](#licenza)

## Cosa Cambia Dal Progetto Originale

- interfaccia utente tradotta in italiano
- nome app `Knook Ita`
- bundle identifier separato: `io.github.manuvarru.knook-ita`
- dati locali salvati in `~/Library/Application Support/knook-ita`
- migrazione automatica da `knook`, `nook` e `Nook`
- aggiornamenti GitHub e Homebrew puntati al fork `manuvarru/knook`
- app nascosta dal Dock, pensata per vivere solo nella barra menu
- schermata pausa con supporto allo sfondo attuale di macOS e blur opzionale
- preset colore disabilitati quando e attivo lo sfondo del Mac
- overlay di pausa piu coprente e meno aggirabile tramite uscita normale
- icona macOS rigenerata per riempire correttamente il contenitore

## Funzionalita

Knook Ita include:

- app nativa macOS in SwiftUI
- timer per pause brevi e pause lunghe
- promemoria prima della pausa
- overlay a schermo intero per la pausa
- controlli per posticipare, saltare o mettere in pausa, secondo le impostazioni
- fasce orarie di lavoro
- reset automatico dopo inattivita
- avvio al login
- pausa intelligente durante il focus a schermo intero
- statistiche e log attivita locali
- impostazioni JSON versionate e migrate automaticamente

## Avvio Rapido

### Installazione diretta

Scarica l'ultima release da:

```text
https://github.com/manuvarru/knook/releases/latest
```

Sposta `Knook Ita.app` in `/Applications` e avviala. L'app comparira nella barra menu, non nel Dock.

### Homebrew

```bash
brew tap manuvarru/tap
brew install --cask knook
```

Aggiornamento:

```bash
brew update
brew upgrade --cask knook
```

Quando viene pubblicata una nuova release nel fork, Knook Ita mostra un avviso di aggiornamento nel menu. Se Homebrew e disponibile, l'aggiornamento usa il tap `manuvarru/tap`; altrimenti apre la pagina release del fork.

## Privacy E Migrazione

Knook Ita non usa account, server o cloud sync. Le impostazioni, le statistiche e il log attivita restano sul Mac.

Nuovo percorso dati:

```text
~/Library/Application Support/knook-ita
```

Al primo avvio, se i nuovi dati non esistono, l'app importa automaticamente dai vecchi percorsi:

```text
~/Library/Application Support/knook
~/Library/Application Support/nook
~/Library/Application Support/Nook
```

I vecchi file non vengono cancellati durante la migrazione.

## Sviluppo

Requisiti:

- macOS 13 o superiore
- Swift toolchain recente
- Xcode completo per build e test locali

Build:

```bash
swift build
```

Esecuzione:

```bash
swift run
```

Test:

```bash
swift test
```

Build Xcode:

```bash
xcodebuild -project knook_ita.xcodeproj -scheme knook -configuration Debug build
```

Per dettagli aggiuntivi sul workflow locale, vedi [docs/local-development.md](docs/local-development.md).

## Struttura Repository

- `Sources/AppShell/`: app macOS, menu bar, finestre e coordinamento UI
- `Sources/Core/`: scheduler, modelli, persistenza e logica condivisa
- `Tests/`: test di Core e AppShell
- `docs/`: documentazione di sviluppo, installazione e release
- `packaging/`: packaging macOS, cask Homebrew e script release

## Licenza

Knook Ita mantiene la licenza [MIT](LICENSE) del progetto originale.
