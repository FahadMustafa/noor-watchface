import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// MIP 64-colour palette: every channel is 00, 55, AA or FF.
const C_BG = 0x000000;
const C_TEXT = 0xFFFFFF;
const C_DIM = 0xAAAAAA;
const C_FAINT = 0x555555;
const C_PRAYER = 0x55FFAA;
const C_HEART = 0xFF5555;
const C_FIRE = 0xFFAA00;
const C_STEPS = 0x55AAFF;
const C_LOW = 0xFF5555;

const PRAYER_NAMES = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];

class NoorView extends WatchUi.WatchFace {
    private var _time as FontResource?;
    private var _label as FontResource?;
    private var _value as FontResource?;
    private var _icons as FontResource?;

    // [lat, lng] in degrees, persisted so prayer times survive a restart without a fresh fix.
    private var _loc as Array<Double>?;
    private var _cacheKey as String = "";
    private var _today as Array<Number?> = [] as Array<Number?>;
    private var _tomorrowFajr as Number? = null;

    function initialize() {
        WatchFace.initialize();
        _loc = Storage.getValue("loc") as Array<Double>?;
    }

    function onLayout(dc as Dc) as Void {
        _time = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        _label = WatchUi.loadResource(Rez.Fonts.Label) as FontResource;
        _value = WatchUi.loadResource(Rez.Fonts.Value) as FontResource;
        _icons = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
    }

    function onUpdate(dc as Dc) as Void {
        var time = _time as FontResource;
        var label = _label as FontResource;
        var value = _value as FontResource;
        var icons = _icons as FontResource;
        var cx = dc.getWidth() / 2;
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        dc.setColor(C_BG, C_BG);
        dc.clear();
        dc.setAntiAlias(true);

        // Next prayer
        var next = nextPrayer(clock, now);
        if (next != null) {
            var name = next[0] as String;
            var at = hm12(next[1] as Number);
            var nameW = dc.getTextWidthInPixels(name, label);
            var x = cx - (20 + 5 + nameW + 7 + dc.getTextWidthInPixels(at, label)) / 2;
            dc.setColor(C_PRAYER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, 38, icons, "M", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(x + 25, 38, label, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + 25 + nameW + 7, 38, label, at, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Top rim: how far we are from the previous prayer to the next one
            var prev = next[2] as Number?;
            var t = next[1] as Number;
            var mins = clock.hour * 60 + clock.min;
            gauge(dc, cx, 135, -90, prev == null ? 0.0 : (mins - prev).toFloat() / (t - prev), C_PRAYER);
        } else {
            dc.setColor(C_FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 38, label, "No location yet", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Date: weekday dd/mm
        var weekday = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week as String;
        var date = Lang.format("$1$/$2$", [(now.day as Number).format("%02d"), (now.month as Number).format("%02d")]);
        var wdW = dc.getTextWidthInPixels(weekday, label);
        var dx = cx - (wdW + 6 + dc.getTextWidthInPixels(date, label)) / 2;
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dx, 68, label, weekday, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dx + wdW + 6, 68, label, date, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Time, 12h, with AM/PM tucked at the top right of the minutes
        var h = clock.hour % 12;
        var hhmm = Lang.format("$1$:$2$", [h == 0 ? 12 : h, clock.min.format("%02d")]);
        var ampm = clock.hour < 12 ? "AM" : "PM";
        var tW = dc.getTextWidthInPixels(hhmm, time);
        var tx = cx - (tW + 4 + dc.getTextWidthInPixels(ampm, label)) / 2;
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, 110, time, hhmm, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx + tW + 4, 93, label, ampm, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(C_FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 60, 145, cx + 60, 145);

        // Heart rate, calories, steps
        var act = ActivityMonitor.getInfo();
        metric(dc, cx - 70, "H", C_HEART, fmt(heartRate()), icons, value);
        metric(dc, cx, "F", C_FIRE, fmt(act.calories), icons, value);
        metric(dc, cx + 70, "S", C_STEPS, fmt(act.steps), icons, value);

        // Battery
        var batt = System.getSystemStats().battery;
        var pct = batt.format("%d") + "%";
        var bx = cx - (22 + 5 + dc.getTextWidthInPixels(pct, label)) / 2;
        var col = batt <= 20 ? C_LOW : C_DIM;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(bx, 205, 19, 10, 2);
        dc.fillRectangle(bx + 19, 208, 2, 4);
        dc.fillRectangle(bx + 2, 207, (15 * batt / 100).toNumber(), 6);
        dc.drawText(bx + 27, 210, label, pct, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        gauge(dc, cx, 225, 90, batt / 100, col);
    }

    // Thin arc along the rim: faint track over `sweep` degrees from `start`, filled to `frac`.
    // Angles follow Dc.drawArc: 0 = 3 o'clock, positive = counter-clockwise.
    private function gauge(dc as Dc, cx as Number, start as Number, sweep as Number, frac as Float, color as Number) as Void {
        var dir = sweep < 0 ? Graphics.ARC_CLOCKWISE : Graphics.ARC_COUNTER_CLOCKWISE;
        dc.setPenWidth(3);
        dc.setColor(C_FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cx, cx - 4, dir, start, start + sweep);
        var fill = (sweep * (frac < 0.0 ? 0.0 : frac > 1.0 ? 1.0 : frac)).toNumber();
        if (fill != 0) { // drawArc with start == end draws a full circle
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cx, cx - 4, dir, start, start + fill);
        }
        dc.setPenWidth(1);
    }

    private function metric(dc as Dc, x as Number, icon as String, color as Number, text as String,
            icons as FontResource, value as FontResource) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 162, icons, icon, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 185, value, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // [name, minutes after midnight, previous prayer minutes or null] of the next prayer, or null without a location.
    private function nextPrayer(clock as System.ClockTime, now as Gregorian.Info) as Array? {
        updateLocation();
        var loc = _loc;
        if (loc == null) { return null; }
        var days = Prayer.daysFromCivil(now.year as Number, now.month as Number, now.day as Number);
        var key = days + "," + loc[0] + "," + loc[1] + "," + clock.timeZoneOffset;
        if (!key.equals(_cacheKey)) {
            var tz = clock.timeZoneOffset / 3600.0d;
            _today = Prayer.times(days, loc[0], loc[1], tz);
            _tomorrowFajr = Prayer.times(days + 1, loc[0], loc[1], tz)[Prayer.FAJR];
            _cacheKey = key;
        }
        // Minutes on one axis from today's midnight: yesterday's Isha is ~ today's minus a day.
        var mins = clock.hour * 60 + clock.min;
        var isha = _today[Prayer.ISHA];
        var prev = isha == null ? null : isha - 1440;
        var order = [Prayer.FAJR, Prayer.DHUHR, Prayer.ASR, Prayer.MAGHRIB, Prayer.ISHA];
        for (var i = 0; i < order.size(); i++) {
            var t = _today[order[i]];
            if (t == null) { continue; }
            if (t >= mins) {
                var friday = (now.day_of_week as Number) == 6;
                return [order[i] == Prayer.DHUHR && friday ? "Jumuah" : PRAYER_NAMES[order[i]], t, prev];
            }
            prev = t;
        }
        return _tomorrowFajr == null ? null : ["Fajr", (_tomorrowFajr as Number) + 1440, prev];
    }

    // Last known position: the watch's last GPS fix, else the activity's, else the weather report's.
    private function updateLocation() as Void {
        var pos = Position.getInfo().position;
        if (pos == null) {
            var info = Activity.getActivityInfo();
            pos = info != null ? info.currentLocation : null;
        }
        if (pos == null) {
            var wx = Weather.getCurrentConditions();
            pos = wx != null ? wx.observationLocationPosition : null;
        }
        if (pos == null) { return; }
        var d = pos.toDegrees();
        var lat = d[0] as Double;
        var lng = d[1] as Double;
        if (lat.abs() > 90.0d || (lat == 0.0d && lng == 0.0d)) { return; } // invalid fix sentinels
        var old = _loc;
        // ~1 km moves don't change prayer times by a minute; skip the flash write.
        if (old == null || (old[0] - lat).abs() > 0.01d || (old[1] - lng).abs() > 0.01d) {
            _loc = [lat, lng] as Array<Double>;
            Storage.setValue("loc", _loc as Array<Storage.ValueType>);
        }
    }

    private function heartRate() as Number? {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) { return info.currentHeartRate; }
        var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) { return sample.heartRate; }
        return null;
    }

    private function fmt(n as Number?) as String {
        return n == null ? "--" : n.toString();
    }

    private function hm12(mins as Number) as String {
        var h = (mins / 60) % 12;
        return Lang.format("$1$:$2$", [h == 0 ? 12 : h, (mins % 60).format("%02d")]);
    }
}
