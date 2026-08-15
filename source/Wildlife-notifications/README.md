# WildLife Notifications

WildLife Notifications ist eine iOS-App fuer Wildkamera-Sichtungen. Die App zeigt neue Bilder und Meldungen uebersichtlich an, speichert Sichtungen lokal und verbindet die Ansicht mit Immich sowie einem FTP/FTPS-Gateway.

## Was die App macht

- Empfaengt Push-Benachrichtigungen fuer neue Wildtier-Sichtungen.
- Zeigt Sichtungen mit Bild, Kamera, Status, Datum und Uhrzeit in einer scrollbaren Liste.
- Speichert Sichtungen lokal in SQLite, damit die Liste schnell verfuegbar bleibt.
- Setzt den App-Icon-Badge zurueck, sobald die Sichtungsansicht geoeffnet wird.
- Unterstuetzt Suche, Detailansicht, Teilen, Anheften und Loeschen einzelner Sichtungen.
- Laedt Bilder nach, wenn der Benutzer durch die Sichtungsliste scrollt.
- Bindet Immich ueber die API an, um Bilder und Metadaten zu verwalten.
- Kann Bilder nach Uhrzeit, Tag, Monat, Jahr oder Datumsbereich in den Immich-Papierkorb verschieben.
- Entfernt geloeschte Sichtungen nach erfolgreichem Immich-Aufruf auch aus der lokalen SQLite-Datenbank.
- Unterstuetzt FTP und explizites FTPS fuer Upload- und Gateway-Verbindungen.

## Hinweise zum Loeschen

Beim Loeschen ueber die Immich-API werden Bilder nicht sofort endgueltig entfernt, sondern mit `force: false` in den Immich-Papierkorb verschoben. Dort bleiben sie standardmaessig noch 30 Tage erhalten. Die lokalen SQLite-Eintraege werden danach aus der App-Datenbank entfernt.

## Projekt

Der iOS-Code liegt in diesem Ordner:

`source/Wildlife-notifications`

Der zugehoerige Backend-/Bot-Teil des Repositories liegt nebenan unter:

`source/WildLifeBildBot`
