# VoiceInk (Derek's build) -- install guide

Free, fully unlocked build of the open-source VoiceInk dictation app,
with polish and bug fixes on top of upstream. Tap or hold Fn, talk,
and clean text lands in whatever app you're typing in.

## Install (easiest)

Paste this into Terminal and press return:

```
curl -fsSL https://raw.githubusercontent.com/dnage76-beep/VoiceInk/main/install.sh | bash
```

It downloads the app, installs it, and skips the Gatekeeper warning
below. Then jump to step 3.

## Install (by hand)

1. Drag **VoiceInk.app** to Applications.
2. First open: **right-click the app, choose Open, then Open again.**
   (This build isn't notarized with Apple, so macOS asks once. If you
   instead see "Apple could not verify...", go to System Settings >
   Privacy & Security, scroll down, and click **Open Anyway**.)
3. The app walks you through permissions:
   - **Microphone**: click Allow.
   - **Accessibility**: needed to type text into other apps. Toggle
     VoiceInk on when System Settings opens, then quit and reopen
     VoiceInk once so the hotkey engine picks it up.
4. In onboarding, pick **Parakeet V2** as the model (fast, accurate,
   runs entirely on your Mac -- audio never leaves the machine).

That's the whole setup. When onboarding finishes you're on a proven
configuration: **Fn is the hotkey** (tap to toggle, hold to talk),
the app starts at login, and short phrases paste instantly.

## AI cleanup (the best part)

Raw dictation is instant and local. AI cleanup (removes ums, fixes
grammar, formats emails) is a second pass on top:

- **Claude Code users: zero setup.** If the `claude` command is on
  your Mac, the app finds it during onboarding and turns cleanup on
  automatically. Uses your existing Claude subscription, no API key,
  transcript-only (audio never leaves your Mac).
- **Free API key**: Groq or Cerebras free tiers work and are fast.
  Set it in the AI Enhancement page.
- **Skip it**: dictation works fine without any of this.

## Notes

- This build never auto-updates (that's deliberate: auto-update would
  replace it with the paid App Store-style build). Updates come as a
  new copy of the app; your settings and history are kept.
- If you rebuild or replace the app, re-grant Accessibility (macOS
  treats each unsigned build as a new app).
- Source code: VoiceInk is GPL v3. This build's source is available at
  the repo link that came with it.
