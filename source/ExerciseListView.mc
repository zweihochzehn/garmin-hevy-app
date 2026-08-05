import Toybox.WatchUi;
import Toybox.Lang;

// Screen 1b: the exercises of the chosen routine with per-exercise set
// progress ("2/3 sets"). Tapping an exercise jumps into its next open set.
// Rebuilt fresh on each entry so the progress counts are always current.
class ExerciseListView extends CardMenu {
    private var mSession as WorkoutSession;
    private var mSetsWord as String;

    function initialize(session as WorkoutSession) {
        CardMenu.initialize(session.title);
        mSession = session;
        mSetsWord = WatchUi.loadResource(Rez.Strings.SetsWord) as String;
        for (var i = 0; i < session.exerciseCount(); i++) {
            var ex = session.exercises[i] as Dictionary;
            var n = session.setCount(i);
            // Zero-set exercises are shown muted and are not selectable (and
            // never green — 0/0 is not "done").
            var done = n > 0 && session.completedCount(i) == n;
            var accent = Theme.BLUE;
            if (n == 0) { accent = Theme.LINE; }
            else if (done) { accent = Theme.GREEN; }
            var t = (ex["title"] != null) ? ex["title"] : "?";
            addItem(new CardMenuItem(i, t, progressLabel(i), accent, done));
        }
    }

    function progressLabel(i as Number) as String {
        return mSession.completedCount(i) + "/" + mSession.setCount(i) + " " + mSetsWord;
    }
}

class ExerciseListDelegate extends WatchUi.Menu2InputDelegate {
    private var mSession as WorkoutSession;

    function initialize(session as WorkoutSession) {
        Menu2InputDelegate.initialize();
        mSession = session;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var idx = item.getId() as Number;
        if (mSession.setCount(idx) == 0) {
            return; // exercise without sets — nothing to run (also: crash guard)
        }
        mSession.jumpToExercise(idx);
        Flow.showCurrentSet(mSession);
    }

    // Leaving the exercise list ends the workout. If sets were logged this is a
    // "finish early": go to the summary so the user can save them (which also
    // ends the recording and persists the payload). With nothing logged, just
    // discard the empty recording and leave — never let it keep running, since
    // that would block Garmin sleep tracking.
    function onBack() as Void {
        if (mSession.totalCompleted() > 0) {
            Flow.showSummary(mSession);
            return;
        }
        getApp().recorder.discard();
        getApp().session = null;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
