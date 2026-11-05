import Toybox.Lang;

//! One short line of guidance at the bottom of the face. First matching rule wins.
//! Kept to ~16 characters so it fits the lower chord of a 416 px round display.
module Nudge {

    // Colour hints returned with each nudge
    const TONE_INFO = 0;
    const TONE_GO = 1;
    const TONE_CAUTION = 2;
    const TONE_STOP = 3;

    function pick(s as Snapshot, cfg as Config, b, ready, bodyPct as Float, lifePct as Float) as Array {
        var nowMin = s.hour * 60 + s.minute;
        var endMin = cfg.workEnd * 60;
        var bedMin = (s.sleepSec != null) ? s.sleepSec / 60 : 22 * 60 + 30;
        var workday = Scoring.isWorkday(s);

        // (An event starting within 10 min is shown by the next-event line itself, highlighted.)

        // 1. Body is telling you to back off.
        if (ready != null && ready < 30) {
            return ["RECOVERY DAY", TONE_STOP];
        }
        if (s.stress != null && s.stress >= 76) {
            return ["BREATHE 2 MIN", TONE_CAUTION];
        }

        // 2. Work is eating the evening.
        if (workday && Scoring.overtimeMin(s, cfg) > 60) {
            return ["WRAP UP WORK", TONE_CAUTION];
        }
        if (Scoring.workOverloaded(s, cfg, b) && nowMin < endMin) {
            return ["GUARD A GAP", TONE_CAUTION];
        }

        // 3. Training window: output is behind and readiness supports it.
        if (bodyPct < 0.5 && (ready == null || ready >= 50) && nowMin >= 15 * 60 && nowMin < bedMin - 150) {
            return ["TRAIN WINDOW", TONE_GO];
        }

        // 4. Evening: reading, then sleep.
        if (b != null && b.get("read") != null && b.get("read") < cfg.readGoal
                && nowMin >= 19 * 60 && nowMin < bedMin - 30) {
            var left = cfg.readGoal - b.get("read");
            return ["READ " + left.format("%d") + " MIN", TONE_GO];
        }
        if (nowMin >= bedMin - 60 && nowMin < bedMin + 120) {
            return ["WIND DOWN", TONE_INFO];
        }

        // 5. Daytime output lag (gentle).
        if (s.steps != null && s.stepGoal != null && s.stepGoal > 0
                && nowMin >= 11 * 60 && nowMin < endMin && s.steps < s.stepGoal * 0.3) {
            return ["WALK 10", TONE_GO];
        }

        // 6. All three pillars moving together.
        if (bodyPct >= 0.9 && lifePct >= 0.6) {
            return ["IN BALANCE", TONE_GO];
        }
        return ["", TONE_INFO];
    }
}
