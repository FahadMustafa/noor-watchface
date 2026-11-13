import Toybox.Lang;
import Toybox.Math;

// Prayer times as computed by api.aladhan.com (praytimes.org sun formulas, Shafi Asr,
// angle-based high-latitude rule). Everything in Doubles: 32-bit Floats lose minutes.
module Prayer {
    const FAJR = 0;
    const SUNRISE = 1;
    const DHUHR = 2;
    const ASR = 3;
    const MAGHRIB = 4;
    const ISHA = 5;

    // Calculation methods, parameters from api.aladhan.com/v1/methods.
    const MAKKAH = 0;  // Umm al-Qura
    const MWL = 1;
    const ISNA = 2;
    const EGYPT = 3;
    const KARACHI = 4;
    const KUWAIT = 5;
    const QATAR = 6;
    const DUBAI = 7;
    const JORDAN = 8;
    const TURKEY = 9;
    const SEA = 10;    // JAKIM / MUIS / Kemenag share 20 / 18
    const FAJR_ANGLE = [18.5d, 18.0d, 15.0d, 19.5d, 18.0d, 18.0d, 18.0d, 18.2d, 18.0d, 18.0d, 20.0d];
    const ISHA_ANGLE = [0.0d, 17.0d, 15.0d, 17.5d, 18.0d, 17.5d, 0.0d, 18.2d, 18.0d, 17.0d, 18.0d]; // 0 = fixed minutes
    const ISHA_MINUTES = [90, 0, 0, 0, 0, 0, 90, 0, 0, 0, 0];
    const MAGHRIB_MINUTES = [0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0];
    // Per-prayer adjustments [fajr, sunrise, dhuhr, asr, maghrib, isha] in minutes.
    const TUNE = [null, null, null, null, null, null, null, [0, 0, 3, 0, 3, 0], null, [0, -7, 5, 4, 7, 0], null];

    // [latMin, latMax, lngMin, lngMax, method]; first match wins, so carve-outs come first. Else MWL.
    // ponytail: bounding boxes, so a town near a border can get the neighbour's method (a few
    // minutes on Fajr/Isha). Swap in country polygons if that ever matters.
    const REGIONS = [
        [28.5d, 30.1d, 46.5d, 48.5d, KUWAIT],
        [24.4d, 26.4d, 50.3d, 51.7d, QATAR],   // Qatar, Bahrain
        [22.6d, 26.1d, 51.5d, 56.4d, DUBAI],   // UAE
        [16.6d, 26.4d, 55.7d, 60.0d, DUBAI],   // Oman
        [30.0d, 37.4d, 42.5d, 48.6d, MWL],     // Iraq south of the KSA box edge
        [29.5d, 31.6d, 36.8d, 39.3d, MAKKAH],  // Qurayyat, Tabarjal (inside the Jordan box)
        [29.5d, 33.4d, 35.0d, 39.3d, JORDAN],
        [27.0d, 32.2d, 34.5d, 55.7d, MAKKAH],  // KSA north of Duba
        [16.3d, 27.0d, 36.5d, 55.7d, MAKKAH],  // KSA south, east of the Red Sea
        [22.0d, 31.7d, 24.7d, 37.0d, EGYPT],
        [36.0d, 42.1d, 26.0d, 44.8d, TURKEY],
        [5.0d, 37.1d, 60.9d, 92.7d, KARACHI],  // Pakistan, India, Bangladesh
        [-11.0d, 7.5d, 95.0d, 141.0d, SEA],    // Malaysia, Singapore, Indonesia, Brunei
        [14.0d, 72.0d, -170.0d, -52.0d, ISNA], // North America
    ];

    function methodFor(lat as Double, lng as Double) as Number {
        for (var i = 0; i < REGIONS.size(); i++) {
            var r = REGIONS[i] as Array;
            if (lat >= (r[0] as Double) && lat <= (r[1] as Double) && lng >= (r[2] as Double) && lng <= (r[3] as Double)) {
                return r[4] as Number;
            }
        }
        return MWL;
    }

    // Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's days_from_civil).
    function daysFromCivil(y as Number, m as Number, d as Number) as Number {
        if (m <= 2) { y -= 1; }
        var era = (y >= 0 ? y : y - 399) / 400;
        var yoe = y - era * 400;
        var doy = (153 * ((m + 9) % 12) + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // Umm al-Qura month starts (days since 1970-01-01) from 1 Muharram 1447 to 1 Muharram 1471,
    // taken from the hijridate package and checked against api.aladhan.com for 2026-2027.
    const HIJRI_FIRST_YEAR = 1447;
    const MONTH_STARTS = [
        20265, 20295, 20324, 20354, 20384, 20414, 20443, 20473, 20502, 20532, 20561, 20591,
        20620, 20649, 20679, 20708, 20738, 20768, 20797, 20827, 20857, 20886, 20916, 20945,
        20975, 21004, 21033, 21063, 21092, 21122, 21151, 21181, 21211, 21240, 21270, 21300,
        21329, 21359, 21388, 21418, 21447, 21476, 21506, 21535, 21565, 21594, 21624, 21654,
        21683, 21713, 21743, 21772, 21802, 21831, 21860, 21890, 21919, 21949, 21978, 22008,
        22037, 22067, 22097, 22127, 22156, 22186, 22215, 22244, 22274, 22303, 22333, 22362,
        22392, 22421, 22451, 22481, 22511, 22540, 22569, 22599, 22628, 22658, 22687, 22717,
        22746, 22775, 22805, 22835, 22865, 22894, 22924, 22953, 22983, 23012, 23042, 23071,
        23101, 23130, 23159, 23189, 23219, 23248, 23278, 23307, 23337, 23367, 23396, 23426,
        23455, 23485, 23514, 23543, 23573, 23602, 23632, 23661, 23691, 23721, 23751, 23780,
        23810, 23839, 23869, 23898, 23927, 23957, 23986, 24015, 24045, 24075, 24104, 24134,
        24164, 24194, 24223, 24253, 24282, 24311, 24341, 24370, 24399, 24429, 24459, 24488,
        24518, 24548, 24578, 24607, 24637, 24666, 24695, 24725, 24754, 24783, 24813, 24843,
        24872, 24902, 24932, 24961, 24991, 25020, 25050, 25079, 25109, 25138, 25167, 25197,
        25227, 25256, 25286, 25315, 25345, 25375, 25404, 25434, 25463, 25493, 25522, 25552,
        25581, 25611, 25640, 25670, 25699, 25729, 25758, 25788, 25817, 25847, 25877, 25906,
        25936, 25965, 25995, 26024, 26053, 26083, 26112, 26142, 26172, 26201, 26231, 26261,
        26290, 26320, 26349, 26379, 26408, 26437, 26467, 26496, 26526, 26555, 26585, 26615,
        26645, 26674, 26704, 26733, 26763, 26792, 26821, 26851, 26880, 26909, 26939, 26969,
        26999, 27029, 27058, 27088, 27117, 27147, 27176, 27205, 27235, 27264, 27294, 27323,
        27353, 27383, 27412, 27442, 27472, 27501, 27531, 27560, 27589, 27619, 27648, 27678,
        27707, 27737, 27766, 27796, 27826, 27855, 27885, 27914, 27944, 27973, 28003, 28032,
        28062, 28091, 28120, 28150, 28180, 28209, 28239, 28269, 28298, 28328, 28358, 28387,
        28416, 28446, 28475, 28504, 28534, 28564, 28593, 28623, 28652, 28682, 28712, 28742,
        28771
    ];

    // [year, month, day] in the Umm al-Qura calendar, or null outside 1447-1470 AH (2025-2048).
    function hijri(days as Number) as Array<Number>? {
        var hi = MONTH_STARTS.size() - 1;
        if (days < (MONTH_STARTS[0] as Number) || days >= (MONTH_STARTS[hi] as Number)) { return null; }
        var lo = 0; // MONTH_STARTS[lo] <= days < MONTH_STARTS[hi]
        while (hi - lo > 1) {
            var mid = (lo + hi) / 2;
            if ((MONTH_STARTS[mid] as Number) <= days) { lo = mid; } else { hi = mid; }
        }
        return [HIJRI_FIRST_YEAR + lo / 12, lo % 12 + 1, days - (MONTH_STARTS[lo] as Number) + 1];
    }

    // Minutes after local midnight for [fajr, sunrise, dhuhr, asr, maghrib, isha];
    // an entry is null when the sun never reaches that angle (polar day or night).
    function times(days as Number, lat as Double, lng as Double, tzHours as Double, method as Number) as Array<Number?> {
        var fa = FAJR_ANGLE[method] as Double;
        var ia = ISHA_ANGLE[method] as Double;
        // Days since J2000 at local midnight, shifted to local mean time.
        var d0 = days - 10957.5d - lng / 360.0d;
        var fajr = sunAngleTime(d0, lat, fa, 5.0d, true);
        var sunrise = sunAngleTime(d0, lat, 0.833d, 6.0d, true);
        var sunset = sunAngleTime(d0, lat, 0.833d, 18.0d, false);
        var isha = ia > 0.0d ? sunAngleTime(d0, lat, ia, 18.0d, false) : null;

        // High latitudes: Fajr/Isha no further than angle/60 of the night from sunrise/sunset.
        if (sunrise != null && sunset != null) {
            var night = fixHour(sunrise - sunset);
            var p = fa / 60.0d * night;
            if (fajr == null || fixHour(sunrise - fajr) > p) { fajr = sunrise - p; }
            p = ia / 60.0d * night;
            if (ia > 0.0d && (isha == null || fixHour(isha - sunset) > p)) { isha = sunset + p; }
        }

        var raw = [fajr, sunrise, midDay(d0, 12.0d), asrTime(d0, lat, 13.0d), sunset, isha] as Array<Double?>;
        var tune = TUNE[method] as Array<Number>?;
        var shift = tzHours - lng / 15.0d;
        var out = new Array<Number?>[6];
        for (var i = 0; i < 6; i++) {
            var h = raw[i];
            if (h != null) {
                out[i] = Math.round((h + shift) * 60.0d).toNumber() + (tune == null ? 0 : tune[i]);
            }
        }
        var maghrib = out[MAGHRIB];
        if (maghrib != null) {
            maghrib += MAGHRIB_MINUTES[method] as Number;
            out[MAGHRIB] = maghrib;
            if (ia == 0.0d) {
                var hd = hijri(days);
                var ramadan = method == MAKKAH && hd != null && hd[1] == 9;
                out[ISHA] = maghrib + (ISHA_MINUTES[method] as Number) + (ramadan ? 30 : 0);
            }
        }
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
