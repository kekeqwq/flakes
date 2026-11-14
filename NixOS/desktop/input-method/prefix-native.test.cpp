// Exercise real librime/librime-lua, not a mock of processor return constants.
#include <rime_api.h>
#include <filesystem>
#include <fstream>
#include <ctime>
#include <cstdlib>
#include <iostream>
#include <stdexcept>

namespace fs = std::filesystem;
static void require(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}
int main(int argc, char** argv) {
  require(argc == 2, "guard source path required");
  const auto root = fs::current_path() / "native-prefix-test";
  const auto shared = root / "shared", user = root / "user";
  fs::create_directories(shared / "lua");
  fs::create_directories(user);
  fs::copy_file(argv[1], shared / "lua/ghostty_tmux_prefix.lua");
  std::ofstream(shared / "default.yaml") << "config_version: '1'\nschema_list:\n  - schema: prefix_probe\n";
  std::ofstream(shared / "prefix_probe.schema.yaml") << R"(schema:
  schema_id: prefix_probe
  name: Prefix probe
  version: '1'
engine:
  processors:
    - lua_processor@*ghostty_tmux_prefix
    - speller
    - express_editor
  segmentors:
    - abc_segmentor
  translators: []
speller:
  alphabet: abcdefghijklmnopqrstuvwxyz
)";
  auto* api = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  const std::string sharedPath = shared.string(), userPath = user.string();
  traits.shared_data_dir = sharedPath.c_str();
  traits.user_data_dir = userPath.c_str();
  traits.app_name = "rime.ghostty-prefix.test";
  traits.log_dir = userPath.c_str();
  api->setup(&traits);
  api->initialize(&traits);
  if (api->start_maintenance(true)) api->join_maintenance_thread();
  auto session = api->create_session();
  require(session != 0, "Rime session creation failed");
  require(api->select_schema(session, "prefix_probe"), "probe schema did not deploy");
  const auto lease = fs::path(std::getenv("HOME")) / ".local/state/input-method/tmux-prefix-context";
  fs::create_directories(lease.parent_path());
  auto context = [&](const char* kind, int age = 0) {
    std::ofstream(lease) << kind << ' ' << (std::time(nullptr) - age) << '\n';
  };
  auto key = [&](int code, int mask = 0) { return api->process_key(session, code, mask) != 0; };
  constexpr int control = 1 << 2, release = 1 << 30;
  api->set_property(session, "client_app", "ghostty");
  context("tmux");
  require(!key('b', control), "Ctrl+B must reach tmux");
  key('b', control | release);
  require(!key('c'), "next press must reach tmux, not be composed");
  require(key('c'), "ordinary Chinese composition must resume after one key");
  api->clear_composition(session);
  require(!key(' ', control), "Ctrl+Space must reach tmux");
  require(!key('c'), "Ctrl+Space next key must reach tmux");
  api->set_property(session, "client_app", "emacs");
  key('b', control);
  require(key('c'), "other applications must retain composition");
  api->clear_composition(session);
  api->set_property(session, "client_app", "ghostty");
  context("other");
  key('b', control);
  require(key('c'), "direct Pi is not a tmux prefix context");
  api->clear_composition(session);
  context("tmux", 10);
  key('b', control);
  require(key('c'), "expired focus lease must not bypass composition");
  api->clear_composition(session);
  api->set_property(session, "client_app", "");
  context("tmux");
  require(!key('b', control), "Wayland empty app: Ctrl+B must pass");
  require(!key('c'), "Wayland empty app: next key must pass with focus lease");
  context("other");
  key('b', control);
  require(key('c'), "Wayland empty app: other focused windows keep composition");
  api->clear_composition(session);
  context("tmux");
  require(!key('b', control), "prefix before reset must pass");
  api->clear_composition(session);
  require(key('c'), "Rime reset must clear a pending prefix before Chinese resumes");
  api->destroy_session(session);
  api->finalize();
  std::cout << "real librime: prefix/next key/release/composition/app scope/lease PASS\n";
}
