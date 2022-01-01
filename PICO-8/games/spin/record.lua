-- input recording/playback
-- todo: update to some Repack compressed format

-- set to true to create recordings of every game
record_enabled = false

-- stored where record_init() won't wipe it at startup
record_filename = nil

-- replay data is checked for in a few places.
-- if nil, the game should work normally,
-- but if not present, _update60() will break.
record_replay = nil

-- if current replay frame is not in future,
-- advance, keeping track of state changes, until it is.
function record_playback_advance()
 if record_replay == nil then
  return
 end

 local effective_t = time() - record_base_t
 while record_playback_index <= #record_replay
 and record_replay[record_playback_index].t <= effective_t do
  local frame = record_replay[record_playback_index]
  for k, v in pairs(frame) do
   if k ~= "t" then
    record_state[k] = v
   end
  end
  record_playback_index = record_playback_index + 1
 end
end

function record_playback_pi_stick(s)
 if s == pi_l then
  return record_state.lx, record_state.ly
 elseif s == pi_r then
  return record_state.rx, record_state.ry
 end
end

-- todo: test this
function record_playback_pi_trigger(s)
 if s == pi_lt then
  return record_state.lt
 elseif s == pi_rt then
  return record_state.rt
 end
end

-- if a replay is loaded, redefine input system
if record_replay ~= nil then
 pi_stick = record_playback_pi_stick
 pi_trigger = record_playback_pi_trigger
end

-- setup for recording or playing back inputs
function record_init()
 -- record and playback times are relative to start of recording
 record_base_t = time()

 -- record and playback states are the same structure
 record_state = {
  lx = 0,
  ly = 0,
  rx = 0,
  ry = 0,
  lt = 0,
  rt = 0,
 }

 -- playback state
 record_playback_index = 1

 -- don't set up for recording if disabled or a replay is loaded
 if not record_enabled or record_replay ~= nil then
  return
 end

 -- end previous recording
 if record_filename ~= nil then
  record_printh("}")
 end

 -- start new file
 record_filename = record_new_filename()
 record_printh("record_replay = {")
end

-- build replay data filename from current UTC date
-- /!\ you can't use dashes in printh() filenames. go figure.
function record_new_filename()
 local filename = "spin_replay_" .. format_lzpad(stat(80), 4)
 for s = 81, 85 do
  filename = filename .. "_" .. format_lzpad(stat(s), 2)
 end
 filename = filename .. "_z.txt"
 return filename
end

-- record by appending to file on desktop
function record_printh(s)
 printh(s, record_filename, false, true)
end


-- returns a table and a bool.
-- the table consists of keys and values in t2
-- with corresponding keys in t1
-- that have different values in t1 and t2.
-- the bool is true if there are any changes.
function record_changed(t1, t2)
 local changed = false
 local tc = {}
 for k, v in pairs(t2) do
  if t1[k] ~= v then
   tc[k] = v
   changed = true
  end
 end
 return tc, changed
end

-- if inputs change, record time and any changed inputs
function record_frame_inputs(lx, ly, rx, ry, lt, rt)
 -- don't record if disabled or a replay is loaded
 if not record_enabled or record_replay ~= nil then
  return
 end

 local update, changed = record_changed(
   record_state,
   {
     lx = lx,
     ly = ly,
     rx = rx,
     ry = ry,
     lt = lt,
     rt = rt,
    }
  )
 if changed then
  update[t] = time()
  record_printh(format_toliteral(update, 1) .. ",\n")
 end
end
