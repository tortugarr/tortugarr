#include <unistd.h>
#include <functional>
#include <iostream>
#include <optional>
#include <string>

#include <dirent.h>
#include <sys/inotify.h>
#include <map>

#include "connection_listener.h"
#include "utils.h"

using namespace connection_listener;

const std::string _input_dir = "/dev/input/";

std::map<ConnectionEventType, const char*> connectionEventTypeNames = {
    {ConnectionEventType::CONNECTED, "CONNECTED"},
    {ConnectionEventType::DISCONNECTED, "DISCONNECTED"},
};

std::optional<ConnectionEventType> _parseEventType(inotify_event* event) {
  uint mask = event->mask;
  if ((mask & IN_CREATE) || (mask & IN_ATTRIB)) {
    return ConnectionEventType::CONNECTED;
  } else if (mask & IN_DELETE) {
    return ConnectionEventType::DISCONNECTED;
  } else {
    return std::nullopt;
  }
}

void _list_existing(
    const std::function<void(const ConnectionEvent&)>& event_consumer) {
  DIR* dir = opendir(_input_dir.c_str());

  if (!dir) {
    // Everything here runs on a detached thread, where an uncaught throw calls
    // std::terminate and takes the whole app down. Gamepad support is optional,
    // so every failure below degrades instead of throwing.
    std::cerr << "Failed to open directory: " << _input_dir
              << ", gamepad detection disabled" << std::endl;
    return;
  }

  struct dirent* entry;
  std::vector<std::string> devices;
  while ((entry = readdir(dir)) != nullptr) {
    if (entry->d_type != DT_CHR) {
      continue;
    }
    if (!starts_with(entry->d_name, "js")) {
      continue;
    }
    std::string device = _input_dir + entry->d_name;
    devices.push_back(device);
  }

  closedir(dir);

  for (std::string& device : devices) {
    ConnectionEvent connectionEvent = {ConnectionEventType::CONNECTED, device};
    event_consumer(connectionEvent);
  }
}

bool _wait_for_connections(
    int inotify,
    const std::function<void(const ConnectionEvent&)>& event_consumer) {
  char buffer[4096] __attribute__((aligned(__alignof__(struct inotify_event))));
  ssize_t len = read(inotify, buffer, sizeof(buffer));
  if (len < 0) {
    // A failed read means the watch is gone, so stop listening.
    std::cerr << "Error reading inotify events, gamepad hotplug disabled"
              << std::endl;
    return false;
  }

  char* ptr = buffer;
  while (ptr < buffer + len) {
    auto* event = reinterpret_cast<struct inotify_event*>(ptr);
    std::string name = event->len > 0 ? event->name : "";
    if (!starts_with(name, "js")) {
      break;
    }

    std::string device = _input_dir + name;
    std::optional<ConnectionEventType> type = _parseEventType(event);
    if (!type) {
      // Events like IN_IGNORED carry no connect or disconnect meaning, so skip
      // them rather than dereferencing an empty optional.
      ptr += sizeof(struct inotify_event) + event->len;
      continue;
    }

    std::cout << "Connection found: " << connectionEventTypeNames[*type]
              << " - " << name << std::endl;
    ConnectionEvent connection_event = {*type, device};
    event_consumer(connection_event);

    ptr += sizeof(struct inotify_event) + event->len;
  }
  return true;
}

namespace connection_listener {
void listen(const bool* keep_reading,
            const std::function<void(const ConnectionEvent&)>& event_consumer) {
  std::cout << "Reading initial gamepads..." << std::endl;
  _list_existing(event_consumer);

  int inotify = inotify_init();
  if (inotify == -1) {
    // Gamepads already plugged in were listed above, so only hotplug is lost.
    std::cerr << "Error initializing inotify, gamepad hotplug disabled"
              << std::endl;
    return;
  }
  int watcher = inotify_add_watch(inotify, _input_dir.c_str(),
                                  IN_CREATE | IN_DELETE | IN_ATTRIB);
  if (watcher == -1) {
    close(inotify);
    std::cerr << "Error adding watch for " << _input_dir
              << ", gamepad hotplug disabled" << std::endl;
    return;
  }

  std::cout << "Listening for gamepads..." << std::endl;
  while (*keep_reading) {
    if (!_wait_for_connections(inotify, event_consumer)) {
      break;
    }
  }
  std::cout << "Stopped listening for gamepads." << std::endl;

  // Remove the inotify watch and close the file descriptor
  inotify_rm_watch(inotify, watcher);
  close(inotify);
}
}  // namespace connection_listener