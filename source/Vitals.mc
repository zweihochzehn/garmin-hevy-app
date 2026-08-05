import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityMonitor;

// Live sensor readouts. During an active recording, Activity.getActivityInfo()
// gives the real-time heart rate and calories; otherwise we fall back to the
// activity-monitor heart-rate history.
module Vitals {

    function heartRate() as Number or Null {
        if (Toybox has :Activity) {
            var info = Activity.getActivityInfo();
            if (info != null && info.currentHeartRate != null) {
                return info.currentHeartRate;
            }
        }
        var hist = ActivityMonitor.getHeartRateHistory(1, true);
        if (hist != null) {
            var s = hist.next();
            if (s != null && s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return s.heartRate;
            }
        }
        return null;
    }

    function calories() as Number or Null {
        if (Toybox has :Activity) {
            var info = Activity.getActivityInfo();
            if (info != null && info.calories != null) {
                return info.calories;
            }
        }
        return null;
    }
}
