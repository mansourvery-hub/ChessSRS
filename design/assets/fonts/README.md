# Fonts

This design uses two typefaces, both SIL Open Font License 1.1. They are not bundled in this package (to
keep it small and avoid redistributing files whose licence terms you should confirm at download time
yourself). Download, verify the licence, and drop the files here before wiring up `pubspec.yaml`.

## Instrument Sans (interface + notation)

- Source: Google Fonts — https://fonts.google.com/specimen/Instrument+Sans
- Weights needed: 400 (Regular), 500 (Medium), 600 (SemiBold)
- Expected file names (adjust `chesssrs_tokens.dart`'s `SrsText.ui` family / the app's `pubspec.yaml` font
  entry if you name them differently):
  - `InstrumentSans-Regular.ttf`
  - `InstrumentSans-Medium.ttf`
  - `InstrumentSans-SemiBold.ttf`

## Newsreader (study notes only)

- Source: Google Fonts — https://fonts.google.com/specimen/Newsreader
- Weight needed: 400 (Regular), upright (not italic)
- Expected file name: `Newsreader-Regular.ttf`

## `pubspec.yaml` entry (example)

```yaml
flutter:
  fonts:
    - family: InstrumentSans
      fonts:
        - asset: assets/fonts/InstrumentSans-Regular.ttf
          weight: 400
        - asset: assets/fonts/InstrumentSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/InstrumentSans-SemiBold.ttf
          weight: 600
    - family: Newsreader
      fonts:
        - asset: assets/fonts/Newsreader-Regular.ttf
          weight: 400
```

## Licence

Include the OFL 1.1 licence text (downloaded alongside the fonts) in the app's About/Licences screen and in
whatever `LICENSES`/`third_party` folder the repo uses for bundled asset licences.
