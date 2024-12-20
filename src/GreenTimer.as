[Setting hidden]
bool S_ShowGreenTimer = true;

[Setting hidden]
vec2 S_GreenTimerPos = vec2(0.95, 0.5);

[Setting hidden]
int S_GreenTimerAlign = nvg::Align::Right | nvg::Align::Middle;

[Setting hidden]
bool S_GreenTimerBg = true;

const vec4 cDefaultText = vec4(0.14f, 0.74f, 0.3f, 1.f);

[Setting hidden]
vec4 S_GreenTimerColor = cDefaultText;

[Setting hidden]
vec4 S_GreenTimerPausedColor = cGray;

[Setting hidden]
float S_GreenTimerFontSize = 120.;

[Setting hidden]
bool S_DragableMode = false;

[Setting hidden]
bool S_TimerActive = true;

[Setting hidden]
bool S_HideWhenUIOff = false;

[Setting hidden]
bool S_PauseInMenu = true;

[Setting hidden]
bool S_PauseInEditor = false;

[Setting hidden]
bool S_PauseWhileLoading = true;

[Setting hidden]
bool S_CountUp = true;

[Setting hidden]
bool S_NotifyOnFinish = true;

[Setting hidden]
int64 g_TimerMs = 0;

int f_Nvg_ExoBold = nvg::LoadFont("Exo-Bold.ttf", true, true);

namespace GreenTimer {
    vec2[] extraPos = {};

    float vScale;
    const float stdHeightPx = 1440.0;

    uint lastRenderTime = 0;
    bool pausedThisFrame = false;
    void Update() {
        if (!S_TimerActive || IsTempPaused()) {
            lastRenderTime = Time::Now;
            pausedThisFrame = true;
            return;
        }
        uint64 delta;
        delta = lastRenderTime == 0 ? 0 : Time::Now - lastRenderTime;
        lastRenderTime = Time::Now;
        int sign = g_TimerMs < 0 ? -1 : 1;
        if (S_CountUp) {
            g_TimerMs += delta;
        } else {
            g_TimerMs -= delta;
        }
        int signAfter = g_TimerMs < 0 ? -1 : 1;
        pausedThisFrame = false;

        if (sign != signAfter) {
            if (S_NotifyOnFinish) {
                UI::ShowNotification("Timer reached 0", "\n\n\t\tTIMER DONE!\n\n\n", S_GreenTimerColor, 5000);
            }
        }
    }

    string tmpPauseReason = "";

    // Pause during loading, menu, editor, map, etc
    bool IsTempPaused() {
        auto app = GetApp();
        if (tmpEditingPauseActive) {
            tmpPauseReason = "Editing timer";
            return true;
        }
        bool inPG = app.CurrentPlayground !is null;
        if (S_PauseInEditor && (app.Editor !is null && !inPG)) {
            tmpPauseReason = "in Editor";
            return true;
        }
        if (S_PauseInMenu && (app.Switcher.ModuleStack.Length < 1 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) !is null)) {
            tmpPauseReason = "in Menu";
            return true;
        }
        if (S_PauseWhileLoading && app.LoadProgress.State == NGameLoadProgress::EState::Displayed) {
            tmpPauseReason = "Loading Screen";
            return true;
        }
        tmpPauseReason = tmpEditingPauseActive ? "Editing timer" : "Manually Paused";
        return false;
    }

    string TmpPausedReason() {
        return tmpPauseReason;
    }

    vec4 Render() {
        vScale = g_screen.y / stdHeightPx;
        nvg::Reset();
        nvg::FontSize(S_GreenTimerFontSize * vScale);
        nvg::FontFace(f_Nvg_ExoBold);
        nvg::TextAlign(S_GreenTimerAlign);
        nvg::BeginPath();
        auto r = _DrawGreenTimer(S_GreenTimerPos, S_GreenTimerAlign);
        nvg::ClosePath();
        return r;
    }

    string lastGreenTimerText = "";

    vec4 _DrawGreenTimer(vec2 pos, int align) {
        nvg::TextAlign(align);
        lastGreenTimerText = Time::Format(g_TimerMs, false, true, true);
        if (lastGreenTimerText.Length < 8) lastGreenTimerText = "0" + lastGreenTimerText;
        vec2 bounds = nvg::TextBounds(lastGreenTimerText.Length > 8 ? "000:00:00" : "00:00:00");
        int nbDigits = lastGreenTimerText.Length > 8 ? 7 : 6;
        vec2 smallBounds = nvg::TextBounds("00");
        float digitWidth = smallBounds.x / 2.;
        float colonWidth = (bounds.x - digitWidth * nbDigits) / 2.;
        vec2 bgTL = posAndBoundsAndAlignToTopLeft(pos * g_screen, bounds, align);
        float hovRound = S_GreenTimerFontSize * 0.1;
        vec2 textTL = bgTL;
        bgTL.y -= bounds.y * 0.1;
        bgTL.x -= hovRound;
        bounds.x += hovRound * 2;
        vec4 rect = vec4(bgTL - hovRound / 2., bounds + hovRound);
        if (S_GreenTimerBg) {
            nvg::FillColor(cBlack75);
            nvg::RoundedRect(rect.xy, rect.zw, hovRound);
            nvg::Fill();
            nvg::BeginPath();
        }
        nvg::TextAlign(nvg::Align::Top | nvg::Align::Left);
        auto textColor = !pausedThisFrame ? S_GreenTimerColor : S_GreenTimerPausedColor;

        auto parts = lastGreenTimerText.Split(":");
        string p;
        vec2 adj = vec2(0, 0);
        for (uint i = 0; i < parts.Length; i++) {
            p = parts[i];
            for (int c = 0; c < p.Length; c++) {
                adj.x = p[c] == 0x31 ? digitWidth / 4 : 0;
                DrawTextWithShadow(textTL+adj, p.SubStr(c, 1), textColor);
                textTL.x += digitWidth;
            }
            if (i < 2) {
                DrawTextWithShadow(textTL, ":", textColor);
                textTL.x += colonWidth;
            }
        }
        // DrawTextWithShadow(g_screen * pos, label, textColor);
        return rect;
    }

    string setTimerTo = "";

    void DrawSettings() {
        if (UI::BeginMenu("Green Timer")) {
            DrawSettingsInner();
            UI::EndMenu();
        }
    }

    // Pause during editing
    bool tmpEditingPauseActive = false;

    void DrawSettingsInner() {
        if (!S_TimerActive && UI::Button("Start")) {
            S_TimerActive = true;
            setTimerTo = "";
        } else if (S_TimerActive && UI::Button("Pause")) {
            S_TimerActive = false;
            setTimerTo = "";
        }

        if (IsTempPaused()) {
            UI::SameLine();
            UI::Text("\\$iPaused reason: " + TmpPausedReason());
        }

        UI::SeparatorText("General Settings");

        S_ShowGreenTimer = UI::Checkbox("Show Green Timer", S_ShowGreenTimer);
        S_HideWhenUIOff = UI::Checkbox("Hide When UI Off", S_HideWhenUIOff);

        S_PauseInMenu = UI::Checkbox("Pause In Menu", S_PauseInMenu);
        S_PauseInEditor = UI::Checkbox("Pause In Editor", S_PauseInEditor);
        S_PauseWhileLoading = UI::Checkbox("Pause While Loading", S_PauseWhileLoading);

        S_DragableMode = UI::Checkbox("Dragable Mode", S_DragableMode);

        UI::SeparatorText("Visual Settings");

        S_GreenTimerColor = UI::InputColor4("Running Color", S_GreenTimerColor);
        UI::SameLine();
        if (UI::Button(Icons::Refresh + "##Reset Color")) {
            S_GreenTimerColor = cDefaultText;
        }

        S_GreenTimerPausedColor = UI::InputColor4("Paused Color", S_GreenTimerPausedColor);
        UI::SameLine();
        if (UI::Button(Icons::Refresh + "##Reset paused Color")) {
            S_GreenTimerPausedColor = cGray;
        }

        S_GreenTimerFontSize = UI::SliderFloat("Font Size", S_GreenTimerFontSize, 10, 200);
        S_GreenTimerPos = UI::InputFloat2("Pos (0-1)", S_GreenTimerPos);
        S_GreenTimerAlign = InputAlign("Align", S_GreenTimerAlign);
        S_GreenTimerBg = UI::Checkbox("Semi-transparent Background", S_GreenTimerBg);

        UI::SeparatorText("Set Timer");

        S_CountUp = UI::Checkbox("Count Up", S_CountUp);
        UI::Indent();
        UI::Text(S_CountUp ? "\\$iCounting up" : "\\$iCounting down");
        UI::Unindent();

        S_NotifyOnFinish = UI::Checkbox("Notify when Timer reaches 0", S_NotifyOnFinish);

        string curr = Time::Format(g_TimerMs, false, true, true);
        if (setTimerTo == "") setTimerTo = curr;
        UI::Text("Current Timer: " + curr);
        bool changed = false;
        setTimerTo = UI::InputText("Set Timer To", setTimerTo, changed);
        bool textFieldActive = UI::IsItemActive();

        if (textFieldActive && tmpEditingPauseActive) {
            // do nothing
        } else if (textFieldActive && S_TimerActive) {
            // tmp pause
            tmpEditingPauseActive = true;
        } else if (!textFieldActive && tmpEditingPauseActive) {
            tmpEditingPauseActive = false;
        }

        if (changed) {
            tryUpdateTimeInMap(setTimerTo);
        } else if (!textFieldActive) {
            setTimerTo = curr;
        }
        if (parseErr != "") {
            UI::TextWrapped("\\$f80Parse Error: " + parseErr);
        }

        if (UI::Button("Reset to 0:00:00")) {
            g_TimerMs = 0;
        }
    }

    string parseErr;

    void tryUpdateTimeInMap(const string &in setTimerTo) {
        try {
            auto parts = setTimerTo.Trim().Split(":");
            if (parts.Length != 3) {
                parseErr = "format: h:mm:ss";
                return;
            }
            int hours = Text::ParseInt(parts[0]);
            int min = Text::ParseInt(parts[1]);
            int sec = Text::ParseInt(parts[2]);
            int sign = (hours < 0 || parts[0].StartsWith("-")) ? -1 : 1;
            hours = Math::Abs(hours);
            g_TimerMs = (hours * 3600 + min * 60 + sec) * 1000 * sign;
            parseErr = "";
        } catch {
            parseErr = "exception: " + getExceptionInfo();
        }
    }
}



nvg::Align InputAlign(const string &in label, uint v) {
    bool l = (v & nvg::Align::Left) > 0;
    bool c = (v & nvg::Align::Center) > 0;
    bool r = (v & nvg::Align::Right) > 0;
    bool t = (v & nvg::Align::Top) > 0;
    bool m = (v & nvg::Align::Middle) > 0;
    bool b = (v & nvg::Align::Bottom) > 0;
    bool bl = (v & nvg::Align::Baseline) > 0;
    UI::Text(label + ": " + (l ? "Left" : c ? "Center" : "Right") + " | " + (t ? "Top" : m ? "Middle" : b ? "Bottom" : "Baseline"));
    if (ButtonSL("Left"))       v = (v & 0b1111000) | nvg::Align::Left;
    if (ButtonSL("Center"))     v = (v & 0b1111000) | nvg::Align::Center;
    if (UI::Button("Right"))    v = (v & 0b1111000) | nvg::Align::Right;
    if (ButtonSL("Top"))        v = (v & 0b0000111) | nvg::Align::Top;
    if (ButtonSL("Middle"))     v = (v & 0b0000111) | nvg::Align::Middle;
    if (ButtonSL("Bottom"))     v = (v & 0b0000111) | nvg::Align::Bottom;
    if (UI::Button("Baseline")) v = (v & 0b0000111) | nvg::Align::Baseline;
    return nvg::Align(v);
}


vec2 posAndBoundsAndAlignToTopLeft(vec2 pos, vec2 bounds, int align) {
    if ((align & nvg::Align::Right) > 0) pos.x -= bounds.x;
    else if ((align & nvg::Align::Center) > 0) pos.x -= bounds.x / 2;
    if ((align & nvg::Align::Bottom) > 0) pos.y -= bounds.y;
    else if ((align & nvg::Align::Middle) > 0) pos.y -= bounds.y / 2;
    else if ((align & nvg::Align::Baseline) > 0) pos.y -= bounds.y * 0.8;
    return pos;
}


bool ButtonSL(const string &in label) {
    bool ret = UI::Button(label);
    UI::SameLine();
    return ret;
}
