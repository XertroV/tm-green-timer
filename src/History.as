namespace History {

    string g_NewTimerName = "";
    string path = IO::FromStorageFolder("GreenTimerHistory.json");
    Json::Value allTimers = Json::Array();
    int activeIndex = -1;

    // Deletion confirmation state
    int pendingDeleteIndex = -1;
    string pendingDeleteName = "";
    vec4 pendingDeleteColor = vec4(1, 1, 1, 1);

    void DrawHistoryInner() {

        UI::SeparatorText("Create New Timer");

        UI::SetNextItemWidth(200);
        g_NewTimerName = UI::InputText("Name##HistoryNewTimer", g_NewTimerName);

        UI::SameLine(0, 6.f);

        if (UI::Button("Create Timer")) {
            startnew(CreateNewTimer);
        }

        UI::SameLine();
        if (UI::Button("Save Current Timer")) {
            startnew(SaveCurrentTimerAsNew);
        }

        UI::SeparatorText("Saved Timers (" + allTimers.Length + ")");

        if (allTimers.Length > 0) {
            if (UI::Button(Icons::Trash + " Delete All")) {
                UI::OpenPopup("Confirm Delete All##confirmDeleteAll");
            }
            if (UI::BeginPopupModal("Confirm Delete All##confirmDeleteAll", UI::WindowFlags::AlwaysAutoResize)) {
                UI::Text("\\$f80Warning: this will delete ALL " + allTimers.Length + " saved timers.");
                UI::Text("This cannot be undone.");
                UI::Separator();

                if (UI::Button("Yes, Delete All##confirmAllYes")) {
                    startnew(ClearHistory);
                    UI::CloseCurrentPopup();
                }
                UI::SameLine();
                if (UI::Button("Cancel##confirmAllNo")) {
                    UI::CloseCurrentPopup();
                }
                UI::EndPopup();
            }
        }

        // display all timers
        for (uint i = 0; i < allTimers.Length; i++) {
            UI::PushID("timer_" + i);

            Json::Value entry = allTimers[i];
            string name = string(entry["name"]);

            bool isActive = false;
            if (i == activeIndex) {
                isActive = true;
            }


            string timeStr;
            if (isActive) {
                timeStr = Time::Format(int(g_TimerMs), false, true, true);
            } else {
                Json::Value timeVal = entry["time"];
                timeStr = Time::Format(int(timeVal), false, true, true);
            }

            string dirIcon = "";
            Json::Value countUpVal = entry["countUp"];
            if (bool(countUpVal)) {
                dirIcon = Icons::ArrowUp;
            } else {
                dirIcon = Icons::ArrowDown;
            }

            // Use the saved timer color for the name
            vec4 entryColor = JsonToVec4(entry["color"]);
            string colorPrefix = Text::FormatOpenplanetColor(entryColor.xyz);

            UI::AlignTextToFramePadding();
            UI::Text(colorPrefix + name + " " + dirIcon);

            // Compute the width of the right-hand cluster: time text + 2 buttons.
            string playPauseIcon = isActive ? Icons::Pause : Icons::Play;
            string timeDisplay = "\\$999" + timeStr;
            vec2 framePadding = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
            float spacing      = 6.0f;
            float timeWidth    = UI::MeasureString(timeStr).x;
            float playBtnWidth = UI::MeasureString(playPauseIcon).x + framePadding.x * 2;
            float delBtnWidth  = UI::MeasureString(Icons::Trash).x + framePadding.x * 2;
            float rightWidth   = timeWidth + spacing + playBtnWidth + spacing + delBtnWidth;

            UI::SameLine();
            float available = UI::GetContentRegionAvail().x;
            if (available > rightWidth) {
                UI::Dummy(vec2(available - rightWidth, 0));
                UI::SameLine(0.0f, 0.0f);
            }

            // Time on the right
            UI::AlignTextToFramePadding();
            UI::Text(timeDisplay);
            UI::SameLine(0.0f, spacing);

            // Load/Stop button
            if (isActive) {
                if (UI::Button(playPauseIcon + "##load")) {
                    WriteCurrentSettingsToIndex(activeIndex);
                    S_TimerActive = false;
                    activeIndex = -1;
                    startnew(reloadTimers);
                }
            } else {
                if (UI::Button(playPauseIcon + "##load")) {
                    // Save the currently active timer before switching
                    WriteCurrentSettingsToIndex(activeIndex);
                    ReadSettingsFromIndex(i);
                    S_TimerActive = true;
                    activeIndex = i;
                }
            }
            UI::SameLine(0.0f, spacing);

            // Delete this timer (opens confirmation popup)
            if (UI::Button(Icons::Trash + "##del")) {
                pendingDeleteIndex = i;
                pendingDeleteName = name;
                pendingDeleteColor = entryColor;
            }

            UI::PopID();
        }

        if (allTimers.Length == 0) {
            UI::Text("\\$999No saved timers yet.");
        }

        // Single-timer delete confirmation popup.
        // OpenPopup is called here (outside the PushID loop) so the popup ID isn't scoped to a single row.
        if (pendingDeleteIndex >= 0) {
            UI::OpenPopup("Confirm Delete Timer##confirmDeleteOne");
        }
        if (UI::BeginPopupModal("Confirm Delete Timer##confirmDeleteOne", UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text("Are you sure you want to delete this timer?");
            UI::PushStyleColor(UI::Col::Text, pendingDeleteColor);
            UI::Text(pendingDeleteName);
            UI::PopStyleColor();
            UI::Separator();

            if (UI::Button("Yes, Delete##confirmOneYes")) {
                if (activeIndex == pendingDeleteIndex) {
                    activeIndex = -1;
                } else if (activeIndex > pendingDeleteIndex) {
                    activeIndex--;
                }

                allTimers.Remove(pendingDeleteIndex);
                pendingDeleteIndex = -1;
                pendingDeleteName = "";
                reloadTimers();
                UI::CloseCurrentPopup();
            }
            UI::SameLine();
            if (UI::Button("Cancel##confirmOneNo")) {
                pendingDeleteIndex = -1;
                pendingDeleteName = "";
                UI::CloseCurrentPopup();
            }
            UI::EndPopup();
        }
    }

    void CreateNewTimer() {
        string name = g_NewTimerName.Trim();
        if (name == "") {
            name = "Timer " + (allTimers.Length + 1);
        }
        Json::Value timerEntry = MakeDefaultEntry();
        timerEntry["name"] = name;
        allTimers.Add(timerEntry);
        g_NewTimerName = "";
        reloadTimers();
    }

    Json::Value MakeDefaultEntry() {
        Json::Value entry = Json::Object();
        entry["time"]              = 0;
        entry["align"]             = int(nvg::Align::Right | nvg::Align::Middle);
        entry["bg"]                = true;
        entry["color"]             = Vec4ToJson(cDefaultText);
        entry["pausedColor"]       = Vec4ToJson(cGray);
        entry["fontSize"]          = 120.0;
        entry["hideWhenUIOff"]     = false;
        entry["pauseInMenu"]       = true;
        entry["pauseInEditor"]     = false;
        entry["pauseWhileLoading"] = true;
        entry["countUp"]           = true;
        entry["notifyOnFinish"]    = true;
        return entry;
    }

    void SaveCurrentTimerAsNew() {
        string name = g_NewTimerName.Trim();
        if (name == "") {
            name = "Timer " + (allTimers.Length + 1);
        }
        Json::Value timerEntry = MakeDefaultEntry();
        timerEntry["name"] = name;
        allTimers.Add(timerEntry);
        WriteCurrentSettingsToIndex(allTimers.Length - 1);
        g_NewTimerName = "";
        reloadTimers();
    }

    Json::Value Vec4ToJson(vec4 v) {
        Json::Value arr = Json::Array();
        arr.Add(v.x);
        arr.Add(v.y);
        arr.Add(v.z);
        arr.Add(v.w);
        return arr;
    }

    vec4 JsonToVec4(Json::Value@ arr) {
        return vec4(float(double(arr[0])), float(double(arr[1])), float(double(arr[2])), float(double(arr[3])));
    }

    void WriteCurrentSettingsToIndex(int index) {
        allTimers[index]["time"]              = g_TimerMs;
        allTimers[index]["align"]             = S_GreenTimerAlign;
        allTimers[index]["bg"]                = S_GreenTimerBg;
        allTimers[index]["color"]             = Vec4ToJson(S_GreenTimerColor);
        allTimers[index]["pausedColor"]       = Vec4ToJson(S_GreenTimerPausedColor);
        allTimers[index]["fontSize"]          = S_GreenTimerFontSize;
        allTimers[index]["hideWhenUIOff"]     = S_HideWhenUIOff;
        allTimers[index]["pauseInMenu"]       = S_PauseInMenu;
        allTimers[index]["pauseInEditor"]     = S_PauseInEditor;
        allTimers[index]["pauseWhileLoading"] = S_PauseWhileLoading;
        allTimers[index]["countUp"]           = S_CountUp;
        allTimers[index]["notifyOnFinish"]    = S_NotifyOnFinish;
    }

    void ReadSettingsFromIndex(int index) {
        Json::Value entry = allTimers[index];
        g_TimerMs               = int64(double(entry["time"]));
        S_GreenTimerAlign       = int(entry["align"]);
        S_GreenTimerBg          = bool(entry["bg"]);
        S_GreenTimerColor       = JsonToVec4(entry["color"]);
        S_GreenTimerPausedColor = JsonToVec4(entry["pausedColor"]);
        S_GreenTimerFontSize    = float(double(entry["fontSize"]));
        S_HideWhenUIOff         = bool(entry["hideWhenUIOff"]);
        S_PauseInMenu           = bool(entry["pauseInMenu"]);
        S_PauseInEditor         = bool(entry["pauseInEditor"]);
        S_PauseWhileLoading     = bool(entry["pauseWhileLoading"]);
        S_CountUp               = bool(entry["countUp"]);
        S_NotifyOnFinish        = bool(entry["notifyOnFinish"]);
    }

    void loadTimers() {
        if (!IO::FileExists(path)) {
            IO::File file(path, IO::FileMode::Write);
            file.Write("[]");
            file.Close();
        }
        IO::File file(path, IO::FileMode::Read);
        allTimers = Json::Parse(file.ReadToEnd());
        file.Close();
    }

    void saveTimers() {
        IO::File file(path, IO::FileMode::Write);
        file.Write(Json::Write(allTimers));
        file.Close();
    }

    void ClearHistory() {
        allTimers = Json::Array();
        activeIndex = -1;
        reloadTimers();
    }

    void reloadTimers() {
        saveTimers();
        loadTimers();
    }

}