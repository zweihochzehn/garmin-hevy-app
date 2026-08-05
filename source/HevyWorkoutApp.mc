import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point. Starts on the routine picker (or the key setup
// screen when no API key is configured). If unsent workouts from a previous
// session are pending, they are offered for resending first.
class HevyWorkoutApp extends Application.AppBase {
    public var recorder as Recorder;
    // The workout in progress, if any. Held here so onStop() can persist its
    // logged sets — the views are gone by then.
    public var session as WorkoutSession or Null;

    function initialize() {
        AppBase.initialize();
        recorder = new Recorder();
        session = null;
    }

    // Safety net on app exit: keep the logged sets for a later resend, save the
    // Garmin activity when sets were logged, and discard an empty recording.
    function onStop(state as Dictionary or Null) as Void {
        persistSession();
        if (recorder.hasData()) {
            recorder.saveAndClose();
        } else {
            recorder.discard();
        }
        session = null;
    }

    // Stash the current workout so nothing is lost. No-op for demo sessions,
    // without a key, or when nothing was logged.
    function persistSession() as Void {
        if (session == null) { return; }
        if (session.isDemo() || !HevyApi.hasKey()) { return; }
        if (session.totalCompleted() == 0) { return; }
        HevyApi.savePending(session.buildPayload());
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        if (HevyApi.hasKey()) {
            if (HevyApi.loadPending() != null) {
                var pv = new PendingView();
                return [pv, new PendingDelegate(pv)];
            }
            var view = new RoutineListView();
            return [view, new RoutineListDelegate(view)];
        }
        var setup = new SetupView(false);
        return [setup, new SetupDelegate(setup)];
    }

    // The user changed settings in the Garmin Connect phone app. If a key was
    // entered there, let it win over a stale watch-entered key and move on from
    // the setup/error screens — but never yank the user out of a workout that
    // is still running or waiting to be saved.
    function onSettingsChanged() as Void {
        if (session != null) {
            WatchUi.requestUpdate();
            return;
        }
        if (HevyApi.hasPhoneKey()) {
            Application.Storage.deleteValue("hevyApiKey");
        }
        if (HevyApi.hasKey()) {
            var view = new RoutineListView();
            WatchUi.switchToView(view, new RoutineListDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.requestUpdate();
        }
    }
}

// Convenience accessor.
function getApp() as HevyWorkoutApp {
    return Application.getApp() as HevyWorkoutApp;
}
