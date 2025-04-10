#ifndef FLUTTER_PLUGIN_CAMERA_SCANNER_PLUGIN_H_
#define FLUTTER_PLUGIN_CAMERA_SCANNER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace camera_scanner {

class CameraScannerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  CameraScannerPlugin();

  virtual ~CameraScannerPlugin();

  // Disallow copy and assign.
  CameraScannerPlugin(const CameraScannerPlugin&) = delete;
  CameraScannerPlugin& operator=(const CameraScannerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace camera_scanner

#endif  // FLUTTER_PLUGIN_CAMERA_SCANNER_PLUGIN_H_
