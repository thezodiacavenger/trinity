import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;

//! One snapshot of everything Trinity reads from the watch.
//! Every field may be null: the face must render with partial data.
class Snapshot {
    // Clock
    var hour = 0;
    var minute = 0;
    var secOfDay = 0;
    var weekday = 1;          // 1 = Sunday ... 7 = Saturday
    var dateText = "";

    // BODY: output
    var heartRate = null;     // bpm
    var steps = null;
    var stepGoal = null;
    var totalKcal = null;     // resting + active, so far today
    var activeKcal = null;    // estimated: total minus prorated BMR
    var intensityToday = null;
    var intensityWeek = null;
    var intensityWeekGoal = null;

    // READINESS: recovery signals
    var bodyBattery = null;   // 0-100
    var stress = null;        // 0-100 (Garmin scale: 0-25 rest, 26-50 low, 51-75 med, 76-100 high)
    var sleepScore = null;    // 0-100, API 6.0.2+ only
    var recoveryMin = null;   // minutes until recovered from training
    var calmMin = null;       // minutes at rest-level stress since wake time (cached by the view)

    // WORK: calendar (native complication gives the time of the next event only, no title)
    var nextEventText = null; // e.g. "2:30p" or "14:30"
    var minutesToNext = null;

    // Profile
    var wakeSec = null;       // seconds after midnight
    var sleepSec = null;

    function initialize() {}
}

module Metrics {

    //! Read one native complication. Returns null if the device or firmware does not expose it.
    function complication(type) {
        try {
            var c = Complications.getComplication(new Complications.Id(type));
            return (c != null) ? c.value : null;
        } catch (e) {
            return null;
        }
    }

    function read() as Snapshot {
        var s = new Snapshot();

        var ct = System.getClockTime();
        s.hour = ct.hour;
        s.minute = ct.min;
        s.secOfDay = ct.hour * 3600 + ct.min * 60 + ct.sec;
        var now = Time.now();
        s.weekday = Gregorian.info(now, Time.FORMAT_SHORT).day_of_week;
        var med = Gregorian.info(now, Time.FORMAT_MEDIUM);
        s.dateText = med.day_of_week.toUpper() + " " + med.day.format("%d");

        // ---- Heart rate: live sensor first, then the most recent history sample
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null) {
            s.heartRate = ai.currentHeartRate;
        } else if (ActivityMonitor has :getHeartRateHistory) {
            var hrIt = ActivityMonitor.getHeartRateHistory(1, true);
            var hrS = (hrIt != null) ? hrIt.next() : null;
            if (hrS != null && hrS.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                s.heartRate = hrS.heartRate;
            }
        }

        // ---- Activity monitor
        var am = ActivityMonitor.getInfo();
        if (am != null) {
            s.steps = am.steps;
            s.stepGoal = am.stepGoal;
            s.totalKcal = am.calories;
            if (am has :activeMinutesDay && am.activeMinutesDay != null) {
                s.intensityToday = am.activeMinutesDay.total;
            }
            if (am has :activeMinutesWeek && am.activeMinutesWeek != null) {
                s.intensityWeek = am.activeMinutesWeek.total;
            }
            if (am has :activeMinutesWeekGoal) {
                s.intensityWeekGoal = am.activeMinutesWeekGoal;
            }
        }
        if (s.totalKcal != null) {
            var resting = bmrPerDay() * s.secOfDay / 86400.0;
            var active = s.totalKcal - resting;
            s.activeKcal = (active > 0) ? active.toNumber() : 0;
        }

        // ---- Readiness signals via native complications (API 4.2+)
        s.bodyBattery = complication(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        s.stress = complication(Complications.COMPLICATION_TYPE_STRESS);
        s.recoveryMin = complication(Complications.COMPLICATION_TYPE_RECOVERY_TIME);
        if (Complications has :COMPLICATION_TYPE_SLEEP_SCORE) {
            s.sleepScore = complication(Complications.COMPLICATION_TYPE_SLEEP_SCORE);
        }

        // Fallbacks through SensorHistory if a complication is missing
        if (s.bodyBattery == null && (Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            s.bodyBattery = latest(SensorHistory.getBodyBatteryHistory({:period => 1}));
        }
        if (s.stress == null && (Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            s.stress = latest(SensorHistory.getStressHistory({:period => 1}));
        }
        if (s.stress != null && s.stress < 0) {
            s.stress = null; // Garmin reports negative values while it cannot measure (e.g. during activity)
        }

        // ---- Next calendar event (time only; privacy-friendly by design)
        var ev = complication(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
        if (ev instanceof String) {
            s.nextEventText = ev;
            s.minutesToNext = minutesUntil(ev, s.hour * 60 + s.minute);
        }

        // ---- Profile
        var p = UserProfile.getProfile();
        if (p != null) {
            if (p.wakeTime != null) { s.wakeSec = p.wakeTime.value(); }
            if (p.sleepTime != null) { s.sleepSec = p.sleepTime.value(); }
        }
        return s;
    }

    function latest(it) {
        if (it == null) { return null; }
        var smp = it.next();
        return (smp != null && smp.data != null) ? smp.data.toNumber() : null;
    }

    //! Mifflin-St Jeor resting energy, kcal/day. Used to split Garmin's total calories into active calories.
    function bmrPerDay() as Float {
        var p = UserProfile.getProfile();
        if (p == null || p.weight == null || p.height == null || p.birthYear == null) {
            return 1700.0;
        }
        var age = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year - p.birthYear;
        var base = 10.0 * (p.weight / 1000.0) + 6.25 * p.height - 5.0 * age;
        return (p.gender == UserProfile.GENDER_FEMALE) ? base - 161.0 : base + 5.0;
    }

    //! Parse the complication's time string ("2:30p", "2:30 PM", "14:30") into minutes from now.
    //! Returns null if the format is not recognised; the face then shows the raw text.
    function minutesUntil(text as String, nowMin as Number) {
        var t = text.toLower();
        var colon = t.find(":");
        if (colon == null || colon == 0 || colon + 3 > t.length()) { return null; }
        var h = t.substring(0, colon).toNumber();
        var m = t.substring(colon + 1, colon + 3).toNumber();
        if (h == null || m == null) { return null; }
        var rest = t.substring(colon + 3, t.length());
        if (rest != null && rest.find("p") != null && h < 12) { h += 12; }
        if (rest != null && rest.find("a") != null && h == 12) { h = 0; }
        var diff = h * 60 + m - nowMin;
        if (diff < -5) { diff += 1440; } // the next event is tomorrow
        return diff;
    }

    //! Minutes spent at rest-level stress (<= 25) between wake time and now.
    //! This is the on-watch proxy for "did I genuinely decompress today".
    function calmMinutesSinceWake(secOfDay as Number, wakeSec) {
        if (!((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory))) { return null; }
        var start = (wakeSec != null) ? wakeSec : 6 * 3600;
        var window = secOfDay - start;
        if (window <= 0) { return 0; }
        var it = SensorHistory.getStressHistory({
            :period => new Time.Duration(window),
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        if (it == null) { return null; }
        var calmSec = 0;
        var prev = it.next();
        var cur = it.next();
        while (cur != null) {
            if (prev != null && prev.data != null && prev.data >= 0 && prev.data <= 25) {
                var dt = cur.when.value() - prev.when.value();
                if (dt > 0 && dt < 900) { calmSec += dt; }
            }
            prev = cur;
            cur = it.next();
        }
        return calmSec / 60;
    }
}
