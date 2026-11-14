#include "../../voice_overlay_window.h"


void VoiceOverlayWindow::Paint() {
  PAINTSTRUCT ps{};
  HDC dc = BeginPaint(window_, &ps);
  RECT bounds{};
  GetClientRect(window_, &bounds);
  HBRUSH background = CreateSolidBrush(RGB(24, 26, 34));
  FillRect(dc, &bounds, background);
  DeleteObject(background);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(242, 244, 250));
  HFONT font = CreateFontW(-Layout(14), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH, L"Segoe UI");
  HGDIOBJ previous = SelectObject(dc, font ? font : GetStockObject(DEFAULT_GUI_FONT));
  RECT header{Layout(16), Layout(8), bounds.right - Layout(16), Layout(38)};
  DrawTextW(dc, L"BOOHTACORD  •  VOICE", -1, &header,
            DT_LEFT | DT_VCENTER | DT_SINGLELINE);
  int y = Layout(44);
  const int kRowHeight = Layout(34);
  for (const auto& member : members_) {
    RECT row{Layout(8), y, bounds.right - Layout(8), y + kRowHeight - Layout(3)};
    HBRUSH fill = CreateSolidBrush(member.speaking ? RGB(55, 82, 73)
                                                   : RGB(38, 41, 51));
    FillRect(dc, &row, fill);
    DeleteObject(fill);
    HBRUSH avatar = CreateSolidBrush(RGB(84, 79, 127));
    const HGDIOBJ old_brush = SelectObject(dc, avatar);
    Ellipse(dc, Layout(12), y + Layout(4), Layout(36), y + Layout(28));
    SelectObject(dc, old_brush);
    DeleteObject(avatar);
    RECT initial{Layout(12), y + Layout(4), Layout(36), y + Layout(28)};
    SetTextColor(dc, RGB(242, 244, 250));
    const int units = !member.display_name.empty() && member.display_name.front() >= 0xD800 &&
        member.display_name.front() <= 0xDBFF && member.display_name.size() > 1 ? 2 : 1;
    DrawTextW(dc, member.display_name.c_str(), units, &initial,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    SetTextColor(dc, member.speaking ? RGB(166, 246, 192) : RGB(235, 237, 244));
    RECT name{Layout(42), y, bounds.right - Layout(78), y + kRowHeight - Layout(3)};
    DrawTextW(dc, member.display_name.c_str(), -1, &name,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    RECT state{bounds.right - Layout(74), y, bounds.right - Layout(14), y + kRowHeight - Layout(3)};
    const wchar_t* state_label = member.deafened ? L"DEAFENED" : member.microphone_muted ? L"MIC OFF" : L"MIC ON";
    DrawTextW(dc, state_label, -1,
              &state, DT_RIGHT | DT_VCENTER | DT_SINGLELINE);
    y += kRowHeight;
  }
  if (members_.empty()) {
    RECT empty{Layout(16), y, bounds.right - Layout(16), y + kRowHeight};
    SetTextColor(dc, RGB(180, 184, 196));
    DrawTextW(dc, L"Нет активных участников", -1, &empty,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
  }
  SelectObject(dc, previous);
  if (font) DeleteObject(font);
  EndPaint(window_, &ps);
}
