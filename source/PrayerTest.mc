import Toybox.Lang;
import Toybox.Test;

// Expected values from api.aladhan.com (latitudeAdjustmentMethod=3, the method given).
// [y, m, d, lat, lng, tz hours, method, [fajr, sunrise, dhuhr, asr, maghrib, isha]]
(:test)
function prayerTimesMatchAladhan(logger as Logger) as Boolean {
    var cases = [
        [2026, 11, 13, 24.7136d, 46.6753d, 3.0d, Prayer.MAKKAH, ["04:47", "06:08", "11:38", "14:46", "17:07", "18:37"]],
        [2026, 6, 21, 24.7136d, 46.6753d, 3.0d, Prayer.MAKKAH, ["03:33", "05:05", "11:55", "15:16", "18:45", "20:15"]],
        [2027, 2, 20, 24.7136d, 46.6753d, 3.0d, Prayer.MAKKAH, ["05:05", "06:24", "12:07", "15:23", "17:50", "19:50"]], // Ramadan
        [2026, 6, 21, 51.5072d, -0.1276d, 1.0d, Prayer.MWL, ["02:31", "04:43", "13:02", "17:25", "21:22", "23:27"]], // high latitude
        [2026, 11, 13, 51.5072d, -0.1276d, 0.0d, Prayer.MWL, ["05:18", "07:15", "11:45", "13:52", "16:14", "18:04"]],
        [2026, 6, 21, 40.7128d, -74.0060d, -4.0d, Prayer.ISNA, ["03:45", "05:25", "12:58", "16:58", "20:31", "22:11"]],
        [2026, 11, 13, 40.7128d, -74.0060d, -5.0d, Prayer.ISNA, ["05:22", "06:41", "11:40", "14:19", "16:40", "17:58"]],
        [2026, 6, 21, 30.0444d, 31.2357d, 3.0d, Prayer.EGYPT, ["04:08", "05:54", "12:57", "16:32", "19:59", "21:33"]],
        [2026, 11, 13, 30.0444d, 31.2357d, 2.0d, Prayer.EGYPT, ["04:49", "06:18", "11:39", "14:40", "17:00", "18:20"]],
        [2026, 6, 21, 25.2048d, 55.2708d, 4.0d, Prayer.DUBAI, ["03:59", "05:29", "12:24", "15:43", "19:15", "20:43"]],
        [2026, 11, 13, 25.2048d, 55.2708d, 4.0d, Prayer.DUBAI, ["05:14", "06:34", "12:06", "15:10", "17:35", "18:52"]],
        [2026, 6, 21, 31.9539d, 35.9106d, 3.0d, Prayer.JORDAN, ["03:51", "05:31", "12:38", "16:18", "19:50", "21:26"]],
        [2026, 11, 13, 31.9539d, 35.9106d, 3.0d, Prayer.JORDAN, ["05:39", "07:03", "12:21", "15:18", "17:43", "19:02"]],
        [2026, 6, 21, 29.3759d, 47.9774d, 3.0d, Prayer.KUWAIT, ["03:13", "04:49", "11:50", "15:24", "18:51", "20:23"]],
        [2026, 11, 13, 29.3759d, 47.9774d, 3.0d, Prayer.KUWAIT, ["04:48", "06:10", "11:32", "14:34", "16:54", "18:14"]],
        [2026, 6, 21, 1.3521d, 103.8198d, 8.0d, Prayer.SEA, ["05:36", "07:00", "13:06", "16:33", "19:13", "20:28"]],
        [2026, 11, 13, 1.3521d, 103.8198d, 8.0d, Prayer.SEA, ["05:27", "06:47", "12:49", "16:13", "18:51", "20:03"]],
        [2026, 6, 21, 24.8607d, 67.0011d, 5.0d, Prayer.KARACHI, ["04:14", "05:43", "12:34", "15:55", "19:24", "20:53"]],
        [2026, 11, 13, 24.8607d, 67.0011d, 5.0d, Prayer.KARACHI, ["05:28", "06:47", "12:16", "15:25", "17:45", "19:04"]],
        [2026, 6, 21, 25.2854d, 51.5310d, 3.0d, Prayer.QATAR, ["03:15", "04:44", "11:36", "14:58", "18:27", "19:57"]],
        [2026, 11, 13, 25.2854d, 51.5310d, 3.0d, Prayer.QATAR, ["04:30", "05:49", "11:18", "14:25", "16:47", "18:17"]],
    ];
    var ok = true;
    for (var c = 0; c < cases.size(); c++) {
        var cs = cases[c] as Array;
        var days = Prayer.daysFromCivil(cs[0] as Number, cs[1] as Number, cs[2] as Number);
        var got = Prayer.times(days, cs[3] as Double, cs[4] as Double, cs[5] as Double, cs[6] as Number);
        var want = cs[7] as Array<String>;
        for (var i = 0; i < 6; i++) {
            var w = want[i];
            var wm = ((w.substring(0, 2) as String).toNumber() as Number) * 60 + ((w.substring(3, 5) as String).toNumber() as Number);
            var g = got[i];
            if (g == null || (g - wm).abs() > 1) {
                logger.error(Lang.format("case $1$ idx $2$: got $3$ want $4$", [c, i, g, wm]));
                ok = false;
            }
        }
    }
    return ok;
}

// The method aladhan picks for each city's country.
(:test)
function methodFollowsLocation(logger as Logger) as Boolean {
    var cases = [
        [24.7136d, 46.6753d, Prayer.MAKKAH],  // Riyadh
        [21.4858d, 39.1925d, Prayer.MAKKAH],  // Jeddah
        [26.4207d, 50.0888d, Prayer.MAKKAH],  // Dammam
        [31.3320d, 37.3400d, Prayer.MAKKAH],  // Qurayyat
        [30.9753d, 41.0381d, Prayer.MAKKAH],  // Arar
        [25.2048d, 55.2708d, Prayer.DUBAI],
        [23.5880d, 58.3829d, Prayer.DUBAI],   // Muscat
        [25.2854d, 51.5310d, Prayer.QATAR],   // Doha
        [26.2285d, 50.5860d, Prayer.QATAR],   // Manama
        [29.3759d, 47.9774d, Prayer.KUWAIT],
        [31.9539d, 35.9106d, Prayer.JORDAN],  // Amman
        [30.0444d, 31.2357d, Prayer.EGYPT],   // Cairo
        [41.0082d, 28.9784d, Prayer.TURKEY],  // Istanbul
        [24.8607d, 67.0011d, Prayer.KARACHI],
        [1.3521d, 103.8198d, Prayer.SEA],     // Singapore
        [40.7128d, -74.0060d, Prayer.ISNA],   // New York
        [51.5072d, -0.1276d, Prayer.MWL],     // London
        [30.5085d, 47.7804d, Prayer.MWL],     // Basra
    ];
    var ok = true;
    for (var i = 0; i < cases.size(); i++) {
        var cs = cases[i] as Array;
        var got = Prayer.methodFor(cs[0] as Double, cs[1] as Double);
        if (got != cs[2]) {
            logger.error(Lang.format("case $1$: got $2$ want $3$", [i, got, cs[2]]));
            ok = false;
        }
    }
    return ok;
}

(:test)
function calendarHelpers(logger as Logger) as Boolean {
    var h = Prayer.hijri(Prayer.daysFromCivil(2026, 11, 13)) as Array<Number>;
    var r1 = Prayer.hijri(Prayer.daysFromCivil(2027, 2, 8)) as Array<Number>;
    var r0 = Prayer.hijri(Prayer.daysFromCivil(2027, 2, 7)) as Array<Number>;
    var last = Prayer.hijri(Prayer.daysFromCivil(2048, 10, 8)) as Array<Number>;
    return Prayer.daysFromCivil(1970, 1, 1) == 0
        && Prayer.daysFromCivil(2000, 3, 1) == 11017
        && h[0] == 1448 && h[1] == 6 && h[2] == 3
        && r1[0] == 1448 && r1[1] == 9 && r1[2] == 1
        && r0[1] == 8 && r0[2] == 30
        && last[0] == 1470 && last[1] == 12 && last[2] == 29
        && Prayer.hijri(Prayer.daysFromCivil(2048, 10, 9)) == null
        && Prayer.hijri(Prayer.daysFromCivil(2025, 6, 25)) == null;
}
