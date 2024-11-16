local mod = require 'core/mods'




-- -------------------------------------------------------------------------
-- CORE

local function round(v)
  return math.floor(v+0.5)
end


-- -------------------------------------------------------------------------
-- UTILS: MIDI IN / OUT

local function send_midi_msg(msg)
  local data = midi.to_data(msg)
  local is_affecting = false

  -- midi in
  for id, dev in pairs(midi.devices) do
    if dev.port ~= nil and dev.name == 'virtual' then
      _norns.midi.event(id, data)
      -- if midi.vports[dev.port].event ~= nil then
      --   midi.vports[dev.port].event(data)
      --   is_affecting = true
      -- end
      break
    end
  end

  return is_affecting
end

local function gamepad_axis_2_cc(axis)
  -- TODO: make this configurable
  -- NB: fwiw, korg joystick is usually CC 16/17
  local mapping = {
    lefty=50,
    leftx=51,
    righty=52,
    rightx=53,
    triggerleft=54,
    triggerright=55,
  }
  return mapping[axis]
end

local function gamepad_analog_event_2_cc(sensor_axis, val, half_reso)
  local cc = gamepad_axis_2_cc(sensor_axis)
  if cc == nil then
    return
  end
  local v = round(util.linlin(0, half_reso*2, 0, 127, val+half_reso))

  -- TODO: make configurable
  local chan = 1
  local msg = {
    type = 'cc',
    cc = cc,
    val = v,
    ch = chan,
  }

  is_affecting = send_midi_msg(msg)
end


-- -------------------------------------------------------------------------
-- LIFECYCLE BINDING

mod.hook.register("script_pre_init", "midipad-script-pre-init", function ()
                    local script_init = init
                    init = function ()
                      script_init()
                      local script_gamepad_analog = gamepad.analog
                      gamepad.analog = function(sensor_axis, val, half_reso)
                        if val == nil or half_reso == nil then
                          -- FIXME: why does this even happen?
                          return
                        end
                        local msg = gamepad_analog_event_2_cc(sensor_axis, val, half_reso)
                        if script_gamepad_analog then
                          script_gamepad_analog(sensor_axis, val, half_reso)
                        end
                      end
                    end
end)

mod.hook.register("script_post_cleanup", "midipad-script-post-cleanup", function ()
                    -- callbacks will be unset for us by script.clear / gamepad.clear
end)
