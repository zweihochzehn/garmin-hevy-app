import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// First screen: loads the user's Hevy routines (all pages) and hands off to a
// scrollable picker. Shows loading/error states with a real retry, a
// change-key path for auth failures, and the demo as an explicit fallback.
class RoutineListView extends WatchUi.View {
    private var mStatus as Symbol;      // :loading, :error, :empty
    private var mErrCode as Number;
    private var mRoutines as Array;
    private var mPage as Number;
    private var mPageCount as Number;
    private var mStarted as Boolean;

    private var mW as Number;
    private var mH as Number;
    private var mStrApp as String;
    private var mStrLoading as String;

    function initialize() {
        View.initialize();
        mStatus = :loading;
        mErrCode = 0;
        mRoutines = [];
        mPage = 1;
        mPageCount = 1;
        mStarted = false;
        var d = System.getDeviceSettings();
        mW = d.screenWidth;
        mH = d.screenHeight;
        mStrApp = WatchUi.loadResource(Rez.Strings.AppName) as String;
        mStrLoading = WatchUi.loadResource(Rez.Strings.Loading) as String;
    }

    function onShow() as Void {
        if (!mStarted) {
            mStarted = true;
            load();
        }
    }

    function load() as Void {
        mStatus = :loading;
        mRoutines = [];
        mPage = 1;
        mPageCount = 1;
        WatchUi.requestUpdate();
        if (!HevyApi.hasKey()) {
            // No key configured -> offline demo.
            showRoutines(SampleData.routines());
            return;
        }
        HevyApi.getRoutines(1, method(:onRoutines));
    }

    // Accumulates pages until page_count (or the safety cap) is reached.
    function onRoutines(code as Number, data as Dictionary or Null) as Void {
        if (code == 200 && data != null && data.hasKey("routines")) {
            var routines = data["routines"];
            if (routines instanceof Lang.Array) {
                for (var i = 0; i < routines.size(); i++) { mRoutines.add(routines[i]); }
            }
            var pc = data["page_count"];
            if (pc instanceof Lang.Number) { mPageCount = pc; }
            if (mPage < mPageCount && mPage < HevyApi.MAX_PAGES) {
                mPage += 1;
                WatchUi.requestUpdate();
                HevyApi.getRoutines(mPage, method(:onRoutines));
                return;
            }
            if (mRoutines.size() == 0) {
                mStatus = :empty;
                WatchUi.requestUpdate();
                return;
            }
            showRoutines(mRoutines);
        } else {
            mStatus = :error;
            mErrCode = code;
            WatchUi.requestUpdate();
        }
    }

    function showRoutines(routines as Array) as Void {
        var menu = new CardMenu(WatchUi.loadResource(Rez.Strings.Routines) as String);
        var exWord = WatchUi.loadResource(Rez.Strings.Exercises) as String;
        for (var i = 0; i < routines.size(); i++) {
            var r = routines[i] as Dictionary;
            var ex = r["exercises"];
            var n = (ex instanceof Lang.Array) ? ex.size() : 0;
            var t = (r["title"] != null) ? r["title"] : "?";
            menu.addItem(new CardMenuItem(i, t, n + " " + exWord,
                (n > 0) ? Theme.BLUE : Theme.LINE, false));
        }
        WatchUi.switchToView(menu, new RoutineMenuDelegate(routines), WatchUi.SLIDE_LEFT);
    }

    // Primary action depends on the state: retry the fetch, or — after an auth
    // failure — clear the watch key and reopen the setup screen.
    function primaryAction() as Void {
        if (mStatus == :error && HevyApi.isKeyError(mErrCode)) {
            HevyApi.clearKey();
            // force = true: the setup screen must stay put even if a key is
            // somehow still readable, or the user could never re-enter one.
            var v = new SetupView(true);
            WatchUi.switchToView(v, new SetupDelegate(v), WatchUi.SLIDE_LEFT);
            return;
        }
        if (mStatus == :error || mStatus == :empty) {
            load();
        }
    }

    function demoAction() as Void {
        if (mStatus == :error || mStatus == :empty) {
            showRoutines(SampleData.routines());
        }
    }

    function hit(x as Number, y as Number) as Symbol or Null {
        if (mStatus != :error && mStatus != :empty) { return null; }
        if (x >= (mW * 0.22).toNumber() && x <= (mW * 0.78).toNumber() &&
            y >= (mH * 0.52).toNumber() && y <= (mH * 0.67).toNumber()) { return :primary; }
        if (y >= (mH * 0.72).toNumber() && y <= (mH * 0.88).toNumber()) { return :demo; }
        return null;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.FG, Theme.BG);
        dc.clear();
        var cx = mW / 2;

        // App name instead of a big brand wordmark.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.14).toNumber(), Graphics.FONT_XTINY,
            Theme.fit(dc, mStrApp, (mW * 0.6).toNumber(), Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (mStatus == :loading) {
            var msg = mStrLoading;
            // Show the pages we will actually load, not the server total.
            var shown = (mPageCount < HevyApi.MAX_PAGES) ? mPageCount : HevyApi.MAX_PAGES;
            if (shown > 1) { msg = msg + " (" + mPage + "/" + shown + ")"; }
            dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 0.5).toNumber(), Graphics.FONT_TINY,
                Theme.fit(dc, msg, (mW * 0.8).toNumber(), Graphics.FONT_TINY),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Error / empty state.
        var text;
        var primary;
        if (mStatus == :empty) {
            text = WatchUi.loadResource(Rez.Strings.NoRoutines) as String;
            primary = WatchUi.loadResource(Rez.Strings.RetryLabel) as String;
        } else if (HevyApi.isKeyError(mErrCode)) {
            text = HevyApi.errorText(mErrCode);
            primary = WatchUi.loadResource(Rez.Strings.ChangeKey) as String;
        } else {
            text = HevyApi.errorText(mErrCode);
            primary = WatchUi.loadResource(Rez.Strings.RetryLabel) as String;
        }

        var maxW = (mW * 0.78).toNumber();
        var tf = Theme.bestFont(dc, text, maxW, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.36).toNumber(), tf, Theme.fit(dc, text, maxW, tf),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Primary pill.
        var x0 = (mW * 0.22).toNumber();
        var x1 = (mW * 0.78).toNumber();
        var y0 = (mH * 0.52).toNumber();
        var y1 = (mH * 0.67).toNumber();
        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, x1 - x0, y1 - y0, (y1 - y0) / 2);
        dc.setColor(Theme.FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (y0 + y1) / 2, Graphics.FONT_TINY, primary,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Demo fallback.
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 0.80).toNumber(), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.StartDemo) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Delegate for the loading/error view.
class RoutineListDelegate extends WatchUi.InputDelegate {
    private var mView as RoutineListView;

    function initialize(view as RoutineListView) {
        InputDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var zone = mView.hit(c[0], c[1]);
        if (zone == :primary) { mView.primaryAction(); }
        else if (zone == :demo) { mView.demoAction(); }
        return true;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) { mView.primaryAction(); return true; }
        return false;
    }
}

// Delegate for the scrollable routine picker. Selecting a routine starts a
// workout session and opens the exercise list.
class RoutineMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var mRoutines as Array;

    function initialize(routines as Array) {
        Menu2InputDelegate.initialize();
        mRoutines = routines;
    }

    // History arrived (or failed) — a failure just means no "last time" hints.
    function onHistory(code as Number, data as Dictionary or Null) as Void {
        if (code == 200) {
            getApp().history.ingest(data);
            WatchUi.requestUpdate();
        }
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var idx = item.getId() as Number;
        var r = mRoutines[idx] as Dictionary;
        var ex = r["exercises"];
        if (!(ex instanceof Lang.Array) || ex.size() == 0) {
            return; // routine without exercises — nothing to start
        }
        var session = new WorkoutSession(r);
        getApp().session = session;
        // Begin the Garmin activity recording (HR/calories -> Garmin Connect).
        // Demo runs never touch the user's Garmin history.
        if (!session.isDemo()) {
            getApp().recorder.start(session.title);
            // Fetch "what did I lift last time" in the background — the set
            // screens pick it up as soon as it lands.
            getApp().history.clear();
            if (HevyApi.hasKey()) {
                HevyApi.getRecentWorkouts(method(:onHistory));
            }
        }
        WatchUi.pushView(
            new ExerciseListView(session),
            new ExerciseListDelegate(session),
            WatchUi.SLIDE_LEFT);
    }
}
