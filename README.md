# emuK

emuK trasforma un tablet Android in una tastiera remota per Windows tramite rete locale.

Nota: una web app non puo presentarsi a Windows come una vera tastiera Bluetooth HID. emuK usa invece un companion Windows che riceve i comandi dalla web app e li invia al sistema operativo come input tastiera.

## Avvio rapido

1. Su Windows, apri questa cartella.
2. Avvia `start-emuk.bat`.
3. Sul tablet Android, apri l'indirizzo mostrato nel terminale, per esempio `http://192.168.1.20:8765`.
4. Tocca i tasti o scrivi nel campo di testo e premi `Invia testo`.

Windows e tablet devono essere sulla stessa rete Wi-Fi.

## Requisiti

- Windows.
- Python 3 installato e disponibile come `py` o `python`.
- Firewall Windows configurato per consentire Python sulle reti private, se richiesto.

## Funzioni

- Tastiera touch con lettere, numeri, funzione, frecce e tasti speciali.
- Invio testo libero.
- Scorciatoie rapide: copia, incolla, taglia, annulla, seleziona tutto, mostra desktop, task manager.
- Nessuna dipendenza Python esterna.

## Porta

La porta predefinita e `8765`. Per cambiarla:

```powershell
$env:EMUK_PORT = "9000"
python companion.py
```

## Sicurezza

Usa emuK solo su reti fidate. Chi riesce ad aprire la pagina dal network puo inviare input tastiera al PC mentre il companion e in esecuzione.
