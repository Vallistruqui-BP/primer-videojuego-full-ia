extends NakamaSocketAdapter

# A bounded cushion for browser timer throttling, not a guarantee during full tab freeze.
const RECEIVE_BUFFER_BYTES := 4 * 1024 * 1024
const WEB_PUMP_SOURCE := """
(function () {
 if (window.__officeSocketPumps) return;
 const entries = new Map();
 window.__officeSocketPumps = {
  install: function (key, callback) {
   this.remove(key);
   const entry = {timer: null, running: false, disposed: false, calls: 0, lastCall: 0};
   const pump = function () {
    if (entry.disposed || entry.running) return;
    entry.running = true;
    entry.calls++;
    entry.lastCall = Date.now();
    try { callback(); } finally { entry.running = false; }
   };
   entry.visibility = function () {
    if (entry.timer !== null) {
     clearInterval(entry.timer);
     entry.timer = null;
    }
    if (document.hidden) {
     entry.timer = setInterval(function () {
      if (document.hidden) pump();
     }, 250);
    }
    pump();
   };
   entry.dispose = function () {
    entry.disposed = true;
    if (entry.timer !== null) clearInterval(entry.timer);
    document.removeEventListener('visibilitychange', entry.visibility);
   };
   entries.set(key, entry);
   document.addEventListener('visibilitychange', entry.visibility);
   entry.visibility();
  },
  remove: function (key) {
   const entry = entries.get(key);
   if (entry) { entry.dispose(); entries.delete(key); }
  },
  inspect: function () {
   let timers = 0, callbacks = 0, lastCallbackMs = 0;
   for (const entry of entries.values()) {
    if (entry.timer !== null) timers++;
    callbacks += entry.calls;
    lastCallbackMs = Math.max(lastCallbackMs, entry.lastCall);
   }
   return {adapters: entries.size, timers, callbacks, lastCallbackMs, hidden: document.hidden};
  }
 };
})();
"""

var _pumping := false
var _web_callback: JavaScriptObject
var _web_bridge: JavaScriptObject
var _web_installed := false
var _web_key := ""

func _init() -> void:
 _ws.inbound_buffer_size = RECEIVE_BUFFER_BYTES

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 if not OS.has_feature("web"): return
 _web_key = str(get_instance_id())
 _web_callback = JavaScriptBridge.create_callback(_background_pump)
 JavaScriptBridge.eval(WEB_PUMP_SOURCE,true)
 _web_bridge = JavaScriptBridge.get_interface("__officeSocketPumps")
 _web_installed = true
 _web_bridge.install(_web_key,_web_callback)

func _process(_delta: float) -> void:
 pump_network()

func _background_pump(_arguments: Array) -> void:
 pump_network()

func pump_network() -> void:
 if _pumping or not is_inside_tree() or is_queued_for_deletion(): return
 _pumping = true
 # Reuse the SDK's state transitions and complete packet drain. Web poll alone is a no-op.
 super._process(0.0)
 _pumping = false

func dispose_web_pump() -> void:
 if _web_installed and _web_bridge:
  _web_bridge.remove(_web_key)
 _web_installed = false
 _web_callback = null
 _web_bridge = null

func _exit_tree() -> void:
 dispose_web_pump()
