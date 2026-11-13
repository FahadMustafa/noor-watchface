import Toybox.Lang;
import Toybox.Test;

// Expected values: api.aladhan.com, method 4 (Umm al-Qura), Riyadh 24.7136N 46.6753E, UTC+3.
(:test)
function prayerTimesMatchUmmAlQura(logger as Logger) as Boolean {
    var cases = [
        [2026, 11, 13, ["04:47", "06:08", "11:38", "14:46", "17:07", "18:37"]],
        [2026, 6, 21, ["03:33", "05:05", "11:55", "15:16", "18:45", "20:15"]],
        [2027, 2, 20, ["05:05", "06:24", "12:07", "15:23", "17:50", "19:50"]], // Ramadan: Isha +120
    ];
    var ok = true;
    for (var c = 0; c < cases.size(); c++) {
        var cs = cases[c] as Array;
        var got = Prayer.times(Prayer.daysFromCivil(cs[0] as Number, cs[1] as Number, cs[2] as Number), 24.7136d, 46.6753d, 3.0d);
        var want = cs[3] as Array<String>;
        for (var i = 0; i < 6; i++) {
            var w = want[i];
            var wm = ((w.substring(0, 2) as String).toNumber() as Number) * 60 + ((w.substring(3, 5) as String).toNumber() as Number);
            var g = got[i] as Number;
            if ((g - wm).abs() > 1) {
                logger.error(Lang.format("$1$-$2$-$3$ idx $4$: got $5$ want $6$", [cs[0], cs[1], cs[2], i, g, wm]));
                ok = false;
            }
        }
    }
    return ok;
}

(:test)
function calendarHelpers(logger as Logger) as Boolean {
    return Prayer.daysFromCivil(1970, 1, 1) == 0
        && Prayer.daysFromCivil(2000, 3, 1) == 11017
        && Prayer.hijriMonth(Prayer.daysFromCivil(2027, 2, 20)) == 9
        && Prayer.hijriMonth(Prayer.daysFromCivil(2026, 11, 13)) == 6;
}
