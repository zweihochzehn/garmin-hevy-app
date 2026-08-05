import Toybox.Communications;
import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;

// Thin wrapper around the Hevy public REST API (https://api.hevyapp.com/docs/).
// Auth is a per-user API key sent in the "api-key" header. Requires Hevy Pro.
module HevyApi {
    const BASE = "https://api.hevyapp.com/v1";
    const PAGE_SIZE = 10;        // Hevy caps /v1/routines pageSize at 10
    const MAX_PAGES = 5;         // safety cap: 50 routines

    // Key entered on the watch is kept in Storage; a key set from the phone
    // lands in Properties. Both are normalized (hyphens/spaces stripped and
    // re-inserted canonically) so paste artifacts can't cause silent 401s.
    function apiKey() as String {
        var s = Application.Storage.getValue("hevyApiKey");
        var n = normalizeKey(s);
        if (n != null) { return n; }
        if (s != null && (s as String).length() > 0) { return s; }
        var p = Application.Properties.getValue("hevyApiKey");
        n = normalizeKey(p);
        if (n != null) { return n; }
        if (p == null) { return ""; }
        return p;
    }

    function hasKey() as Boolean {
        return apiKey().length() > 0;
    }

    function saveKey(key as String) as Void {
        Application.Storage.setValue("hevyApiKey", key);
    }

    // Removes the key from BOTH stores. Clearing only Storage would leave a
    // rejected phone-settings key in place, and hasKey() would stay true — the
    // setup screen would bounce straight back and the user could never fix it.
    function clearKey() as Void {
        Application.Storage.deleteValue("hevyApiKey");
        Application.Properties.setValue("hevyApiKey", "");
    }

    // True when the phone settings hold a (normalizable) key.
    function hasPhoneKey() as Boolean {
        return normalizeKey(Application.Properties.getValue("hevyApiKey")) != null;
    }

    // Normalizes user input into the canonical 8-4-4-4-12 key. Hyphens and
    // spaces are ignored on input (the watch keyboard has no "-"), so the user
    // can type just the 32 letters/digits and we insert the hyphens. Returns
    // the formatted key, or null if it isn't 32 alphanumerics.
    function normalizeKey(input as String or Null) as String or Null {
        if (input == null) { return null; }
        var core = stripAlnum(input);
        if (core.length() != 32) { return null; }
        return core.substring(0, 8) + "-" + core.substring(8, 12) + "-" +
               core.substring(12, 16) + "-" + core.substring(16, 20) + "-" +
               core.substring(20, 32);
    }

    function isAlnum(c as Char) as Boolean {
        var n = c.toNumber();
        return (n >= 48 && n <= 57) || (n >= 65 && n <= 90) || (n >= 97 && n <= 122);
    }

    // Keeps only letters/digits (drops hyphens, spaces, etc.).
    function stripAlnum(s as String or Null) as String {
        if (s == null) { return ""; }
        var out = "";
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (isAlnum(chars[i])) { out += chars[i].toString(); }
        }
        return out;
    }

    // Human-readable, localized message for a makeWebRequest response code.
    // Negative codes are Connect IQ transport errors (phone/BLE), positive
    // ones are HTTP statuses from Hevy.
    function errorText(code as Number) as String {
        var id;
        if (code == 401 || code == 403) { id = Rez.Strings.ErrKey; }
        else if (code == 429) { id = Rez.Strings.ErrRate; }
        else if (code >= 500) { id = Rez.Strings.ErrServer; }
        else if (code == Communications.NETWORK_REQUEST_TIMED_OUT) { id = Rez.Strings.ErrTimeout; }
        else if (code <= 0) { id = Rez.Strings.ErrPhone; }
        else {
            return (WatchUi.loadResource(Rez.Strings.ErrGeneric) as String) + " " + code;
        }
        return WatchUi.loadResource(id) as String;
    }

    function isKeyError(code as Number) as Boolean {
        return code == 401 || code == 403;
    }

    // GET /v1/routines (one page) — returns routines with exercises and sets
    // inline plus page/page_count. callback(code as Number, data as Dictionary or Null)
    function getRoutines(page as Number, callback as Method) as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "api-key" => apiKey(),
                "Accept" => "application/json"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(BASE + "/routines",
            { "page" => page, "pageSize" => PAGE_SIZE }, options, callback);
    }

    // POST /v1/workouts — logs a completed workout.
    // payload is the full { "workout": { ... } } dictionary.
    function postWorkout(payload as Dictionary, callback as Method) as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "api-key" => apiKey(),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(BASE + "/workouts", payload, options, callback);
    }

    // ---- Pending workouts (offline safety net) ------------------------------
    // A workout's payload is persisted as soon as it has logged sets and is
    // only removed after Hevy confirms (200/201). If saving fails or the user
    // leaves, the app offers to resend on the next launch.
    //
    // This is a QUEUE, not a single slot: finishing a second workout while the
    // first is still unsent must not overwrite the first.
    const MAX_PENDING = 5;

    function pendingList() as Array {
        var p = Application.Storage.getValue("pendingWorkout");
        if (p instanceof Lang.Array) { return p; }
        if (p instanceof Lang.Dictionary) { return [p]; }   // legacy single slot
        return [];
    }

    // Appends, or replaces the entry with the same start_time (so re-showing a
    // summary updates rather than duplicates).
    function savePending(payload as Dictionary) as Void {
        var list = pendingList();
        var key = startTimeOf(payload);
        for (var i = 0; i < list.size(); i++) {
            if (startTimeOf(list[i]).equals(key)) {
                list[i] = payload;
                Application.Storage.setValue("pendingWorkout", list);
                return;
            }
        }
        list.add(payload);
        while (list.size() > MAX_PENDING) { list.remove(list[0]); }
        Application.Storage.setValue("pendingWorkout", list);
    }

    function startTimeOf(payload as Dictionary or Null) as String {
        if (payload == null) { return ""; }
        var w = payload["workout"];
        if (w instanceof Lang.Dictionary && w["start_time"] != null) { return w["start_time"]; }
        return "";
    }

    // Oldest unsent workout, or null.
    function loadPending() as Dictionary or Null {
        var list = pendingList();
        if (list.size() == 0) { return null; }
        return list[0];
    }

    function pendingCount() as Number {
        return pendingList().size();
    }

    // Removes one specific workout (by start_time) once it is safely stored.
    function clearPending(payload as Dictionary or Null) as Void {
        var key = startTimeOf(payload);
        var list = pendingList();
        var out = [];
        for (var i = 0; i < list.size(); i++) {
            if (!startTimeOf(list[i]).equals(key)) { out.add(list[i]); }
        }
        if (out.size() == 0) {
            Application.Storage.deleteValue("pendingWorkout");
        } else {
            Application.Storage.setValue("pendingWorkout", out);
        }
    }

    function clearAllPending() as Void {
        Application.Storage.deleteValue("pendingWorkout");
    }
}
