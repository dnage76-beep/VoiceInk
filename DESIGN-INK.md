# Ink design language (from Wispr Flow field study, 2026-07-28)

Captured live from Wispr Flow v1.6.224 on Derek's Mac. This is the styling
target for the VoiceInk fork. Emulate the language; never copy their sentences
verbatim or their branding.

## Palette (monochrome + one accent moment)

- Window background: warm off-white `#F7F6F3` (light appearance; the app is
  LIGHT-first, not dark)
- Content cards: pure white `#FFFFFF`, hairline border `#E8E7E3`, radius ~12
- Text primary: near-black `#1A1A18`
- Text secondary: `#6B6A66`
- Primary button: solid near-black pill, white text ("Add new", "Create New")
- Secondary button: light gray fill `#EFEEEB`, dark text ("Change", "Set up")
- Toggles: black when on, gray when off (native switch look)
- ONE accent used only for data/emphasis: deep teal `#1F6F6B` (gauge, usage
  bars, heatmap). Keyboard chips get a warm tan tint.
- Recorder pill overlay: black, white waveform.
- VoiceInk keeps supporting dark mode: mirror with `#161513` bg, `#211F1C`
  cards, same structure. Light is the design-primary appearance.

## Typography

- UI text: system sans (SF), 13 body, 11 secondary/captions.
- Page titles: ~26 SERIF (New York / `.serif` design), regular weight, not
  bold-heavy: "General", "Vibe coding", "My Transforms".
- Marketing/headline lines inside banner cards: serif with ITALIC serif on the
  one emphasized word ("Make Flow sound like *you*").
- Stat numerals: 28-34 sans semibold; label BELOW in 10-11 caps or lowercase
  secondary ("96" / "wpm", "209" / "total words").
- Small-caps section labels: "TODAY", "SETTINGS", "ACCOUNT", "WORDS PER MINUTE".

## Components

- Sidebar: flat list, NO colored icon tiles. Small monochrome SF symbols
  (~14pt), 13pt labels, selected row = soft gray pill `#EAE9E5` (no accent
  color, no border). Width ~200. Brand row on top (logo + name). Utility
  items pinned bottom (Settings, Help).
- Tabs: text-only with 2pt underline on the active tab (Insights: "Your
  usage / Your voice"; Dictionary: "All / Personal").
- Settings: MODAL SHEET over the window, own left nav (icon + label, small),
  serif page title, version string bottom-left.
- Settings rows: white card, one row per setting: Title (13 medium) +
  one-line summary under it (12 secondary, states CURRENT value, e.g. "Hold
  Fn and speak.") + trailing "Change" secondary button OR toggle. Detail
  lives behind Change, never inline. This is the progressive disclosure.
- Info icons (ⓘ) after stat labels; detail on hover, not in the layout.
- Keyboard chips: rounded rect, hairline border, warm tint, symbol + name
  ("⌘ Cmd", "⌥ Opt 1").
- Inline code chip for technical values (`index.tsx`): mono font, light
  gray chip.
- List rows (history, dictionary): plain white, time/label left in secondary,
  content primary, hover-revealed trailing actions (copy, flag, kebab). Rows
  separated by hairlines, not cards.
- Banner/promo card: dark photo or black card, serif headline with italic
  emphasis word, one explaining sentence, light-gray pill CTA. Dismissable X.
- Empty states: single quiet line, centered ("No notes found").
- Beta features: small "Beta" chip (black on light gray) after the title +
  opt-in toggle at top right of the page.

## Copy voice (write like this, never like a feature list)

- Second person, present tense, short. One sentence where possible.
- Pattern A (what it is): "The stuff you shouldn't have to re-type."
- Pattern B (how to act): verb-first: "Save text you type often, then say a
  word to drop it in instantly."
- Pattern C (settings summary): state the CURRENT value plainly: "Hold Fn
  and speak." "Built-in mic (recommended)." "English".
- Pattern D (benefit line under a feature): "Better understands variables in
  code. Learn more →"
- No exclamation marks. No "powerful", "seamless", "supercharge". No em
  dashes (Derek's rule; use commas or colons). Bold key phrases inline
  sparingly when explaining ("Add personal terms, company jargon").
- Big claims live in banner cards only; settings stay dry and factual.

## Screen-by-screen target for VoiceInk

1. **Dashboard (= Wispr "Dictation" home)**: greeting "Hey Derek, talk with
   [Fn chip]" style header with real hotkey chip; right rail stat mini-card
   (total words / wpm / streak) + unlock-progress card; TODAY history list
   (time + text + hover actions) replaces nothing: we keep insights page
   below or split. Keep our insights content but restyle cards to white/
   hairline + teal-only accents.
2. **History**: hairline rows, hover actions (copy, delete), search icon
   right-aligned, day group headers in small caps.
3. **Dictionary**: two tabs (Vocabulary / Replacements), "Add new" black
   pill top right, rows plain, replacement rows as "btw → by the way".
4. **AI Enhancement**: keep; restyle rows as settings rows; provider status
   line states current value ("Claude via local bridge, connected").
5. **Modes**: keep features; restyle cards to white cards, monochrome icons,
   black toggles; "Beta"-style chips for model names in gray, not colored.
6. **Settings**: convert to modal-sheet style with left nav or at least
   settings-row pattern (title + current value + Change).
7. **Recorder pill**: already black; keep. Three styles now: Notch, Mini, and
   Minimalist. Minimalist is Notch's motion with Notch's problems removed:
   Notch draws a notch-hugging shape sized to the physical notch, so on a
   notchless Mac (Derek's Air has no notch) it falls back to a hardcoded
   180pt width and reads as a slab pinned to nothing. Minimalist uses a fixed
   124x30 capsule tucked under the menu bar, shows no live text and no
   assistant panel, and meters the voice with a single breathing circle
   (PulseVisualizer) instead of a waveform: the only question a minimal
   recorder should answer is "am I being heard".
8. **Onboarding**: keep flow, restyle to white cards + serif headline with
   italic emphasis; copy per voice rules.

## Feature gaps vs Wispr (add without removing anything)

- [x] Dictionary replacements (= their Snippets, spoken-phrase expansions)
- [ ] Rename/reframe: surface Word Replacements as "Snippets: say a word,
      drop in saved text" with their explanation pattern
- [x] Insights: wpm stat and day streak, on the dashboard summary strip
      (derived from SessionMetric; tests in DashboardStreakTests). Per-app
      usage split still open.
- [x] "Cleaned up by AI" counter (sessions with an enhancement model named,
      shown against the session total)
- [ ] Transforms (post-hoc rewrite of last transcription via hotkey):
      VoiceInk has retryLastTranscription + pasteLastEnhancement; a
      "re-enhance with prompt X" action exists in AudioPlayerView; defer
      unless time allows
- [ ] Scratchpad: defer (History + Notes cover it); do not build v1
- [ ] Voice profile: skip (requires their cloud analysis)

## Implementation order (multiple passes)

1. AppTheme rewrite: light-first ink palette, semantic tokens, serif title
   helper, chip components (KeyChip, CodeChip, BetaChip).
2. Sidebar + ContentView restyle.
3. Dashboard restyle + right-rail stats + wpm/streak computation.
4. Settings-row component; apply to Settings, AI Enhancement, Audio.
5. Dictionary/History/Modes restyle + copy pass everywhere.
6. Rebuild, screenshot every page, compare, fix. Repeat.
7. Logo: Derek drops an icon on the Desktop; convert to AppIcon.appiconset
   (iconutil) and rebuild.

## Build invariants (do not forget)

- After every `make local`: re-sign with "Derek Nagel Local CodeSign"
  before installing, or permissions break.
- Never remove existing features. Never touch the bridge/enhancement
  pipeline while restyling.
- Test after each pass: chord ctrl+opt+cmd+D toggles recorder; verify a
  transcription lands in ZTRANSCRIPTION.

## Fresh-install defaults = Derek's proven setup (2026-07-28)

Onboarding should land a new user exactly here, no configuration needed:

- Launch at login: ON (LaunchAtLogin.isEnabled = true at onboarding finish)
- Hotkey: Fn, hybrid (tap toggle, hold push-to-talk); set AppleFnUsageType=0
- Transcription: Parakeet V2, realtime streaming ON, VAD ON
- Enhancement default: Local CLI Claude template if `claude` binary found on
  PATH, else off with a one-line pointer to the AI Enhancement page
- SkipShortEnhancement ON, threshold 6 words; timeout 20s; no retry
- Modes seeded: Default (enhance if provider set), Agentic Coding, Texting,
  Email, Writing (same prompts/triggers as StarterModeCatalog)
- Sound feedback ON, mute-music-while-recording ON
- Menu bar icon ON, dock icon ON

Also wanted: perf pass (Instruments trace while dictating; suspects:
realtime streaming UI updates, VisualEffectView repaints, stats refresh),
and the speed feel: recorder should appear <100ms after hotkey.
