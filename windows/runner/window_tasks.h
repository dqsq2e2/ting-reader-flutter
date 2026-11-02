#ifndef RUNNER_WINDOW_TASKS_H_
#define RUNNER_WINDOW_TASKS_H_

#include <windows.h>

constexpr UINT kExitApplicationMessage = WM_APP + 49;
constexpr UINT kExitSystemMenuCommand = 0x1F00;

void InitializeTaskbarTasks();
void ExitRunningApplication();

#endif
