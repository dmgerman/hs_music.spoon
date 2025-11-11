--- Music control spoon for Hammerspoon.
-- Provides utilities for controlling music playback across various music applications.
--
-- @author dmg
-- @module hs_music

local obj = {}
obj.__index = obj

--- Metadata about the spoon.
obj.name = "hs_music"
obj.version = "0.1"
obj.author = "Daniel M German <dmg@turingmachine.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT"

--- Configuration attributes.
-- @field alertDuration (number): Duration in seconds for track info alerts (default: 5)
obj.alertDuration = 5

--- Logger for debugging.
local logger = hs.logger.new(obj.name)

--- Sends a command to the currently playing music application.
--
-- @param command (string): The command to send (e.g., "playpause", "next", "previous")
-- @return (boolean): true if command was sent, false otherwise
function obj:sendMusicAppCommand(command)
  if not command or command == "" then
    logger:e("Invalid command: " .. tostring(command))
    return false
  end

  local success = pcall(function()
    hs.osascript.applescript(string.format(
      'tell application "Music" to %s',
      command
    ))
  end)

  if not success then
    logger:w("Failed to send command: " .. command)
  end

  return success
end

--- Sets the volume level of the Music app via AppleScript.
-- Clamps the input to 0–100 range.
--
-- @param level (number): Volume level as a percentage (0-100)
--
-- @details
-- - Uses AppleScript to set the sound volume directly
-- - Automatically clamps the value to 0-100 range
-- - Shows alerts for success/failure
--
-- @return (number or nil): The new volume level if successful, nil otherwise
function obj:changeMusicAppVolume(level)
    -- clamp to 0–100 range
    if level < 0 then level = 0 end
    if level > 100 then level = 100 end

    local ok, result = hs.osascript.applescript(
        string.format('tell application "Music" to set sound volume to %d', level)
    )

    if ok then
        hs.alert(string.format("Music volume set to %d%%", level))
        return level
    else
        hs.alert("Failed to set Music volume")
        return nil
    end
end



--- Gets the current volume level of the Music app via AppleScript.
--
-- @return (number or nil): Volume as a percentage (0-100), or nil if unavailable
--
-- @details
-- - Uses AppleScript to query the Music app directly
-- - Returns the sound volume value from the Music application
--
-- @note
-- Returns nil if Music app is not running or the query fails
function obj:getMusicAppVolume()
    local ok, result = hs.osascript.applescript('tell application "Music" to get sound volume')

    if ok and result then
        local volume = tonumber(result)
        if volume then
            hs.alert(string.format("Music volume: %d%%", volume))
            return volume
        end
    end

    hs.alert("Could not read Music volume")
    return nil
end

--- Changes the volume by a given percentage amount.
-- Gets the current volume, adds the delta, and clamps to 0–100 range.
--
-- @param delta (number): The percentage amount to change volume by (can be negative)
--
-- @return (number or nil): The new volume level if successful, nil otherwise
function obj:changeVolume(delta)
    local currentVolume = self:getMusicAppVolume()
    if not currentVolume then
        return nil
    end

    local newVolume = currentVolume + delta
    return self:changeMusicAppVolume(newVolume)
end



--- Plays or pauses the current track.
--
-- @return (boolean): true if successful, false otherwise
function obj:toggleMusicAppPlayPause()
  return self:sendMusicAppCommand("playpause")
end

--- Plays the next track.
--
-- @return (boolean): true if successful, false otherwise
function obj:nextMusicAppTrack()
  return self:sendMusicAppCommand("next track")
end

--- Plays the previous track.
--
-- @return (boolean): true if successful, false otherwise
function obj:previousMusicAppTrack()
  return self:sendMusicAppCommand("previous track")
end

--- Gets the currently playing track information (name, artist, album).
-- Checks if Music app is running and currently playing before retrieving info.
--
-- @return (string or nil): Formatted string "TrackName - Artist [Album]" if playing, nil otherwise
function obj:getMusicAppCurrentTrack()
  local script = [[
    tell application "Music"
      if it is running and player state is playing then
        set trackName to name of current track
        set trackArtist to artist of current track
        set trackAlbum to album of current track
        return trackName & " - " & trackArtist & " [" & trackAlbum & "]"
      else
        return "Not playing"
      end if
    end tell
  ]]

  local ok, result = hs.osascript.applescript(script)
  if ok and result and result ~= "Not playing" then
    return result
  end

  return nil
end

--- Gets the current artist name.
--
-- @return (string or nil): Artist name, or nil if unavailable
function obj:getMusicAppCurrentArtist()
  local success, result = pcall(function()
    return hs.osascript.applescript(
      'tell application "Music" to artist of current track'
    )
  end)

  if success and result and type(result) == "string" then
    return result
  end

  return nil
end

--- Shows current track information in an alert.
--
-- @return (boolean): true if successful, false otherwise
--
-- @details
-- - Displays formatted track info: "TrackName - Artist [Album]"
-- - Uses the `alertDuration` attribute (default: 5 seconds)
-- - Customize duration by setting: `music.alertDuration = 3`
function obj:showMusicAppCurrentTrack()
  local track = self:getMusicAppCurrentTrack()

  if not track then
    hs.alert.show("No track currently playing", self.alertDuration)
    return false
  end

  hs.alert.show(track, self.alertDuration)
  return true
end

--- Initializes the spoon with hotkey bindings.
--
-- @param hotkeys (table): Hotkey configuration table with keys for modifiers
-- @details
-- - hotkeys.togglePlayPause: Hotkey for play/pause
-- - hotkeys.nextTrack: Hotkey for next track
-- - hotkeys.previousTrack: Hotkey for previous track
-- - hotkeys.showTrack: Hotkey to show current track
--
-- @return (hs_music): Returns self for chaining
function obj:init(hotkeys)
  hotkeys = hotkeys or {}

  if hotkeys.togglePlayPause then
    hs.hotkey.bind(hotkeys.togglePlayPause.mods, hotkeys.togglePlayPause.key, function()
      self:toggleMusicAppPlayPause()
    end)
  end

  if hotkeys.nextTrack then
    hs.hotkey.bind(hotkeys.nextTrack.mods, hotkeys.nextTrack.key, function()
      self:nextMusicAppTrack()
    end)
  end

  if hotkeys.previousTrack then
    hs.hotkey.bind(hotkeys.previousTrack.mods, hotkeys.previousTrack.key, function()
      self:previousMusicAppTrack()
    end)
  end

  if hotkeys.showTrack then
    hs.hotkey.bind(hotkeys.showTrack.mods, hotkeys.showTrack.key, function()
      self:showMusicAppCurrentTrack()
    end)
  end

  return self
end

return obj
