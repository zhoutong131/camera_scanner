#include "include/camera_scanner/camera_scanner_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "camera_plugin.h"

void CameraScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  camera_scanner::CameraPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
