import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! Layout (416 x 416, scales to 360 x 360 on the 265S):
//!
//!            ───── WORK ─────            top arc, blue (amber when overloaded)
//!               THU 5
//!               7:42                    time
//!        HR 58   8.2k   BB 72           heart rate, steps, body battery
//!              READY 74                 core score, coloured by band
//!         NEXT 2:30p · 48m              next calendar event, time only
//!   LIFE      TRAIN WINDOW      BODY    nudge
//!   (lower-left arc, green)  (lower-right arc, orange)
class TrinityView extends WatchUi.WatchFace {

    // Palette (AMOLED: true black background, saturated accents)
    const C_WORK = 0x3D9BFF;
    const C_BODY = 0xFF6A3D;
    const C_LIFE = 0x3DDC97;
    const C_WARN = 0xFFB000;
    const C_STOP = 0xFF3B3B;
    const C_TRACK = 0x262626;
    const C_TEXT = 0xFFFFFF;
    const C_MUTED = 0x9A9A9A;

    // Arc geometry: degrees, 0 = 3 o'clock, counter-clockwise positive
    const WORK_CENTER = 90;
    const BODY_CENTER = 330;
    const LIFE_CENTER = 210;
    const HALF_SPAN = 55;

    private var _w = 416;
    private var _h = 416;
    private var _cx = 208;
    private var _cy = 208;
    private var _r = 194;
    private var _pen = 12;
    private var _lowPower = false;
    private var _burnIn = false;

    // Calm-minute calculation walks the day's stress history; refresh every 15 min, not every frame.
    private var _calmMin = null;
    private var _calmAt = -1;

    function initialize() {
        WatchFace.initialize();
        var ds = System.getDeviceSettings();
        _burnIn = (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _pen = (_w * 0.03).toNumber();
        _r = _cx - _pen / 2 - 2;
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var s = Metrics.read();
        if (_calmMin == null || _calmAt < 0 || s.secOfDay < _calmAt || s.secOfDay - _calmAt >= 900) {
            _calmMin = Metrics.calmMinutesSinceWake(s.secOfDay, s.wakeSec);
            _calmAt = s.secOfDay;
        }
        s.calmMin = _calmMin;

        if (_lowPower && _burnIn) {
            drawAlwaysOn(dc, s);
            return;
        }

        var cfg = Scoring.loadConfig();
        var b = Scoring.bridge();
        var ready = Scoring.readiness(s);
        var workPct = Scoring.work(s, cfg);
        var bodyPct = Scoring.body(s, cfg, ready);
        var lifePct = Scoring.life(s, cfg, b);

        // ---- The three pillars
        var workColor = Scoring.workOverloaded(s, cfg, b) ? C_WARN : C_WORK;
        drawPillar(dc, WORK_CENTER, workPct, workColor, "W");
        drawPillar(dc, BODY_CENTER, bodyPct, C_BODY, "B");
        drawPillar(dc, LIFE_CENTER, lifePct, C_LIFE, "L");

        // ---- Date + time
        dc.setColor(C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 0.21, Graphics.FONT_XTINY, s.dateText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 0.37, Graphics.FONT_NUMBER_HOT, timeText(s), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- Stats row: HR · steps · body battery
        var y = _h * 0.555;
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 0.29, y, Graphics.FONT_TINY, "HR " + fmt(s.heartRate), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_cx, y, Graphics.FONT_TINY, stepsText(s.steps), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_w * 0.71, y, Graphics.FONT_TINY, "BB " + fmt(s.bodyBattery), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- Core: READY
        dc.setColor(readyColor(ready), Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 0.645, Graphics.FONT_XTINY, "READY " + fmt(ready), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- Next event
        var next = nextText(s, b);
        if (next != null) {
            var soon = nextMinutes(s, b);
            dc.setColor((soon != null && soon >= 0 && soon <= 10) ? C_TEXT : C_WORK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 0.73, Graphics.FONT_XTINY, next, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ---- Nudge
        var n = Nudge.pick(s, cfg, b, ready, bodyPct, lifePct);
        if ((n[0] as String).length() > 0) {
            dc.setColor(toneColor(n[1] as Number), Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 0.815, Graphics.FONT_XTINY, n[0] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! AMOLED always-on: time + next event only, dimmed, nudged a few pixels each minute
    //! to avoid burn-in and stay well under Garmin's lit-pixel budget.
    private function drawAlwaysOn(dc as Dc, s as Snapshot) as Void {
        var dx = (s.minute % 5) * 3 - 6;
        var dy = ((s.minute / 5) % 3) * 3 - 3;
        dc.setColor(0x8A8A8A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + dx, _h * 0.42 + dy, Graphics.FONT_NUMBER_MEDIUM, timeText(s), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (s.nextEventText != null) {
            dc.setColor(0x2F5F99, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx + dx, _h * 0.60 + dy, Graphics.FONT_XTINY, "NEXT " + s.nextEventText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawPillar(dc as Dc, center as Number, pct as Float, color as Number, label as String) as Void {
        var start = center + HALF_SPAN;
        dc.setPenWidth(_pen);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(_cx, _cy, _r, Graphics.ARC_CLOCKWISE, norm(start), norm(center - HALF_SPAN));
        if (pct > 0.01) {
            var sweep = (2 * HALF_SPAN * Scoring.clamp(pct, 0.0, 1.0)).toNumber();
            if (sweep < 2) { sweep = 2; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(_cx, _cy, _r, Graphics.ARC_CLOCKWISE, norm(start), norm(start - sweep));
        }
        // Pillar letter just inside the arc's midpoint
        var rad = center * Math.PI / 180.0;
        var lr = _r - _pen - (_w * 0.04);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + lr * Math.cos(rad), _cy - lr * Math.sin(rad), Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function nextText(s as Snapshot, b) {
        if (b != null && b.get("nIn") != null && b.get("nCat") != null) {
            return (b.get("nCat") as String) + " IN " + durText(b.get("nIn") as Number);
        }
        if (s.nextEventText == null) { return null; }
        if (s.minutesToNext != null && s.minutesToNext <= 720) {
            return "NEXT " + s.nextEventText + " - " + durText(s.minutesToNext);
        }
        return "NEXT " + s.nextEventText;
    }

    private function nextMinutes(s as Snapshot, b) {
        if (b != null && b.get("nIn") != null) { return b.get("nIn"); }
        return s.minutesToNext;
    }

    private function timeText(s as Snapshot) as String {
        var h = s.hour;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.format("%d") + ":" + s.minute.format("%02d");
    }

    private function durText(min as Number) as String {
        if (min < 0) { return "NOW"; }
        if (min < 60) { return min.format("%d") + "m"; }
        return (min / 60).format("%d") + "h" + (min % 60).format("%02d");
    }

    private function stepsText(steps) as String {
        if (steps == null) { return "--"; }
        if (steps >= 1000) { return (steps / 1000.0).format("%.1f") + "k"; }
        return steps.format("%d");
    }

    private function fmt(v) as String {
        return (v == null) ? "--" : v.format("%d");
    }

    private function readyColor(ready) as Number {
        if (ready == null) { return C_MUTED; }
        if (ready >= 70) { return C_LIFE; }
        if (ready >= 40) { return C_WARN; }
        return C_STOP;
    }

    private function toneColor(tone as Number) as Number {
        if (tone == Nudge.TONE_GO) { return C_LIFE; }
        if (tone == Nudge.TONE_CAUTION) { return C_WARN; }
        if (tone == Nudge.TONE_STOP) { return C_STOP; }
        return C_TEXT;
    }

    private function norm(deg as Number) as Number {
        var d = deg % 360;
        return (d < 0) ? d + 360 : d;
    }
}
