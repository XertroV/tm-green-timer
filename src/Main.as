void Main() {
    startnew(LoadFonts);
}

// UI::Font@ f_MonoSpace = null;
UI::Font@ f_Droid = null;
// UI::Font@ f_DroidBig = null;
// UI::Font@ f_DroidBigger = null;

void LoadFonts() {
	// @f_MonoSpace = UI::LoadFont("DroidSansMono.ttf");
    @f_Droid = UI::LoadFont("DroidSans.ttf", 16.);
    // @f_DroidBig = UI::LoadFont("DroidSans.ttf", 20.);
    // @f_DroidBigger = UI::LoadFont("DroidSans.ttf", 26.);
}

vec2 g_screen;

void RenderEarly() {
    g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    GreenTimer::Update();
}

const int windowFlagsBase = UI::WindowFlags::NoTitleBar
    | UI::WindowFlags::NoResize
    | UI::WindowFlags::NoDecoration
    | UI::WindowFlags::NoFocusOnAppearing
    | UI::WindowFlags::AlwaysAutoResize;
    // | UI::WindowFlags::NoBringToFrontOnFocus
    // | UI::WindowFlags::NoSavedSettings

void Render() {
    if (!S_ShowGreenTimer) return;
    if (S_HideWhenUIOff && !UI::IsGameUIVisible()) return;
    auto rect = GreenTimer::Render();
    auto adjPos = rect.xy / UI::GetScale();
    // auto adjSize = rect.zw / UI::GetScale();
    auto wp = UI::GetStyleVarVec2(UI::StyleVar::WindowPadding);
    auto windowFlags = windowFlagsBase;
    if (!S_DragableMode) {
        UI::SetNextWindowPos(int(adjPos.x - wp.x), int(adjPos.y - wp.x), UI::Cond::Always);
        windowFlags |= UI::WindowFlags::NoMove;
    }
    // UI::SetNextWindowSize(int(adjSize.x), int(adjSize.y), UI::Cond::Always);
    UI::PushStyleColor(UI::Col::WindowBg, vec4(0, 0, 0, S_DragableMode ? .6 : 0));
    UI::PushStyleColor(UI::Col::Border, vec4(0, 0, 0, 0));
    vec2 winPos;
    if (UI::Begin("green-timer-window", windowFlags)) {
        auto startPos = UI::GetCursorPos();
        winPos = UI::GetWindowPos();
        if (S_DragableMode) {
            DrawCenteredText("Drag Me", rect.zw, vec2(.25, .25));
            DrawCenteredText("Drag Me", rect.zw, vec2(.25, .75));
            DrawCenteredText("Drag Me", rect.zw, vec2(.75, .75));
            DrawCenteredText("Drag Me", rect.zw, vec2(.75, .25));
            DrawCenteredText("Drag Me", rect.zw, vec2(.5, .5));
            UI::SetCursorPos(startPos);
        }
        UI::Dummy(rect.zw);
        if (UI::BeginPopupContextItem("green-timer-rbm")) {
            GreenTimer::DrawSettingsInner();
            UI::EndPopup();
        }
        if (S_DragableMode) {
            vec2 uv = Round3Dps((winPos + g_screen * S_GreenTimerPos - rect.xy + wp) / g_screen);
            S_GreenTimerPos = uv;
            // UI::SetCursorPos(startPos);
            // UI::Text('' + winPos.ToString());
            // UI::Text('' + uv.ToString());
            // UI::Text('' + S_GreenTimerPos.ToString());
        }
    }
    UI::End();
    UI::PopStyleColor(2);
    if (S_DragableMode) {

    }
}

vec2 Round3Dps(vec2 v) {
    return vec2(Math::Round(v.x * 1000.) / 1000., Math::Round(v.y * 1000.) / 1000.);
}


void DrawCenteredText(const string &in msg, vec2 size, vec2 uv) {
    auto bounds = Draw::MeasureString(msg, f_Droid, 16., 0.0f) * UI::GetScale();
    auto pos = size * uv - vec2(bounds.x, 16.) / 2. + vec2(0, 2.);
    UI::SetCursorPos(pos);
    UI::Text(msg);
}


[SettingsTab name="General" icon="Cogs"]
void R_Settings_General() {
    GreenTimer::DrawSettingsInner();
}

void RenderMenu() {
    string extra = "\\$999 (" + (S_ShowGreenTimer ? "Active" : "Hidden") + ")"; //  + " / " + GreenTimer::lastGreenTimerText + ")";
    if (UI::MenuItem("\\$7f7" + Icons::ClockO + " Green Timer" + extra, "", S_ShowGreenTimer)) {
        S_ShowGreenTimer = !S_ShowGreenTimer;
    }
}
