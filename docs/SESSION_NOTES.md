# Trinity: session notes and handoff

Everything needed to pick this project up later, including in a new Claude session.
Start a new session with: *"Read docs/SESSION_NOTES.md and continue the Trinity project."*

- **Design brief (live, private):** https://claude.ai/artifact/V54VpVWT41W4Swxh4YAEEC
  The same page is in this repo at `docs/trinity-brief.html`. Open it in any browser.
- **Repo:** https://github.com/thezodiacavenger/trinity
- **Started:** 2026-11-05

---

## 1. The original request (owner's words, lightly condensed)

> Do some research on people who are high-performing physical athletes who are also alpha-level executives,
> and consider an app to create for the Garmin 265 or Garmin suite of watches, but namely the 265.
>
> I would like a watch face that considers work-life balance, work-life physical activity balance. It is the
> Trinity. We'll call it Trinity: something that shows the time, your heart rate, your steps, your activity for
> the day, like your output. Are you hitting your caloric output goal for the day with physical activity?
>
> Upcoming meeting appointment. If it can read a calendar, it doesn't have to say what it is. Read the schedule,
> and it'd give you a little, say, meeting, lunch, or personal time, things to balance. Then somehow factor in
> reading time.
>
> I want a watch face for this, and I want an app for this somehow. Stress should also factor in: if you're short
> on sleep, if your stress level is high, is your body battery low? Understand the capabilities of the watch.
> Understand the capabilities of someone who works full days, goes out and hits their 1 or 2 hours of workouts a
> day, and then has a busy personal or activity life.

Owner context: Product and Sales Support Manager at Vistek Ltd (Canada), increasingly working with the President,
VP and CFO.

---

## 2. Where things stand

| Piece | State | Notes |
|---|---|---|
| Watch face (`source/`, `resources/`, `manifest.xml`) | Code drafted, **never compiled** | No Connect IQ SDK was available in the cloud session. First job: build in the simulator and fix compile errors. |
| Calendar Bridge, Google (`bridge/google-apps-script/Code.gs`) | Written, logic tested | `node tools/test_bridge.js` passes. Not yet deployed to a Google account. |
| Calendar Bridge, Microsoft 365 | Not started | Needed if the work calendar is Outlook. |
| Trinity on-watch app + glance | Not started | Phase 3, spec below. |
| Weekly review (phone or web) | Not started | Phase 4. |
| Design brief + simulator (`docs/trinity-brief.html`) | Done, published | The JS model in the page mirrors `Scoring.mc` and `Nudge.mc`; keep them in sync. |
| Screenshots (`docs/screenshots/`) | Current | Regenerate with `node tools/screenshot_brief.js`. |

---

## 3. Decisions still needed from the owner

1. **Calendar source:** Google, Outlook / Microsoft 365, or both. This decides which Bridge to finish. Outlook depends on what Vistek IT allows (Graph API app, Power Automate flow, or Azure Function).
2. **Targets:** active-calorie goal (draft default 900 kcal, about 1–2 h of training), work hours (default 08:00–17:00 Mon–Fri), meeting cap (default 240 min), calm goal (90 min), personal-time goal (90 min), reading goal (30 min).
3. **Distribution:** sideload to own watch only, or publish to the Connect IQ Store (needs review and a privacy statement).
4. **Developer setup:** Garmin developer account, Connect IQ SDK Manager with the `fr265` device, VS Code Monkey C extension.

---

## 4. Design decisions already made (and why)

- **Three pillars + a core.** WORK, BODY, LIFE are the arcs. READY (sleep, Body Battery, stress, recovery time) is the core and *modulates* the targets instead of being a fourth arc. Reason: the owner listed stress, sleep and Body Battery as things that should "factor in," and the main failure mode for executive athletes is stacking hard training on short sleep and a stressful day.
- **Readiness lowers the body target:** READY ≥ 70 → 100% of the goal, 40–69 → 80%, < 40 → 60%.
- **Calendar privacy:** the face shows "MTG IN 8m", never a title. The Bridge returns only categories and minutes. Reason: the owner said "it doesn't have to say what it is," and a watch face is visible across a boardroom table.
- **Reading time comes from the calendar** ("Read" blocks), because no sensor measures it and watch faces cannot take input. Later the on-watch app adds a reading timer.
- **No logging on the wrist for the face.** Watch faces cannot take button or touch input. Anything interactive goes in the Phase 3 app.
- **Imminent events:** when something starts within 10 minutes, the next-event line turns white. (An earlier draft also put it in the nudge line, which duplicated it; removed.)
- **Battery:** the background calendar fetch runs every 15 min (Connect IQ minimum is 5), and only when a Bridge URL is configured. Calm-minute calculation (walks the day's stress history) is cached for 15 min.
- **AMOLED always-on mode:** arcs dropped; dimmed time and next event only, shifted a few pixels each minute for burn-in protection.
- **Palette:** Work blue `#3D9BFF`, Body orange `#FF6A3D`, Life green `#3DDC97`, warning amber `#FFB000`, stop red `#FF3B3B`, on true black.

### Scoring (source of truth: `source/Scoring.mc`)

- **READY** = 0.45·BodyBattery + 0.30·SleepScore + 0.25·(100 − Stress), reweighted over whichever signals exist, minus up to 25 for recovery hours (72 h max).
- **BODY** = 0.60·(active kcal ÷ adjusted goal) + 0.25·(steps ÷ step goal) + 0.15·(intensity min today ÷ weekly goal/7).
  Active kcal = Garmin total calories − Mifflin-St Jeor resting burn prorated to the time of day.
- **WORK** = progress through the work window. Amber when > 60 min overtime or meetings > cap.
- **LIFE** = calm minutes since wake ÷ goal; with the Bridge, 50% calm + 50% (personal + reading) ÷ (goals).

### Nudges (source of truth: `source/Nudge.mc`), first match wins

RECOVERY DAY (READY < 30) → BREATHE 2 MIN (stress ≥ 76) → WRAP UP WORK (> 60 min overtime) → GUARD A GAP
(meetings over cap during work hours) → TRAIN WINDOW (after 15:00, BODY < 50%, READY ≥ 50, > 2.5 h before bed) →
READ N MIN (after 19:00, reading short of goal, Bridge only) → WIND DOWN (within 1 h of bedtime) → WALK 10
(after 11:00, < 30% of step goal) → IN BALANCE (BODY ≥ 90%, LIFE ≥ 60%).

---

## 5. Forerunner 265 / Connect IQ facts relied on

- Complications API (Connect IQ API 4.2.0+) exposes: steps, calories (total), intensity minutes (weekly), heart rate, Body Battery, stress, recovery time (minutes), next calendar event (**time string only, no title or date**), battery, notifications, VO2 max, training status, race predictors, pulse ox, respiration. **Sleep score** only from API 6.0.2.
- **Not available** to third-party faces: HRV status, Training Readiness score, calendar titles or details, Garmin's own "active calories" number.
- Watch faces cannot take input. Background temporal events every ≥ 5 min; web requests go through the Garmin Connect phone app.
- AMOLED always-on requires burn-in protection and a limited lit-pixel budget.
- Watch-face memory is limited (about 128 KB on comparable 416 px AMOLED devices; check the simulator's memory view for the 265).
- Targets in `manifest.xml`: `fr265`, `fr265s`, `fr965`.

### Verify on first build

- Exact format of the calendar complication string (`"2:30p"` vs `"14:30"`). `Metrics.minutesUntil` handles both.
- That the `ComplicationSubscriber` permission name is right and complications read without subscribing.
- Estimated active calories vs Garmin Connect (target within ~10%).
- Fonts and positions on 416 px (265) and 360 px (265S).
- Whether Google Apps Script's redirect works with `makeWebRequest`. If not, host the Bridge on a Cloudflare Worker.

---

## 6. Research summary

- **Corporate athlete:** Loehr & Schwartz, "The Making of a Corporate Athlete," *Harvard Business Review*, 2001. Sustained performance comes from cycling stress and recovery; manage energy, not just time.
- **CEO fitness and firm value:** S&P 1500 CEOs 2001–2011; firms whose CEO finished a marathon were valued about 5% higher after controls (Limbach & Sonnenburg, "Does CEO Fitness Matter?"). Correlation, not causation. Coverage: [Canadian Running](https://runningmagazine.ca/?p=19831), [HRM Online](https://www.hrmonline.co.nz/news/do-marathon-runners-make-better-ceos-192100.aspx).
- **Sleep:** AASM / Sleep Research Society consensus (2015): adults need 7+ hours.
- **Publicly reported routines:** Bob Iger (up ~4:15 a.m. to exercise), Tim Cook (pre-5 a.m. start, gym), Anna Wintour (daily early tennis), Richard Branson (daily exercise, says it doubles productivity), Barack Obama (~45 min daily workout), Warren Buffett (most of the day reading), Bill Gates (~50 books a year).
- **Design takeaways:** protect the morning training block; the failure mode is stacking; the calendar is the control surface; glanceable over detailed; discretion in meetings.

### Sources

- Garmin Connect IQ Complications API: https://developer.garmin.com/connect-iq/api-docs/Toybox/Complications.html
- Garmin forum, next calendar event date: https://forums.garmin.com/developer/connect-iq/f/discussion/362370/any-way-to-detect-next-calendar-event-date
- Garmin forum, calendar on watch face: https://forums.garmin.com/developer/connect-iq/f/discussion/214598/calendar-on-watch-face
- Garmin, The Real Devices of Connect IQ: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/the-real-devices-of-connect-iq-part-1

---

## 7. Next steps, in order

1. Owner answers the decisions in section 3.
2. Install the SDK, run `Monkey C: Run` on `fr265`, fix compile errors, check layout at 416 px and 360 px.
3. Sideload to the watch and live with it for a week; compare active calories with Garmin Connect.
4. Deploy the Bridge (Google steps are in the header of `Code.gs`), or build the Microsoft 365 version.
5. Phase 3, Trinity app + glance: per-pillar breakdown screens, "Start reading" timer, 2-minute breathing reset when stress spikes, weekly balance view. The glance shows today's READY and the weakest pillar. Reading minutes reach the face through the Bridge, since a face and a separate app cannot share storage.
6. Phase 4, weekly review: balance by day, nights under 7 h, overtime hours, reading minutes, next week's targets.

When changing the scoring, update `source/Scoring.mc`, `source/Nudge.mc`, the JS model in `docs/trinity-brief.html`, and this file together.
