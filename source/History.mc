import Toybox.Lang;

// "What did I lift last time?" — the most recent performed sets per exercise.
//
// Built from GET /v1/workouts (newest first), which returns every exercise and
// set of each workout. One request covers every exercise of the routine, which
// matters on a watch: the alternative, GET /v1/exercise_history/{id}, would be
// one request per exercise and returns the entire history, unbounded in size.
//
// Only the FIRST workout containing an exercise is kept — that is the most
// recent one, because the list is ordered newest first.
class History {
    private var mMap as Dictionary;    // template id -> Array of { :w, :r }
    private var mLoaded as Boolean;

    function initialize() {
        mMap = {};
        mLoaded = false;
    }

    function isLoaded() as Boolean { return mLoaded; }

    function clear() as Void {
        mMap = {};
        mLoaded = false;
    }

    // Feed a /v1/workouts response. Safe against missing/odd fields.
    function ingest(data as Dictionary or Null) as Void {
        mLoaded = true;
        if (data == null) { return; }
        var workouts = data["workouts"];
        if (!(workouts instanceof Lang.Array)) { return; }

        for (var w = 0; w < workouts.size(); w++) {
            var workout = workouts[w];
            if (!(workout instanceof Lang.Dictionary)) { continue; }
            var exercises = workout["exercises"];
            if (!(exercises instanceof Lang.Array)) { continue; }

            for (var e = 0; e < exercises.size(); e++) {
                var ex = exercises[e];
                if (!(ex instanceof Lang.Dictionary)) { continue; }
                var id = ex["exercise_template_id"];
                if (id == null || mMap.hasKey(id)) { continue; }   // newest wins

                var sets = ex["sets"];
                if (!(sets instanceof Lang.Array)) { continue; }
                var out = [];
                for (var s = 0; s < sets.size(); s++) {
                    var st = sets[s];
                    if (!(st instanceof Lang.Dictionary)) { continue; }
                    // Warm-up sets are not a meaningful target.
                    if ("warmup".equals(st["type"])) { continue; }
                    if (st["weight_kg"] == null && st["reps"] == null) { continue; }
                    out.add({ :w => st["weight_kg"], :r => st["reps"] });
                }
                if (out.size() > 0) { mMap.put(id, out); }
            }
        }
    }

    // All performed sets of the last session for this exercise, or null.
    function sets(templateId as String or Null) as Array or Null {
        if (templateId == null || !mMap.hasKey(templateId)) { return null; }
        return mMap.get(templateId);
    }

    // The matching set of the last session (set 1 -> set 1, …). Falls back to
    // the last available set when the routine now has more sets than last time.
    function setAt(templateId as String or Null, index as Number) as Dictionary or Null {
        var list = sets(templateId);
        if (list == null || list.size() == 0) { return null; }
        if (index < list.size()) { return list[index]; }
        return list[list.size() - 1];
    }
}
