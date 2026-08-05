import Toybox.Lang;

// Bundled demo routine mirroring the Hevy Apple Watch screenshot ("Chest day").
// Reachable from the setup screen and as a fallback, so the full flow is
// testable offline. Demo sessions are NEVER posted to Hevy (SummaryView checks
// WorkoutSession.isDemo()), so the template ids are deliberately fake.
module SampleData {

    function routines() as Array<Dictionary> {
        return [ chestDay() ];
    }

    function chestDay() as Dictionary {
        return {
            "id"       => "demo",
            "title"    => "Chest day",
            "exercises" => [
                {
                    "index"    => 0,
                    "title"    => "Bench Press (Barbell)",
                    "rest_seconds" => 90,
                    "exercise_template_id" => "DEMO0001",
                    "sets" => [
                        normalSet(0, 20.0, 8),
                        normalSet(1, 20.0, 8),
                        normalSet(2, 20.0, 8)
                    ]
                },
                {
                    "index"    => 1,
                    "title"    => "Chest Press (Machine)",
                    "rest_seconds" => 90,
                    "exercise_template_id" => "DEMO0002",
                    "sets" => [
                        normalSet(0, 30.0, 10),
                        normalSet(1, 30.0, 10),
                        normalSet(2, 30.0, 10)
                    ]
                },
                {
                    "index"    => 2,
                    "title"    => "Plank",
                    "rest_seconds" => 60,
                    "exercise_template_id" => "DEMO0003",
                    "sets" => [
                        durationSet(0, 30, "warmup"),
                        durationSet(1, 60, "normal"),
                        durationSet(2, 60, "normal")
                    ]
                }
            ]
        };
    }

    function normalSet(idx as Number, kg as Float, reps as Number) as Dictionary {
        return {
            "index" => idx, "type" => "normal",
            "weight_kg" => kg, "reps" => reps,
            "duration_seconds" => null
        };
    }

    function durationSet(idx as Number, secs as Number, type as String) as Dictionary {
        return {
            "index" => idx, "type" => type,
            "weight_kg" => null, "reps" => null,
            "duration_seconds" => secs
        };
    }
}
