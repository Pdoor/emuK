# emuK

emuK trasforma un tablet o smartphone in una tastiera remota per Windows.

La web app gira sul telefono/tablet, mentre un companion Python su Windows riceve i comandi e li invia al sistema operativo come input tastiera.

Nota: una web app non puo presentarsi a Windows come una vera tastiera Bluetooth HID. emuK emula l'effetto pratico tramite rete/tunnel e input Windows.

## Avvio consigliato

Usa il tunnel se vuoi evitare problemi di firewall, router, isolamento Wi-Fi o certificati locali.

```powershell
cd C:\Users\gmeluzzi\emuk
.\start-tunnel.bat
```

Il comando:

- scarica `cloudflared` al primo avvio;
- avvia emuK localmente su `127.0.0.1:5000`;
- stampa un URL temporaneo `https://...trycloudflare.com`.

Apri quell'URL su tablet/iPhone/Android. Nella pagina deve comparire:

```text
Connesso a Windows
Metodo: HTTP compatibile.
```

Poi clicca in una finestra Windows, per esempio Blocco Note, e premi `Test`.

## Avvio solo LAN

Se telefono e PC si raggiungono sulla stessa rete locale:

```text
start-http-5000.bat
```

Apri dal telefono:

```text
http://IP-DEL-PC:5000
```

Per vedere l'IP corretto, le porte e lo stato firewall:

```powershell
.\diagnose-emuk.ps1
```

Per aprire le porte nel Firewall Windows, da PowerShell come amministratore:

```powershell
.\open-firewall.ps1
```

## HTTPS locale

`start-emuk.bat` avvia HTTPS locale sulla porta `8787` e un fallback HTTP sulla porta `8788`.

```text
start-emuk.bat
```

La prima apertura HTTPS richiede di accettare il certificato locale self-signed. Se il browser rifiuta il certificato, usa `start-http-5000.bat` oppure `start-tunnel.bat`.

## Funzioni

- Tastiera touch con lettere, numeri, Tab, funzione, frecce e tasti speciali.
- Invio testo libero.
- Scorciatoie rapide: copia, incolla, taglia, annulla, seleziona tutto, Alt Tab, mostra desktop, task manager.
- Trasporto HTTP predefinito, compatibile con browser mobile e tunnel.
- WebSocket opzionale aggiungendo `?ws=1` all'URL.
- Nessuna dipendenza Python esterna per il companion base.

## Requisiti

- Windows.
- Python 3 disponibile come `py` o `python`.
- Per la modalita tunnel: accesso internet per scaricare/eseguire `cloudflared`.
- Per la modalita LAN: telefono e PC devono potersi raggiungere sulla stessa rete.

## Porte

- `5000`: HTTP semplice, usato da `start-http-5000.bat` e `start-tunnel.bat`.
- `8787`: HTTPS locale, usato da `start-emuk.bat`.
- `8788`: fallback HTTP locale quando HTTPS e attivo.

Per cambiare porta manualmente:

```powershell
$env:EMUK_PORT = "9000"
$env:EMUK_HTTPS = "0"
python companion.py
```

## Troubleshooting

Se la pagina si apre ma compare `Invio fallito`, aggiorna il repo e riavvia il companion:

```powershell
git pull
.\start-tunnel.bat
```

Se dal telefono la pagina LAN va in timeout:

- prova prima `start-tunnel.bat`;
- verifica che l'IP del telefono e quello del PC siano nella stessa subnet;
- controlla che non sia una rete guest o isolata;
- esegui `open-firewall.ps1` come amministratore.

Se la pagina resta su `WebSocket non disponibile`, ricarica senza WebSocket oppure aggiungi un cache buster:

```text
https://...trycloudflare.com/?v=3
```

WebSocket non e necessario per l'uso normale.

## Sicurezza

Usa emuK solo in sessioni controllate. Chi riesce ad aprire la pagina mentre il companion e in esecuzione puo inviare input tastiera al PC.

Con `start-tunnel.bat`, l'URL `trycloudflare.com` e pubblico ma temporaneo: chiudi il terminale quando hai finito.
