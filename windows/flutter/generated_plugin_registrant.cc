//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <firebase_core/firebase_core_plugin_c_api.h>
#include <just_audio_engine/just_audio_engine_plugin.h>
#include <just_gamepads/just_gamepads_plugin_c_api.h>
#include <just_inputs/just_inputs_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FirebaseCorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
  JustAudioEnginePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("JustAudioEnginePlugin"));
  JustGamepadsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("JustGamepadsPluginCApi"));
  JustInputsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("JustInputsPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
