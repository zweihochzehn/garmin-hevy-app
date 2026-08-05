import Toybox.Lang;
import Toybox.WatchUi;

// Central navigation for the guided-workout state machine. Views call into
// these helpers instead of pushing each other directly, so the alternation of
// exercise -> rest -> next exercise lives in one place.
module Flow {

    // Show the current set: a rep/weight screen, or the timer screen for
    // time-based (Plank) and distance-based (Running, Farmers Walk) sets.
    function showCurrentSet(session as WorkoutSession) as Void {
        var set = session.currentSet();
        if (set == null) {
            // Exercise without sets — reroute to the next real set, or finish.
            var nxt = session.firstIncomplete();
            if (nxt == null) {
                showSummary(session);
                return;
            }
            session.exIndex = nxt[0];
            session.setIndex = nxt[1];
            set = session.currentSet();
            if (set == null) { return; }
        }
        if (WorkoutSession.isDurationSet(set) || WorkoutSession.isDistanceSet(set)) {
            var v = new DurationSetView(session);
            WatchUi.switchToView(v, new DurationSetDelegate(v), WatchUi.SLIDE_LEFT);
        } else {
            var sv = new SetView(session);
            WatchUi.switchToView(sv, new SetDelegate(sv), WatchUi.SLIDE_LEFT);
        }
    }

    // Called after the user confirms a set (the view has already logged it).
    // Advances to the next incomplete set, inserting a rest screen when the
    // just-finished exercise defines a rest period.
    function afterSetConfirmed(session as WorkoutSession) as Void {
        var restEx = session.currentExercise();
        var nxt = session.firstIncomplete();
        if (nxt == null) {
            showSummary(session);
            return;
        }
        session.exIndex = nxt[0];
        session.setIndex = nxt[1];

        var rest = restEx["rest_seconds"];
        if (rest != null && rest > 0) {
            var rv = new RestView(session, rest);
            WatchUi.switchToView(rv, new RestDelegate(rv, rest), WatchUi.SLIDE_LEFT);
        } else {
            showCurrentSet(session);
        }
    }

    function showSummary(session as WorkoutSession) as Void {
        var sv = new SummaryView(session);
        WatchUi.switchToView(sv, new SummaryDelegate(sv), WatchUi.SLIDE_LEFT);
    }
}
