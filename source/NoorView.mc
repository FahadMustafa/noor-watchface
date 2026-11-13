import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.SensorHistory;
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
const C_SUNRISE = 0xFFAA55;
const C_HEART = 0xFF5555;
const C_BODY = 0x55AAFF;
const C_STEPS = 0xAAAAFF;
const C_FIRE = 0xFFAA00;
const C_ALERT = 0xFF5555;

const PRAYER_NAMES = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
const HIJRI_MONTHS = ["Muharram", "Safar", "Rabi I", "Rabi II", "Jumada I", "Jumada II",
    "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhul Qa'dah", "Dhul Hijjah"];

const LEFT = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

class NoorView extends WatchUi.WatchFace {
    private var _time as FontResource?;
    private var _label as FontResource?;
    private var _value as FontResource?;
    private var _small as FontResource?;
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
        _small = WatchUi.loadResource(Rez.Fonts.Small) as FontResource;
        _icons = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
    }

    function onUpdate(dc as Dc) as Void {
        var time = _time as FontResource;
        var label = _label as FontResource;
        var value = _value as FontResource;
        var small = _small as FontResource;
        var icons = _icons as FontResource;
        var cx = dc.getWidth() / 2;
        var clock = System.getClockTime();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = Prayer.daysFromCivil(now.year as Number, now.month as Number, now.day as Number);
        var mins = clock.hour * 60 + clock.min;

        dc.setColor(C_BG, C_BG);
        dc.clear();
        dc.setAntiAlias(true);

        // Next prayer, countdown, and a rim arc from the previous prayer to it
        var next = nextPrayer(clock, now, days);
        if (next != null) {
            var idx = next[0] as Number;
            var at = next[1] as Number;
            var prev = next[2] as Number?;
            var name = idx == Prayer.DHUHR && (now.day_of_week as Number) == 6 ? "Jumuah" : PRAYER_NAMES[idx] as String;
            var color = idx == Prayer.SUNRISE ? C_SUNRISE : C_PRAYER;
            var atText = hm12(at);
            var nameW = dc.getTextWidthInPixels(name, label);
            var x = cx - (20 + 5 + nameW + 7 + dc.getTextWidthInPixels(atText, label)) / 2;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, 35, icons, idx == Prayer.SUNRISE ? "U" : "M", LEFT);
            dc.drawText(x + 25, 35, label, name, LEFT);
            dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + 25 + nameW + 7, 35, label, atText, LEFT);

            var left = at - mins;
            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 55, small, left == 0 ? "now" : left < 60 ? "in " + left + "m" : "in " + left / 60 + "h " + left % 60 + "m", CENTER);

            gauge(dc, cx, 135, -90, prev == null ? 0.0 : (mins - prev).toFloat() / (at - prev), color);
        } else {
            dc.setColor(C_FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 35, label, "No location yet", CENTER);
            gauge(dc, cx, 135, -90, 0.0, C_PRAYER);
        }

        // Date line: weekday dd/mm, then the Umm al-Qura Hijri date
        var weekday = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week as String;
        var date = Lang.format("$1$/$2$", [(now.day as Number).format("%02d"), (now.month as Number).format("%02d")]);
        var h = Prayer.hijri(days);
        var hijri = h == null ? "" : h[2] + " " + HIJRI_MONTHS[h[1] - 1];
        var wdW = dc.getTextWidthInPixels(weekday, label);
        var dW = dc.getTextWidthInPixels(date, label);
        var dx = cx - (wdW + 5 + dW + (h == null ? 0 : 9 + dc.getTextWidthInPixels(hijri, small))) / 2;
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dx, 76, label, weekday, LEFT);
        dc.drawText(dx + wdW + 5 + dW + 9, 77, small, hijri, LEFT);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dx + wdW + 5, 76, label, date, LEFT);

        // Time, 12h, AM/PM at the top right; a phone-off marker below it when disconnected
        var hr12 = clock.hour % 12;
        var hhmm = Lang.format("$1$:$2$", [hr12 == 0 ? 12 : hr12, clock.min.format("%02d")]);
        var ampm = clock.hour < 12 ? "AM" : "PM";
        var tW = dc.getTextWidthInPixels(hhmm, time);
        var tx = cx - (tW + 4 + dc.getTextWidthInPixels(ampm, label)) / 2;
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, 117, time, hhmm, LEFT);
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx + tW + 4, 100, label, ampm, LEFT);
        if (!System.getDeviceSettings().phoneConnected) {
            dc.setColor(C_ALERT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx + tW + 2, 130, icons, "P", LEFT);
        }

        dc.setColor(C_FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 60, 149, cx + 60, 149);

        // Heart rate, Body Battery, steps
        var act = ActivityMonitor.getInfo();
        metric(dc, cx - 70, "H", C_HEART, fmt(heartRate()), icons, value);
        metric(dc, cx, "B", C_BODY, fmt(bodyBattery()), icons, value);
        metric(dc, cx + 70, "S", C_STEPS, fmt(act.steps), icons, value);

        // Calories and battery
        var kcal = fmt(act.calories);
        var batt = System.getSystemStats().battery;
        var pct = batt.format("%d") + "%";
        var kW = dc.getTextWidthInPixels(kcal, label);
        var bx = cx - (18 + kW + 12 + 21 + 4 + dc.getTextWidthInPixels(pct, label)) / 2;
        dc.setColor(C_FIRE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx - 2, 207, icons, "F", LEFT);
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx + 18, 207, label, kcal, LEFT);
        bx += 18 + kW + 12;
        var col = batt <= 20 ? C_ALERT : C_DIM;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, 202, 19, 10, 2);
        dc.fillRectangle(bx + 19, 205, 2, 4);
        dc.fillRectangle(bx + 2, 204, (15 * batt / 100).toNumber(), 6);
        dc.drawText(bx + 25, 207, label, pct, LEFT);
        gauge(dc, cx, 235, 70, batt / 100, col);
    }

    private function metric(dc as Dc, x as Number, icon as String, color as Number, text as String,
            icons as FontResource, value as FontResource) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 163, icons, icon, CENTER);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 184, value, text, CENTER);
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

    // [prayer index, minutes, previous prayer minutes or null] for the next prayer or sunrise,
    // on one axis from today's midnight (tomorrow's Fajr is +1440). Null without a location.
    private function nextPrayer(clock as System.ClockTime, now as Gregorian.Info, days as Number) as Array? {
        updateLocation();
        var loc = _loc;
        if (loc == null) { return null; }
        var key = days + "," + loc[0] + "," + loc[1] + "," + clock.timeZoneOffset;
        if (!key.equals(_cacheKey)) {
            var tz = clock.timeZoneOffset / 3600.0d;
            var method = Prayer.methodFor(loc[0], loc[1]);
            _today = Prayer.times(days, loc[0], loc[1], tz, method);
            _tomorrowFajr = Prayer.times(days + 1, loc[0], loc[1], tz, method)[Prayer.FAJR];
            _cacheKey = key;
        }
        var mins = clock.hour * 60 + clock.min;
        var isha = _today[Prayer.ISHA];
        var prev = isha == null ? null : isha - 1440; // yesterday's Isha, near enough
        for (var i = Prayer.FAJR; i <= Prayer.ISHA; i++) {
            var t = _today[i];
            if (t == null) { continue; }
            if (t >= mins) { return [i, t, prev]; }
            prev = t;
        }
        var fajr = _tomorrowFajr;
        return fajr == null ? null : [Prayer.FAJR, fajr + 1440, prev];
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

    private function bodyBattery() as Number? {
        var sample = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}).next();
        var v = sample != null ? sample.data : null;
        return v == null ? null : v.toNumber();
    }

    private function fmt(n as Number?) as String {
        return n == null ? "--" : n.toString();
    }

    private function hm12(mins as Number) as String {
        var h = (mins / 60) % 12;
        return Lang.format("$1$:$2$", [h == 0 ? 12 : h, (mins % 60).format("%02d")]);
    }
}
