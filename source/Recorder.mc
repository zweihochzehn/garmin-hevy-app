import Toybox.Lang;
import Toybox.ActivityRecording;
import Toybox.Activity;

// Wraps a Garmin activity recording for the workout. Recording a
// STRENGTH_TRAINING session makes the watch capture heart rate, calories and
// time and sync them to Garmin Connect on save. (Hevy's API has no HR field,
// so HR/calories only go to Garmin Connect; the structured sets go to Hevy.)
class Recorder {
    private var mSession as ActivityRecording.Session or Null;
    private var mHasData as Boolean;

    function initialize() {
        mSession = null;
        mHasData = false;
    }

    function start(title as String) as Void {
        if (mSession != null) { return; }
        if (!(Toybox has :ActivityRecording)) { return; }
        mSession = ActivityRecording.createSession({
            :sport => Activity.SPORT_TRAINING,
            :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING,
            :name => title
        });
        mSession.start();
        mHasData = false;
    }

    // Called when the user actually logs a set — an empty recording (browsed a
    // routine, exited) is discarded instead of polluting Garmin Connect.
    function markData() as Void {
        mHasData = true;
    }

    function hasData() as Boolean {
        return mHasData;
    }

    function isRecording() as Boolean {
        return mSession != null && mSession.isRecording();
    }

    // Stop and persist the activity -> syncs to Garmin Connect.
    // Returns true if an activity was actually saved.
    function saveAndClose() as Boolean {
        if (mSession != null) {
            if (mSession.isRecording()) { mSession.stop(); }
            mSession.save();
            mSession = null;
            return true;
        }
        return false;
    }

    // Stop and throw away (used when the workout is abandoned early).
    function discard() as Void {
        if (mSession != null) {
            if (mSession.isRecording()) { mSession.stop(); }
            mSession.discard();
            mSession = null;
        }
    }
}
