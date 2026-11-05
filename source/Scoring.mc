import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

//! The Trinity model.
//!
//!   WORK  - where you are in the work day, and whether it is spilling over (overtime, meeting overload)
//!   BODY  - physical output vs a target that is ADJUSTED by readiness
//!   LIFE  - recharge outside work: calm time, personal time, reading
//!   READY - the core. Sleep, Body Battery, stress, training recovery. It modulates the other three:
//!           a poor night lowers the body target and turns the nudges toward recovery.
//!
//! All pillar scores are 0.0 - 1.0 (progress toward today's target). READY is 0 - 100.
module Scoring {

    function clamp(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    function ratio(v, goal) as Float {
        if (v == null || goal == null || goal <= 0) { return 0.0; }
        return clamp(v.toFloat() / goal.toFloat(), 0.0, 1.0);
    }

    function prop(key as String, dflt) {
        try {
            var v = Application.Properties.getValue(key);
            return (v == null) ? dflt : v;
        } catch (e) {
            return dflt;
        }
    }

    function loadConfig() as Dictionary {
        return {
            :kcalGoal   => prop("ActiveKcalGoal", 900),
            :workStart  => prop("WorkStartHour", 8),
            :workEnd    => prop("WorkEndHour", 17),
            :meetingCap => prop("MeetingCapMin", 240),
            :calmGoal   => prop("CalmGoalMin", 90),
            :lifeGoal   => prop("LifeGoalMin", 90),
            :readGoal   => prop("ReadingGoalMin", 30)
        };
    }

    //! Calendar data from the optional Trinity Bridge, or null if absent / older than 3 hours.
    function bridge() {
        var b = Application.Storage.getValue("bridge");
        if (!(b instanceof Dictionary)) { return null; }
        var rx = b.get("rx");
        if (rx == null || Time.now().value() - rx > 3 * 3600) { return null; }
        return b;
    }

    // ------------------------------------------------------------------ READY

    function readiness(s as Snapshot) {
        var sum = 0.0;
        var w = 0.0;
        if (s.bodyBattery != null) { sum += 0.45 * s.bodyBattery; w += 0.45; }
        if (s.sleepScore != null)  { sum += 0.30 * s.sleepScore;  w += 0.30; }
        if (s.stress != null)      { sum += 0.25 * (100 - s.stress); w += 0.25; }
        if (w == 0.0) { return null; }
        var r = sum / w;
        if (s.recoveryMin != null && s.recoveryMin > 0) {
            // Up to -25 points while Garmin still counts recovery hours (72 h is its maximum).
            r -= clamp(s.recoveryMin / 4320.0 * 25.0, 0.0, 25.0);
        }
        return clamp(r, 0.0, 100.0).toNumber();
    }

    //! Readiness scales the body target. High performers' most common failure is not too little
    //! output, it is stacking hard training on short sleep and a high-stress day.
    function targetFactor(ready) as Float {
        if (ready == null || ready >= 70) { return 1.0; }
        if (ready >= 40) { return 0.8; }
        return 0.6;
    }

    // ------------------------------------------------------------------ BODY

    function body(s as Snapshot, cfg as Dictionary, ready) as Float {
        var kcalGoal = cfg[:kcalGoal] * targetFactor(ready);
        var imDaily = (s.intensityWeekGoal != null) ? s.intensityWeekGoal / 7.0 : 22.0;
        return 0.60 * ratio(s.activeKcal, kcalGoal)
             + 0.25 * ratio(s.steps, s.stepGoal)
             + 0.15 * ratio(s.intensityToday, imDaily);
    }

    function adjustedKcalGoal(cfg as Dictionary, ready) as Number {
        return (cfg[:kcalGoal] * targetFactor(ready)).toNumber();
    }

    // ------------------------------------------------------------------ WORK

    function isWorkday(s as Snapshot) as Boolean {
        return s.weekday >= 2 && s.weekday <= 6;
    }

    //! Minutes past the configured end of the work day (0 if not past it, or not a work day).
    function overtimeMin(s as Snapshot, cfg as Dictionary) as Number {
        if (!isWorkday(s)) { return 0; }
        var endSec = cfg[:workEnd] * 3600;
        return (s.secOfDay > endSec) ? (s.secOfDay - endSec) / 60 : 0;
    }

    //! Work arc = progress through the planned work day.
    function work(s as Snapshot, cfg as Dictionary) as Float {
        if (!isWorkday(s)) { return 0.0; }
        var startSec = cfg[:workStart] * 3600;
        var endSec = cfg[:workEnd] * 3600;
        if (endSec <= startSec) { return 0.0; }
        return clamp((s.secOfDay - startSec).toFloat() / (endSec - startSec), 0.0, 1.0);
    }

    //! True when the day is out of balance on the WORK side: meetings over cap, or > 1 h overtime.
    function workOverloaded(s as Snapshot, cfg as Dictionary, b) as Boolean {
        if (overtimeMin(s, cfg) > 60) { return true; }
        if (b != null && b.get("meet") != null && cfg[:meetingCap] > 0) {
            return b.get("meet") > cfg[:meetingCap];
        }
        return false;
    }

    // ------------------------------------------------------------------ LIFE

    function life(s as Snapshot, cfg as Dictionary, b) as Float {
        var calm = ratio(s.calmMin, cfg[:calmGoal]);
        if (b == null) { return calm; }
        var personal = (b.get("pers") != null ? b.get("pers") : 0) + (b.get("read") != null ? b.get("read") : 0);
        return 0.5 * calm + 0.5 * ratio(personal, cfg[:lifeGoal] + cfg[:readGoal]);
    }
}
