#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

// Owns the process-wide single-instance mutex.
// Returns false when another live instance already owns it. That instance is
// brought forward and this process must exit without creating a window.
// A crashed or rebooted previous instance does not keep the mutex: the next
// launch is allowed to open the window again.
bool AcquireSingleInstance();

void ReleaseSingleInstance();

// Posted to the existing window so it restores itself once its thread runs.
UINT ItaraActivateMessage();

#endif  // RUNNER_SINGLE_INSTANCE_H_
