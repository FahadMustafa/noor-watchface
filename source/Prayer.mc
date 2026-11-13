import Toybox.Lang;
import Toybox.Math;

// Prayer times, Umm al-Qura method (Saudi Arabia): Fajr at 18.5° depression, Asr at shadow
// factor 1, Maghrib at sunset, Isha 90 min after Maghrib (120 min in Ramadan).
// Sun position formulas from praytimes.org. Everything in Doubles: 32-bit Floats lose minutes.
module Prayer {
    const FAJR = 0;
    const SUNRISE = 1;
    const DHUHR = 2;
    const ASR = 3;
    const MAGHRIB = 4;
    const ISHA = 5;

    // Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's days_from_civil).
    function daysFromCivil(y as Number, m as Number, d as Number) as Number {
        if (m <= 2) { y -= 1; }
        var era = (y >= 0 ? y : y - 399) / 400;
        var yoe = y - era * 400;
        var doy = (153 * ((m + 9) % 12) + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // Hijri month (1-12) from the tabular Islamic calendar.
    // ponytail: tabular calendar can be a day off the Umm al-Qura one, so Isha may be 30 min off
    // on the first or last day of Ramadan; embed the Umm al-Qura month table if that matters.
    function hijriMonth(days as Number) as Number {
        var l = days + 2440588 - 1948440 + 10632;
        var n = (l - 1) / 10631;
        l = l - 10631 * n + 354;
        var j = ((10985 - l) / 5316) * ((50 * l) / 17719) + (l / 5670) * ((43 * l) / 15238);
        l = l - ((30 - j) / 15) * ((17719 * j) / 50) - (j / 16) * ((15238 * j) / 43) + 29;
        return (24 * l) / 709;
    }

    // Minutes after local midnight for [fajr, sunrise, dhuhr, asr, maghrib, isha];
    // an entry is null when the sun never reaches that angle (polar latitudes).
    function times(days as Number, lat as Double, lng as Double, tzHours as Double) as Array<Number?> {
        // Days since J2000 at local midnight, shifted to local mean time.
        var d0 = days - 10957.5d - lng / 360.0d;
        var t = [
            sunAngleTime(d0, lat, 18.5d, 5.0d, true),
            sunAngleTime(d0, lat, 0.833d, 6.0d, true),
            midDay(d0, 12.0d),
            asrTime(d0, lat, 13.0d),
            sunAngleTime(d0, lat, 0.833d, 18.0d, false),
        ] as Array<Double?>;
        var out = new Array<Number?>[6];
        for (var i = 0; i < 5; i++) {
            var h = t[i];
            // Nearest minute, like the published tables; expect +-1 min against any one of them.
            out[i] = h == null ? null : Math.round((h + tzHours - lng / 15.0d) * 60.0d).toNumber();
        }
        var maghrib = out[MAGHRIB];
        out[ISHA] = maghrib == null ? null : maghrib + (hijriMonth(days) == 9 ? 120 : 90);
        return out;
    }

    // [declination°, equation of time in hours] at d days since J2000.
    function sun(d as Double) as Array<Double> {
        var g = fixAngle(357.529d + 0.98560028d * d);
        var q = fixAngle(280.459d + 0.98564736d * d);
        var l = fixAngle(q + 1.915d * dsin(g) + 0.020d * dsin(2.0d * g));
        var e = 23.439d - 0.00000036d * d;
        var ra = fixHour(Math.toDegrees(Math.atan2(dcos(e) * dsin(l), dcos(l))) / 15.0d);
        return [Math.toDegrees(Math.asin(dsin(e) * dsin(l))), q / 15.0d - ra] as Array<Double>;
    }

    function midDay(d0 as Double, guess as Double) as Double {
        return fixHour(12.0d - sun(d0 + guess / 24.0d)[1]);
    }

    function sunAngleTime(d0 as Double, lat as Double, angle as Double, guess as Double, beforeNoon as Boolean) as Double? {
        var decl = sun(d0 + guess / 24.0d)[0];
        var c = (-dsin(angle) - dsin(decl) * dsin(lat)) / (dcos(decl) * dcos(lat));
        if (c < -1.0d || c > 1.0d) { return null; }
        var t = Math.toDegrees(Math.acos(c)) / 15.0d;
        var noon = midDay(d0, guess);
        return beforeNoon ? noon - t : noon + t;
    }

    function asrTime(d0 as Double, lat as Double, guess as Double) as Double? {
        var decl = sun(d0 + guess / 24.0d)[0];
        var x = 1.0d + Math.tan(Math.toRadians((lat - decl).abs()));
        return sunAngleTime(d0, lat, -(Math.toDegrees(Math.atan(1.0d / x)) as Double), guess, false);
    }

    function dsin(a as Double) as Double { return Math.sin(Math.toRadians(a)) as Double; }
    function dcos(a as Double) as Double { return Math.cos(Math.toRadians(a)) as Double; }
    function fixAngle(a as Double) as Double { return a - 360.0d * Math.floor(a / 360.0d); }
    function fixHour(a as Double) as Double { return a - 24.0d * Math.floor(a / 24.0d); }
}
