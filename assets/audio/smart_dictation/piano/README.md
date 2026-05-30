# Piano samples (C2–C7)

Per-note WAV files for low-latency piano playback (music companion, music play, smart dictation, smart sight singing).

- **Sound**: FluidR3 GM *acoustic grand piano* (MusyngKite bank)
- **Source**: [gleitz/midi-js-soundfonts](https://github.com/gleitz/midi-js-soundfonts) (`MusyngKite/acoustic_grand_piano-mp3`)
- **Format**: mono, 44.1 kHz, 16-bit PCM, ~3.2 s max (trimmed tail + fade-out)
- **Naming**: naturals `C4.wav`; sharps `Cs4.wav` (C♯4) to avoid `#` in filenames

Regenerate with:

```bash
python tools/fetch_standard_piano_samples.py
```

Dart mapping: `lib/core/audio/piano_note_assets.dart`
