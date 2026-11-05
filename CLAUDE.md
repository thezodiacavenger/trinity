# Trinity: notes for Claude

Garmin Connect IQ watch face (Forerunner 265 first) that balances WORK · BODY · LIFE with a READY core.
Owner: Product and Sales Support Manager at Vistek Ltd (Canada). Not a developer: explain in plain language,
lead with what changed for them, keep technical detail in the repo.

**Read `docs/SESSION_NOTES.md` first.** It has the original request, decisions, open questions, sources and next steps.
Open GitHub issues are the work queue.

## Rules for this repo

- **Scoring lives in three places and must stay in sync:** `source/Scoring.mc`, `source/Nudge.mc`, and the JS
  `model()` in `docs/trinity-brief.html`. Change one, change all three, then update section 4 of `docs/SESSION_NOTES.md`.
- **Privacy:** calendar titles, attendees and locations never leave the Bridge. `tools/test_bridge.js` asserts this; keep that test.
- **Never commit** the Connect IQ developer key (`*.der`) or build output (`bin/`, `*.prg`).
- **The watch face has never been compiled** (no SDK in cloud sessions). Don't claim it builds until someone runs
  it in the Connect IQ simulator. Say so when reporting.
- Target devices: `fr265` (416 px AMOLED), `fr265s` (360 px), `fr965`. Min API 4.2.0; sleep score needs 6.0.2 and is guarded.

## Commands

```bash
node tools/test_bridge.js          # Bridge logic tests (also run by GitHub Actions)
node tools/screenshot_brief.js     # Re-render docs/screenshots/ from the brief (needs Playwright)
```

The published brief is https://claude.ai/artifact/V54VpVWT41W4Swxh4YAEEC. Republish it after changing `docs/trinity-brief.html`.
