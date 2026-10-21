#include "single_instance.h"

namespace {

constexpr wchar_t kMutexName[] = L"Local\\ITARA.POS.SingleInstance";
constexpr wchar_t kActivateMessageName[] = L"ITARA.POS.ActivateExistingWindow";
constexpr wchar_t kMainWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

HANDLE g_mutex = nullptr;
bool g_owns_mutex = false;

struct WindowSearch {
  HWND hwnd;
};

BOOL CALLBACK FindMainWindow(HWND hwnd, LPARAM param) {
  auto* search = reinterpret_cast<WindowSearch*>(param);
  wchar_t class_name[128];
  if (::GetClassNameW(hwnd, class_name, 128) == 0) {
    return TRUE;
  }
  if (::wcscmp(class_name, kMainWindowClass) != 0) {
    return TRUE;
  }
  search->hwnd = hwnd;
  return FALSE;
}

HWND ExistingMainWindow() {
  WindowSearch search{nullptr};
  ::EnumWindows(FindMainWindow, reinterpret_cast<LPARAM>(&search));
  return search.hwnd;
}

void BringToFront(HWND hwnd) {
  if (hwnd == nullptr) {
    return;
  }
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  } else {
    ::ShowWindow(hwnd, SW_SHOW);
  }
  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);
  // Queued for the existing thread. If that window is frozen, the message
  // waits and restores it when the thread runs again.
  ::PostMessageW(hwnd, ItaraActivateMessage(), 0, 0);
}

}  // namespace

UINT ItaraActivateMessage() {
  static const UINT message = ::RegisterWindowMessageW(kActivateMessageName);
  return message;
}

bool AcquireSingleInstance() {
  g_mutex = ::CreateMutexW(nullptr, FALSE, kMutexName);
  if (g_mutex == nullptr) {
    const HWND existing = ExistingMainWindow();
    if (existing != nullptr) {
      BringToFront(existing);
      return false;
    }
    return true;
  }

  const DWORD wait = ::WaitForSingleObject(g_mutex, 0);
  // WAIT_OBJECT_0: this process owns a fresh mutex.
  // WAIT_ABANDONED: the previous owner crashed or was killed. Take over.
  if (wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED) {
    g_owns_mutex = true;
    return true;
  }

  BringToFront(ExistingMainWindow());
  ::CloseHandle(g_mutex);
  g_mutex = nullptr;
  g_owns_mutex = false;
  return false;
}

void ReleaseSingleInstance() {
  if (g_mutex == nullptr) {
    return;
  }
  if (g_owns_mutex) {
    ::ReleaseMutex(g_mutex);
  }
  ::CloseHandle(g_mutex);
  g_mutex = nullptr;
  g_owns_mutex = false;
}
