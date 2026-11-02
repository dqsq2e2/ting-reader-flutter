#include "window_tasks.h"

#include <propkey.h>
#include <propvarutil.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <cwchar>
#include <string>

namespace {
constexpr wchar_t kAppId[] = L"cn.tingreader.desktop";

std::wstring ExecutablePath() {
  wchar_t path[32768];
  const DWORD length = GetModuleFileNameW(nullptr, path, ARRAYSIZE(path));
  return length > 0 && length < ARRAYSIZE(path) ? std::wstring(path, length) : L"";
}
}

void InitializeTaskbarTasks() {
  using Microsoft::WRL::ComPtr;
  SetCurrentProcessExplicitAppUserModelID(kAppId);
  ComPtr<ICustomDestinationList> destinations;
  if (FAILED(CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&destinations)))) return;
  if (FAILED(destinations->SetAppID(kAppId))) return;
  UINT slots = 0;
  ComPtr<IObjectArray> removed;
  if (FAILED(destinations->BeginList(&slots, IID_PPV_ARGS(&removed)))) return;

  ComPtr<IObjectCollection> tasks;
  ComPtr<IShellLinkW> link;
  ComPtr<IPropertyStore> properties;
  const auto path = ExecutablePath();
  HRESULT status = CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                                    CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&tasks));
  if (SUCCEEDED(status)) {
    status = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&link));
  }
  if (SUCCEEDED(status)) status = link->SetPath(path.c_str());
  if (SUCCEEDED(status)) status = link->SetArguments(L"--exit");
  if (SUCCEEDED(status)) status = link->SetDescription(L"退出听悦");
  if (SUCCEEDED(status)) status = link->SetIconLocation(path.c_str(), 0);
  if (SUCCEEDED(status)) status = link.As(&properties);
  PROPVARIANT title;
  PropVariantInit(&title);
  if (SUCCEEDED(status)) status = InitPropVariantFromString(L"退出软件", &title);
  if (SUCCEEDED(status)) status = properties->SetValue(PKEY_Title, title);
  if (SUCCEEDED(status)) status = properties->Commit();
  PropVariantClear(&title);
  if (SUCCEEDED(status)) status = tasks->AddObject(link.Get());
  if (SUCCEEDED(status)) status = destinations->AddUserTasks(tasks.Get());
  if (SUCCEEDED(status)) status = destinations->CommitList();
  if (FAILED(status)) destinations->AbortList();
}

void ExitRunningApplication() {
  const auto path = ExecutablePath();
  if (path.empty()) return;
  // 任务栏命令只退出同一路径下的客户端，避免影响其他版本。
  EnumWindows([](HWND window, LPARAM parameter) -> BOOL {
    wchar_t class_name[128];
    if (!GetClassNameW(window, class_name, ARRAYSIZE(class_name)) ||
        wcscmp(class_name, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0) return TRUE;
    DWORD process_id = 0;
    GetWindowThreadProcessId(window, &process_id);
    const HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
    if (!process) return TRUE;
    wchar_t executable[32768];
    DWORD size = ARRAYSIZE(executable);
    if (QueryFullProcessImageNameW(process, 0, executable, &size) &&
        _wcsicmp(executable, reinterpret_cast<const std::wstring*>(parameter)->c_str()) == 0) {
      PostMessage(window, kExitApplicationMessage, 0, 0);
    }
    CloseHandle(process);
    return TRUE;
  }, reinterpret_cast<LPARAM>(&path));
}
