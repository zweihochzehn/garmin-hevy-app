import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Holds the live state of one guided workout: which exercise/set is current
// and the actual values the user confirmed for each set. Also builds the
// payload for POST /v1/workouts.
//
// Defensive about API data: a missing exercises array, a missing sets array,
// or a missing title must never crash the app (the Hevy API permits all of
// them via API-created routines).
class WorkoutSession {
    public var title as String;
    public var exercises as Array;               // from the routine, sets normalized
    public var exIndex as Number;
    public var setIndex as Number;
    public var startMoment as Time.Moment;
    private var done as Array;                   // done[ei][si] = Dictionary or null
    private var mDemo as Boolean;

    function initialize(routine as Dictionary) {
        var t = routine["title"];
        title = (t != null) ? t : "Workout";
        var ex = routine["exercises"];
        exercises = (ex instanceof Lang.Array) ? ex : [];
        mDemo = "demo".equals(routine["id"]);
        exIndex = 0;
        setIndex = 0;
        startMoment = Time.now();
        done = [];
        for (var i = 0; i < exercises.size(); i++) {
            var n = setCount(i);
            var row = new [n];
            for (var j = 0; j < n; j++) { row[j] = null; }
            done.add(row);
        }
        // Start at the first set of the first exercise.
        var f = firstIncomplete();
        if (f != null) { exIndex = f[0]; setIndex = f[1]; }
    }

    // Demo sessions are never posted to Hevy and never persisted.
    function isDemo() as Boolean { return mDemo; }

    function exerciseCount() as Number { return exercises.size(); }
    function currentExercise() as Dictionary { return exercises[exIndex]; }

    // Title of the current exercise, never null (drawing it would crash).
    function currentTitle() as String {
        var t = (exercises[exIndex] as Dictionary)["title"];
        return (t != null) ? t : "?";
    }

    function currentSets() as Array {
        var sets = (exercises[exIndex] as Dictionary)["sets"];
        return (sets instanceof Lang.Array) ? sets : [];
    }

    // Null when the current exercise has no sets (callers must handle it).
    function currentSet() as Dictionary or Null {
        var sets = currentSets();
        if (setIndex >= sets.size()) { return null; }
        return sets[setIndex];
    }

    function setCount(ei as Number) as Number {
        var sets = (exercises[ei] as Dictionary)["sets"];
        return (sets instanceof Lang.Array) ? sets.size() : 0;
    }

    function completedCount(ei as Number) as Number {
        var c = 0;
        var row = done[ei] as Array;
        for (var j = 0; j < row.size(); j++) {
            if (row[j] != null) { c++; }
        }
        return c;
    }

    function totalSets() as Number {
        var t = 0;
        for (var i = 0; i < exercises.size(); i++) { t += setCount(i); }
        return t;
    }

    function totalCompleted() as Number {
        var t = 0;
        for (var i = 0; i < exercises.size(); i++) { t += completedCount(i); }
        return t;
    }

    // Planned reps for a set, or null. Hevy's routine editor stores rep
    // RANGES ("8-12") as rep_range {start, end} with reps = null, so a set
    // counts as a rep set when either field is present; the range's lower
    // bound is the planned value.
    static function plannedReps(set as Dictionary) as Number or Null {
        var r = set["reps"];
        if (r != null) { return r; }
        var rr = set["rep_range"];
        if (rr instanceof Lang.Dictionary) {
            var s = rr["start"];
            if (s != null) { return s.toNumber(); }
            var e = rr["end"];
            if (e != null) { return e.toNumber(); }
        }
        return null;
    }

    static function isDurationSet(set as Dictionary) as Boolean {
        return set["duration_seconds"] != null && plannedReps(set) == null;
    }

    // Planned reps can arrive either as a fixed `reps` value or as a
    // `rep_range` ({start, end}) — Hevy routines commonly use the range for
    // bodyweight work ("10-15 reps"). Returns [start, end] or null.
    static function repRange(set as Dictionary) as Array or Null {
        var r = set["rep_range"];
        if (!(r instanceof Lang.Dictionary)) { return null; }
        var s = r["start"];
        var e = r["end"];
        if (s == null && e == null) { return null; }
        return [s, e];
    }

    // A whole exercise counts as bodyweight when no set plans a weight — the
    // set screen then drops the weight column entirely.
    function exerciseHasWeight(ei as Number) as Boolean {
        var sets = (exercises[ei] as Dictionary)["sets"];
        if (!(sets instanceof Lang.Array)) { return false; }
        for (var i = 0; i < sets.size(); i++) {
            var s = sets[i];
            if (s instanceof Lang.Dictionary && s["weight_kg"] != null) { return true; }
        }
        return false;
    }

    // Distance sets (e.g. Running, Farmers Walk) have distance_meters and no
    // reps; they run on the timer screen and the distance is passed through.
    static function isDistanceSet(set as Dictionary) as Boolean {
        return set["distance_meters"] != null && plannedReps(set) == null;
    }

    // First incomplete set in routine order, or null when all are done.
    // Empty exercises have no slots and are skipped naturally.
    function firstIncomplete() as Array or Null {
        for (var ei = 0; ei < exercises.size(); ei++) {
            var row = done[ei] as Array;
            for (var si = 0; si < row.size(); si++) {
                if (row[si] == null) { return [ei, si]; }
            }
        }
        return null;
    }

    // Point the cursor at a specific exercise's first incomplete set (used when
    // the user taps an exercise in the list). Falls back to set 0.
    function jumpToExercise(ei as Number) as Void {
        exIndex = ei;
        var row = done[ei] as Array;
        for (var si = 0; si < row.size(); si++) {
            if (row[si] == null) { setIndex = si; return; }
        }
        setIndex = 0;
    }

    // Record actual values for the current set. Null fields are omitted from
    // the payload later, so a bodyweight set can carry a null weight.
    function logCurrent(weightKg as Float or Null, reps as Number or Null,
                        durationSec as Number or Null, distanceM as Number or Null) as Void {
        var set = currentSet();
        if (set == null) { return; }
        var row = done[exIndex] as Array;
        row[setIndex] = {
            "type" => set["type"],
            "weight_kg" => weightKg,
            "reps" => reps,
            "duration_seconds" => durationSec,
            "distance_meters" => distanceM
        };
        getApp().recorder.markData();
    }

    function isComplete() as Boolean {
        return firstIncomplete() == null;
    }

    function elapsedSeconds() as Number {
        return Time.now().subtract(startMoment).value();
    }

    // Build the POST /v1/workouts body from the sets actually completed.
    // Privacy: is_private comes from the app setting (default true) so the
    // app never publishes to the user's feed without an explicit opt-in.
    function buildPayload() as Dictionary {
        var exOut = [];
        for (var ei = 0; ei < exercises.size(); ei++) {
            var setsOut = [];
            var row = done[ei] as Array;
            for (var si = 0; si < row.size(); si++) {
                var d = row[si] as Dictionary or Null;
                if (d == null) { continue; }
                // "type" must never be null — Hevy rejects the whole workout.
                var s = { "type" => (d["type"] != null) ? d["type"] : "normal" };
                if (d["weight_kg"] != null) { s["weight_kg"] = d["weight_kg"]; }
                if (d["reps"] != null) { s["reps"] = d["reps"]; }
                if (d["duration_seconds"] != null) { s["duration_seconds"] = d["duration_seconds"]; }
                if (d["distance_meters"] != null) { s["distance_meters"] = d["distance_meters"]; }
                setsOut.add(s);
            }
            if (setsOut.size() == 0) { continue; }
            // Without a template id Hevy 400s the whole workout — skip instead.
            var tid = (exercises[ei] as Dictionary)["exercise_template_id"];
            if (tid == null) { continue; }
            exOut.add({
                "exercise_template_id" => tid,
                "sets" => setsOut
            });
        }
        var priv = Application.Properties.getValue("privateWorkouts");
        if (priv == null) { priv = true; }
        return {
            "workout" => {
                "title" => title,
                "start_time" => isoUtc(startMoment),
                "end_time" => isoUtc(Time.now()),
                "is_private" => priv,
                "exercises" => exOut
            }
        };
    }

    static function isoUtc(moment as Time.Moment) as String {
        var g = Gregorian.utcInfo(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$T$4$:$5$:$6$Z", [
            g.year.format("%04d"), g.month.format("%02d"), g.day.format("%02d"),
            g.hour.format("%02d"), g.min.format("%02d"), g.sec.format("%02d")
        ]);
    }
}
