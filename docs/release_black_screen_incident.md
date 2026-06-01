# Incident release 2026-05-21 - ecran noir au lancement

## Source

Un APK release a ete construit avec la commande nue `flutter build apk --release`,
sans `--dart-define=API_BASE_URL=...`.

En release, `ApiService.validateBaseUrl()` refuse la valeur par defaut
`http://10.0.2.2:8000`. Comme ce controle etait execute avant `runApp()`,
l'application pouvait rester sur un ecran noir au lancement.

## Prevention

- Ne jamais builder un APK release directement avec `flutter build apk --release`.
- Utiliser `tools\build_mobile_release.ps1`, qui exige `-ApiBaseUrl`.
- Pour un backend HTTP temporaire, fournir aussi `-CleartextAllowedHosts <host>`
  et verifier que le host est autorise dans
  `PPRCollecte_Flutter\android\app\src\main\res\xml\network_security_config.xml`.
- Le bootstrap Flutter affiche maintenant `Configuration release invalide` au
  lieu d'un ecran noir si une configuration invalide passe quand meme.

## Commande locale type

```powershell
tools\build_mobile_release.ps1 `
  -ApiBaseUrl http://192.168.10.153:8000 `
  -CleartextAllowedHosts 192.168.10.153 `
  -OutputName 2026-05-21-local-192.168.10.153-v6-nuwa.apk
```
