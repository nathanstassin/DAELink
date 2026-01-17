--[[
    MotionBridge | v0.9 Beta | © 2025-2026 Nathan Stassin

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.

    Description: Links timeline nests with compositions in AE via a GUI Window. 
                 Automated render management and shared markers across programs. 

    Author:       Nathan Stassin  |  https://www.nathanstassin.com

    Requirements: Davinci Resolve Studio V20 or later 
                  OR Davinci Resolve Free 19.0.3

    Intallation: Drag this file into the Utility Scripts folder on your computer
                 Mac:/Users/Username/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility
                 Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\

    Privacy:    All data stored locally. 
                No data is transmitted to external servers.
                
    Version History:
    - 0.9 Beta - 17/01/2026 
]]

-- GLOBALS
_G.resolve = app:GetResolve() or bmd.scriptapp("Resolve")
_G.project = nil
_G.project_id = nil
_G.media_pool = nil
_G.root_folder = nil
_G.project_media_path = nil 
_G.json_path = nil 
_G.motionbridge_folder = nil 
_G.comps_folder = nil 
_G.renders_folder = nil 
_G.compound_clips_folder = nil 

_G.CONSTANTS = {
    MOTIONBRIDGE_VERSION = 0.9,
    PLACEHOLDER_TL_NAME = "0_MotionBridgePlaceholder",
    FOLDER_NAMES = {
        MOTIONBRIDGE = "0_MotionBridge",
        COMPOUNDCLIPS = "0_Compound Clips",
        RENDERS = "1_Renders", 
        LINKEDCOMPS = "Linked Compositions"
    },
    DIRECTORY_NAMES = { 
        ROOT = "motionbridge",
        RENDERS = "renders",
        SUPPORT = "support"
    },
    MARKER_COLORS = {'Blue', 'Cyan', 'Green', 'Yellow', 'Red', 'Pink', 'Purple', 'Fuchsia', 'Rose', 'Lavender', 'Sky', 'Mint', 'Lemon', 'Sand', 'Cocoa', 'Cream'},
    VIDEO_EXTENSIONS = {".mov", ".mp4", ".mxf", ".avi", ".mkv", ".m4v", ".wmv", ".flv", ".webm", ".mpg", ".mpeg", ".tif", ".tiff"},
    PLACEHOLDER_DURATION = 5,  -- seconds
    FILE_DISPLAY_MAX_LENGTH = 90,
    PAGE_SIZE = 10,
    TIMECODE = {
        START = "00:00:00:00",
        PLACEHOLDER_END = "00:59:55:00"
    },
    TRACK_NAMES = {
        RENDER_VIDEO = "RENDER▪LOCKED",
        RENDER_AUDIO = "RENDER▪LOCKED",
        COMPOUND_CLIP = "COMPOUND CLIP"
    },
    JSON_FILENAME = "motionbridge.json",
    COMMENT_ID_PREFIX = "ID(DONOTDELETE):",
    PRELINK_PATTERN = "^prelink%d+$",
    LINKED_CLIPS_SUFFIX = " linked clips",
    CUSTOM_SETTINGS = {
        DEFAULT_WIDTH = 1920,
        DEFAULT_HEIGHT = 1080
    },
    SEARCH_SAFETY_LIMIT = 100,  
    ICONS = {
        logoB64        = [[data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAAsTAAALEwEAmpwYAAAD6ElEQVR4nN2auYsUURDG34w3GIj+CyqoaCiiqIhXopEH4gGiK6gg4gXKgqKCB6KYaGIkRqaGezPTGyz7V4giInjgfeHPoLtxtu2r6r2+9oMKduZVdX/fq1dV3bPGFIiBgQEDpNl94EHamrGxsSJvsTgMDg5mkT/HP/Snre10OlXTkWFoaEhCPpcI3W63alr5kIP8+Rjy00MEYdqrRKjtcVCm/fTIBIu03w5sarQIFuSP9Kw5oBGh8uMwPDycRf5CArGjMWsPakTwPK8a8hYFry/F51AjMsGi4KWRtxKhtJpgceaP5SBfbxEKSvtmHAeLtI8reM3KBEetTmuqFulMhIrJW4lgfRwc93lbK3dOKLng5bVyCmPBfb4SEXLXhJL6fD1FqGnal3McSuzzy4GVwCJgJjADWBh8tqIMEf7LhJJa3RLgUSDYUmAu0Aq+mwMsBg4Ha5YL4trNCSMjI2WQD3fqZI61fcFaSWapRPA8z2QFdtHnjysE2xf4nBb4qOaEtIAuCt7GwKcj8AltIPDdJvAR14Qiyc8CPgd+mxQCrAl8fwLzihIhLoCrPn858PuFX+WlAswHvgUxbgl9c4tQxM6H9jbw/YCfDVJ/A7wOYnzCb5nORchDXvNgs67H30UGAGxRxMgUISvttY+0ZyJxNitirIvEuKi8l9QWafB/oo7iOzrFQ7sRifdMEeNpJMY9i/tZD3yN4fmwbYyZnfBo8DPf41MsWpG/dxpjNgj8Vxtj9lpcP4ofCZ/PDhXqj00S2K9U/GxMrK/Aqhy+y4CPMf6XlPeyJ4HbNZhaBJNEOKi46PqEWH+AU8R3hTZwAr/vx0EyEIW2N418VIA0EQ4JL9wC3ifEAngBPAGuBPYYeJ6y/gvyVppJnhgBXIpwPYWQFHeF185FngQBXIkwl/jKK8Vv/JnAOXlSBHAlwlYV5anYIbieiDwZArgSoS8hRh7keX+QRf5qmp8ZHx/XinBAcHM7gTcC4u+AXYL4uzXkJycn/Wmg2+1qRZDMCQuAm8DLFOKvgDv47wvzxk3t80k2MTFhWq2eec1CBOmcMAt/zD4D3A7sLH6fnyOMJT7zIfl2u/3/XNjpdLQiSFukC1OTn7LzUVhkQpkiuN35holQLPmaH4di0r4hmaDq8+KddyiCZE7IMlWfV++8QxG07xN6Td3nrXbeoQia9wnWZ94p+RAlF8ZyC15elFQY67XzJYtQb/IhCjoO9Uz7JDjOhGr6fIUi9M4J1fb5CkXYCKxN+K5eZz4LFiI0n3wIi8IoIl+LtE+CZSY0c+ejUIowPciHEB6HZqd9EkZHR7NEeIj/j5GJazzPK3Tn/wKe3UL0/v4G+AAAAABJRU5ErkJggg==]],
        copyright      = "©",
        warning        = "⚠",
        openFolder     = "📂",
        upTriangle     = "▲",
        downTriangle   = "▼",
        upArrow        = "↑",
        downArrow      = "↓",
        downRightArrow = "↳",
        downToBarArrow = "⤓",
        leftArrow      = "←",
        rightArrow     = "→",
        help           = "?",
        gear           = "⚙",
        refresh        = "↻",
        plus           = "✚",
        play           = "▶"
    }, 
    WEBSITEURL = "https://nathanstassin.com/motionbridge"
}

local TITLE_CSS = [[
    QLabel
    {
        font-size: 13px;
        background-color: rgba(30, 30, 30, 255);
        border-radius: 0px;
        border-top-left-radius: 10px; 
        border-top-right-radius: 10px;
        padding: 1px;
    }
]]
local BRANDING_CSS = [[
    QLabel
    {
        color: rgba(200, 200, 200, 255);
        font-size: 12.5px;
        border-radius: 0px;
        padding: 1px;
    }
]]

-- INIT
function build_project_paths(base)
    -- Normalise to forward slashes and remove trailing slashes
    base = base:gsub("\\", "/"):gsub("/+$", "")
    
    local root = base .. "/" .. _G.CONSTANTS.DIRECTORY_NAMES.ROOT
    return {
        root = root,
        support = root .. "/" .. _G.CONSTANTS.DIRECTORY_NAMES.SUPPORT,
        renders = root .. "/" .. _G.CONSTANTS.DIRECTORY_NAMES.RENDERS,
        json = root .. "/" .. _G.CONSTANTS.DIRECTORY_NAMES.SUPPORT .. "/" .. _G.CONSTANTS.JSON_FILENAME
    }
end

function initialise(project_media_path)    
    if not project_media_path or project_media_path == "" then
        alert("No media path provided.")
        return false
    end

    -- Normalise path: convert backslashes to forward slashes and remove trailing slashes
    project_media_path = project_media_path:gsub("\\", "/"):gsub("/+$", "")
    
    local normalised_path = project_media_path
    local lower_path = normalised_path:lower()
    
    if lower_path:match("/motionbridge/?$") then
        -- User selected motionbridge folder, strip it off to get parent
        project_media_path = normalised_path:match("^(.*)/[mM][oO][tT][iI][oO][nN][bB][rR][iI][dD][gG][eE]/?$")
    end

    local paths = build_project_paths(project_media_path)
    
    -- Store the normalised project_media_path globally
    _G.project_media_path = project_media_path

    if paths then 
        _G.json_path = paths.json        
        refresh_project_globals()
        
        local initial_timeline = _G.project:GetCurrentTimeline()        
        local placeholder_state = validate_placeholder()

        if not placeholder_state then 
            return false 
        end

        local is_first_init = placeholder_state == "missing"
        
        if is_first_init then
            if not confirm("No Link detected for current project: " .. _G.project:GetName() .. "\n\nInitialise link?") then
                alert("User cancelled link initialisation. Aborting.")
                return false
            end
                        
            -- Create directories
            for i, path in ipairs({paths.root, paths.support, paths.renders}) do
                if not create_directory(path) then 
                    return false 
                end
            end
            
            _G.json_path = paths.json
            
            get_motionbridge_folders()
            
            if not create_placeholder_timeline() then 
                return false 
            end
            
            if not initialise_json() then 
                return false 
            end
            
            alert("MotionBridge Project initialised!\n Connect to same folder from AE using MotionBridge panel.")
        else
            -- Check if motionbridge folder exists in selected parent folder
            if not directory_exists(paths.root) then
                alert("No motionbridge folder found!")
                return false
            end
            
            if not version_check() then return false end
            alert("Link detected for current project: " .. _G.project:GetName() .. "\n\nRebinding...")
            
            -- Validate directories exist
            local checks = {
                {paths.root, "MotionBridge folder not found at selected media path."},
                {paths.support, "MotionBridge/Support folder missing."},
                {paths.renders, "MotionBridge/Renders folder missing."}
            }
            
            for _, check in ipairs(checks) do
                if not directory_exists(check[1]) then
                    alert(check[2])
                    return false
                end
            end
            
            if not file_exists(paths.json) then
                alert("motionbridge.json not found. Cannot rebind.")
                return false
            end
            
            _G.json_path = paths.json
            
            if not load_and_validate_json() then return false end
            
            get_motionbridge_folders()
        end

        if initial_timeline then
            _G.project:SetCurrentTimeline(initial_timeline)
        end

        return true
    end
end

function validate_placeholder()
    -- Returns: "missing", "valid", or false (error)
    local placeholder_timeline = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    
    if not placeholder_timeline then
        return "missing"
    end

    local props = placeholder_timeline:GetClipProperty()
    local comment = props["Comments"] or ""
    
    if comment == "" then
        alert("Error: Comment with ID deleted from MotionBridge Placeholder.\n\nDelete timeline and re-initialise project")
        return false
    end

    local pattern = _G.CONSTANTS.COMMENT_ID_PREFIX:gsub("([%(%)%-])", "%%%1") .. "%s*([%w%-]+)"
    local embedded_id = comment:match(pattern)
    if not embedded_id then
        alert("Invalid MotionBridge placeholder comment format")
        return false
    end

    if embedded_id ~= _G.project:GetUniqueId() then
        alert("MotionBridge placeholder belongs to a different project. Aborting.")
        return false
    end

    return "valid"
end

function create_placeholder_timeline()
    _G.media_pool:SetCurrentFolder(_G.motionbridge_folder)

    local tl = _G.media_pool:CreateEmptyTimeline(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not tl then
        alert("Failed to create MotionBridge placeholder timeline.")
        return false
    end

    tl:SetTrackEnable("video", 1, false) -- Hide null fusion comp
    tl:SetStartTimecode(_G.CONSTANTS.TIMECODE.START)
    tl:InsertFusionCompositionIntoTimeline()
    tl:SetCurrentTimecode(_G.CONSTANTS.TIMECODE.PLACEHOLDER_END)
    tl:InsertFusionCompositionIntoTimeline()


    local timeline_item = get_timeline_mpi(tl)
    timeline_item:SetClipProperty("Comments", _G.CONSTANTS.COMMENT_ID_PREFIX .. _G.project_id)
    
    return true
end

function initialise_json()
    return save_json_data({
        projectid = _G.project_id,
        motionBridgeVersion = _G.CONSTANTS.MOTIONBRIDGE_VERSION,
        projectFPS = _G.project:GetSetting("timelineFrameRate"),
        compositions = {}
    })
end

function load_and_validate_json()
    local data = load_json_data(_G.json_path)
    if not data then
        alert("Failed to read motionbridge.json.")
        return false
    end

    if data.projectid ~= _G.project_id then
        alert("motionbridge folder belongs to a different project.")
        return false
    end

    -- Ensure required keys exist
    if not data.compositions then
        data.compositions = {}
        save_json_data(data)
    end
    
    return true
end

function require_initialisation()
    if not _G.project_media_path or not _G.json_path then
        alert("Please initialise by selecting a project folder first (click Browse).")
        return false
    end
    return true
end

-- FILE SYSTEM UTILITIES
function create_directory(path)
    local separator = package.config:sub(1,1)
    local is_windows = separator == '\\'
    
    -- Normalise path separators for the OS
    if is_windows then
        path = path:gsub("/", "\\")
    end
    
    local cmd
    if is_windows then
        cmd = string.format('mkdir "%s" 2>nul', path)
    else
        cmd = string.format('mkdir -p "%s"', path)
    end
    
    local ok = os.execute(cmd)
    if ok ~= true and ok ~= 0 then
        alert("Failed to create directory:\n" .. path)
        return false
    end
    return true
end

function directory_exists(path)
    local ok, _, code = os.rename(path, path)
    if ok then return true end

    -- On some platforms, rename fails but directory exists
    return code == 13  -- permission denied = exists
end

function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function is_video_file(filename)
    local lower = filename:lower()
    for _, ext in ipairs(_G.CONSTANTS.VIDEO_EXTENSIONS) do
        if lower:sub(-#ext) == ext then return true end
    end
    return false
end

-- GLOBAL REFRESHES
function version_check()
    local data = load_json_data(_G.json_path)
    local script_version = _G.CONSTANTS.MOTIONBRIDGE_VERSION
    local saved_version = data.motionBridgeVersion

    if saved_version ~= script_version then 
        alert("Version mismatch detected.\n\nProject version: " .. saved_version .. "\nScript version: " .. script_version .. "\n\nPlease use MotionBridge v" .. saved_version .. " in both AE and Resolve for this project.") 
        return false
    end
    return true 
end

function refresh_project_globals()
    local current_project = _G.resolve:GetProjectManager():GetCurrentProject()
    if not current_project then
        alert("No project open in DaVinci Resolve.")
        set_ui_enabled(false)
        return false
    end
    
    local current_project_id = current_project:GetUniqueId()
    
    if _G.json_path and file_exists(_G.json_path) then
        local data = load_json_data(_G.json_path)
        if data and data["projectid"] and current_project_id ~= data["projectid"] then 
            alert("DaVinci project changed. Please re-initialise by clicking Browse.")
            set_ui_enabled(false)
            return false
        end
    end
    
    _G.project = current_project
    _G.project_id = current_project_id
    _G.media_pool = _G.project:GetMediaPool()
    _G.root_folder = _G.media_pool:GetRootFolder()
    return true
end

function update_project_fps()
    -- Potential edge case:
        -- User changes project frame rate in Davinci without updating json, sends aecomp, then loads with mismatching fps
        -- Not currently an issue as Davinci doesn't allow project FPS changes once media imported 
    local data = load_json_data(_G.json_path)
    data["projectFPS"] = _G.project:GetSetting("timelineFrameRate")
    save_json_data(data)
end

function get_motionbridge_folders()
    _G.motionbridge_folder = get_or_create_folder(_G.root_folder, _G.CONSTANTS.FOLDER_NAMES.MOTIONBRIDGE)
    _G.comps_folder = get_or_create_folder(_G.motionbridge_folder, _G.CONSTANTS.FOLDER_NAMES.LINKEDCOMPS)
    _G.renders_folder = get_or_create_folder(_G.comps_folder, _G.CONSTANTS.FOLDER_NAMES.RENDERS)
    _G.compound_clips_folder = get_or_create_folder(_G.comps_folder, _G.CONSTANTS.FOLDER_NAMES.COMPOUNDCLIPS)
end 

-- JSON UTILITIES
local json = (function()
  -- Simple, safe JSON encode/decode (based on rxi/json.lua, modified for Resolve)
  local json = {}

  local function escape_str(s)
    local replacements = {
      ['"']  = '\\"',
      ['\\'] = '\\\\',
      ['\b'] = '\\b',
      ['\f'] = '\\f',
      ['\n'] = '\\n',
      ['\r'] = '\\r',
      ['\t'] = '\\t'
    }
    return s:gsub('[%z\1-\31\\"]', replacements)
  end

  function json.encode(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. escape_str(v) .. '"'
    elseif t == "table" then
      local is_array = (#v > 0)
      local result = {}
      if is_array then
        for i = 1, #v do table.insert(result, json.encode(v[i])) end
        return "[" .. table.concat(result, ",") .. "]"
      else
        for k, val in pairs(v) do
          table.insert(result, '"' .. tostring(k) .. '":' .. json.encode(val))
        end
        return "{" .. table.concat(result, ",") .. "}"
      end
    else
      return '"<unsupported type>"'
    end
  end

    function json.decode(str)
    -- Very small recursive JSON parser (handles strings, numbers, arrays, objects, booleans, null)
    local pos = 1
    local function skip_ws()
        local _, np = str:find("^[ \n\r\t]*", pos)
        pos = np + 1
    end

    local function parse_value()
        skip_ws()
        local ch = str:sub(pos, pos)
        if ch == "{" then
        pos = pos + 1
        local obj = {}
        skip_ws()
        if str:sub(pos, pos) == "}" then pos = pos + 1 return obj end
        while true do
            skip_ws()
            local key = parse_value()
            skip_ws()
            assert(str:sub(pos, pos) == ":", "Expected ':' after key")
            pos = pos + 1
            local val = parse_value()
            obj[key] = val
            skip_ws()
            local c = str:sub(pos, pos)
            if c == "}" then pos = pos + 1 break end
            assert(c == ",", "Expected ',' or '}'")
            pos = pos + 1
        end
        return obj
        elseif ch == "[" then
        pos = pos + 1
        local arr = {}
        skip_ws()
        if str:sub(pos, pos) == "]" then pos = pos + 1 return arr end
        while true do
            arr[#arr + 1] = parse_value()
            skip_ws()
            local c = str:sub(pos, pos)
            if c == "]" then pos = pos + 1 break end
            assert(c == ",", "Expected ',' or ']'")
            pos = pos + 1
        end
        return arr
        elseif ch == '"' then
        local i = pos + 1
        local s = {}
        while true do
            local c = str:sub(i, i)
            if c == '"' then break end
            if c == "\\" then
            local n = str:sub(i + 1, i + 1)
            local map = { b="\b", f="\f", n="\n", r="\r", t="\t", ['"']='"', ["\\"]="\\", ["/"]="/" }
            s[#s+1] = map[n] or n
            i = i + 2
            else
            s[#s+1] = c
            i = i + 1
            end
        end
        pos = i + 1
        return table.concat(s)
        elseif str:find("^%-?%d+%.?%d*[eE]?[+%-]?%d*", pos) then
        local num = str:match("^%-?%d+%.?%d*[eE]?[+%-]?%d*", pos)
        pos = pos + #num
        return tonumber(num)
        elseif str:sub(pos, pos + 3) == "true" then
        pos = pos + 4
        return true
        elseif str:sub(pos, pos + 4) == "false" then
        pos = pos + 5
        return false
        elseif str:sub(pos, pos + 3) == "null" then
        pos = pos + 4
        return nil
        else
        error("Unexpected character at position " .. pos .. ": " .. ch)
        end
    end

    local ok, result = pcall(parse_value)
    if not ok then error("JSON decode error: " .. tostring(result)) end
    return result
    end


  return json
end)()

function load_json_data(path)
    local file, err = io.open(path, "r")
    if not file then
        print("Error opening JSON file: " .. tostring(err))
        return nil
    end
    local content = file:read("*a")
    file:close()

    if not content or content:match("^%s*$") then
        print("JSON file empty, returning default structure.")
        return { projRenderTemplate = nil, compositions = {} }
    end

    local ok, result = pcall(function() return json.decode(content) end)
    if not ok then
        print("Error parsing JSON: " .. tostring(result))
        return { projRenderTemplate = nil, compositions = {} }
    end
    return result
end

function save_json_data(data)
    local encoded, encode_err = nil, nil
    local ok, result = pcall(function()
        return json.encode(data)
    end)

    if not ok then
        print("Error encoding JSON: " .. tostring(result))
        return false
    end

    local file, err = io.open(_G.json_path , "w")
    if not file then
        print("Error writing JSON file: " .. tostring(err))
        return false
    end

    file:write(result)
    file:close()
    return true
end

function write_compdata_tojson(nested_timeline_id, placeholder, linked_to_placeholder, comp_name, resolutionHeight, resolutionWidth, fps, duration)
    local data = load_json_data(_G.json_path ) or { projRenderTemplate = nil, compositions = {} }
    if not data["compositions"] then
        data["compositions"] = {}
    end

    local comp_entry = {
        name = comp_name,
        aeID = nil,
        renderPath = nil,
        fps = tostring(fps),
        resolutionHeight = tonumber(resolutionHeight),
        resolutionWidth = tonumber(resolutionWidth),
        duration = duration,
        compStartFrame = 0,
        layers = {},
        markers = {}
    }

    local record_frame_offset = placeholder:GetStart(true)

    local filtered_linked = {}
    for _, clip in ipairs(linked_to_placeholder) do
        if clip:GetName() ~= _G.CONSTANTS.PLACEHOLDER_TL_NAME then
            table.insert(filtered_linked, clip)
        end
    end

    -- Remove duplicate audio layers that share names with video items
    local video_names = {}
    for _, clip in ipairs(filtered_linked) do
        if clip:GetTrackTypeAndIndex()[1] == "video" then
            video_names[clip:GetName()] = true
        end
    end
    local final_linked = {}
    for _, clip in ipairs(filtered_linked) do
        local track_type = clip:GetTrackTypeAndIndex()[1]
        if not (track_type == "audio" and video_names[clip:GetName()]) then
            table.insert(final_linked, clip)
        end
    end

    for _, clip in ipairs(final_linked) do
        local media_item = clip:GetMediaPoolItem()
        local file_path = ""
        if media_item then
            local props = media_item:GetClipProperty()
            if props and props["File Path"] then
                file_path = props["File Path"]
            end
        end

        local track_info = clip:GetTrackTypeAndIndex()
        -- Known limitation: anchorpoints behave differently, so ommiting from layerData intentionally: AE (position + rotation) | Resolve (only rotation)
        table.insert(comp_entry["layers"], {
            layerName = clip:GetName(),
            filePath = file_path,
            mediaType = track_info[1],
            trackIndex = track_info[2],
            sourceStartFrame = clip:GetSourceStartFrame(),
            recordFrame = clip:GetStart(true) - record_frame_offset,
            duration = clip:GetDuration(true),
            zoomX = clip:GetProperty("ZoomX"),
            zoomY = clip:GetProperty("ZoomY"),
            pan = clip:GetProperty("Pan"),
            tilt = clip:GetProperty("Tilt"),
            rotationAngle = clip:GetProperty("RotationAngle"),
            flipX = tostring(clip:GetProperty("FlipX")), 
            flipY = tostring(clip:GetProperty("FlipY")), 
            opacity = clip:GetProperty("Opacity")
        })
    end

    local markers = placeholder:GetMarkers()
    if markers then
        for frame_id, marker_data in pairs(markers) do
            local color_name = marker_data["color"] or ""
            local color_index = get_marker_color_index(color_name)
            table.insert(comp_entry["markers"], {
                name = marker_data["name"] or "",
                note = (marker_data["note"] or ""):gsub("\n", ""),
                recordFrame = frame_id,
                duration = marker_data["duration"] or 0,
                color = color_index
            })
        end
    end

    data["compositions"][nested_timeline_id] = comp_entry
    local ok = save_json_data(data)
    if ok then
        print("Added/updated composition in JSON for " .. comp_name)
    else
        print("Failed to write JSON data.")
    end
end

-- POPUP UTILITIES
function show_dialog(config)
    -- config: {title, message, buttons = {"OK"} or {"Yes", "No"}}
    if not _G.disp then
        print("[" .. (config.title or "DIALOG") .. "]", config.message)
        return #config.buttons == 1 
    end

    local newlines = select(2, config.message:gsub("\n", "\n"))
    local est_lines = math.ceil(#config.message / 60)
    local total_lines = math.max(newlines + 1, est_lines)
    local height = math.min(150 + total_lines * 18, 450)
    local result = false
    local button_widgets = {}
    
    for i, btn_text in ipairs(config.buttons) do
        table.insert(button_widgets, _G.ui:Button{
            ID = "Btn" .. i,
            Text = btn_text,
            MinimumSize = {80, 30}
        })
    end

    local win = _G.disp:AddWindow({
        ID = "Dialog_" .. tostring(os.time()),
        WindowTitle = config.title or "Dialog",
        Geometry = {400, 300, 440, height},
        _G.ui:VGroup{
            Spacing = 10,
            _G.ui:Label{
                Text = config.message,
                WordWrap = true,
                Alignment = {AlignHCenter = true, AlignVCenter = true}
            },
            _G.ui:HGroup{
                Weight = 0,
                Spacing = 20,
                Alignment = {AlignHCenter = true},
                table.unpack(button_widgets)
            }
        }
    })

    for i = 1, #config.buttons do
        win.On["Btn" .. i].Clicked = function()
            result = (i == #config.buttons) 
            _G.disp:ExitLoop()
        end
    end

    win.On["Dialog_.Close"] = function()
        _G.disp:ExitLoop()
    end

    win:Show()
    _G.disp:RunLoop()
    win:Hide()
    
    return result
end

function alert(message)
    show_dialog({
        title = "Alert",
        message = message,
        buttons = {"OK"}
    })
end

function confirm(message)
    return show_dialog({
        title = "Confirm",
        message = message,
        buttons = {"No", "Yes"}
    })
end

function prompt_custom_settings()
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)

    local win = disp:AddWindow({
        ID = "CustomRes_" .. os.time(),
        WindowTitle = "Custom AE Comp Resolution",
        Geometry = {950, 400, 300, 150},
        ui:VGroup{
            ui:HGroup{
                ui:Label{ Text = "Width", Weight = 0.25 },
                ui:LineEdit{ ID = "width", Text = tostring(_G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_WIDTH), Weight = 0.75 }
            },
            ui:HGroup{
                ui:Label{ Text = "Height", Weight = 0.25 },
                ui:LineEdit{ ID = "height", Text = tostring(_G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_HEIGHT), Weight = 0.75 }
            },
            ui:HGroup{
                ui:Button{ ID = "ok", Text = "OK" },
                ui:Button{ ID = "cancel", Text = "Cancel" }
            }
        }
    })

    local items = win:GetItems()

    function win.On.ok.Clicked(ev)
        disp:ExitLoop({
            customResolutionWidth = tonumber(items.width.Text) or _G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_WIDTH,
            customResolutionHeight = tonumber(items.height.Text) or _G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_HEIGHT
        })
    end

    function win.On.cancel.Clicked(ev)
        disp:ExitLoop(nil)
    end

    function win.On.CustomRes_.Close(ev)
        disp:ExitLoop(nil)
    end

    win:Show()
    local result = disp:RunLoop()
    win:Hide()

    return result
end

function show_help_window()
    if not _G.disp then
        print("[HELP] Help dialog not available")
        return
    end
    local BUTTON_COLOR_CSS = "QLabel { color: rgba(221, 251, 225, 1); }"
    local helpWin = _G.disp:AddWindow({
        ID = "HelpDialog",
        WindowTitle = "How MotionBridge Works",
        Geometry = {300, 500, 500, 600},
        ui:VGroup{
            FixedSize = { 500, 560 },
            ID = "root",
            Weight = 0, 

            ui:VGroup{
                Weight = 0,
                ui:Label{ Text = "Getting Started", StyleSheet = TITLE_CSS, Alignment = {AlignCenter = true} },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "•", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.openFolder .. " Browse", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "to initialise/connect to current project motionbridge folder.", Weight = 1, WordWrap = true }
                },
                ui:Label{
                    Text = "• Then connect AE Project by navigating to motionbridge folder from there.\n" ..
                           "• Each project has its own motionbridge folder, with subfolders:\n" ..
                           "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Renders: all renders from AE\n" ..
                           "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Support: JSON file which contains link data",
                    WordWrap = true,
                    Alignment = {AlignLeft = true, AlignTop = true}
                },
                ui:Label{ FrameStyle = 4, Weight = 0 }
            },
            
            ui:VGroup{
                Weight = 0,
                ui:Label{ Text = "Linking Compositions with After Effects " .. _G.CONSTANTS.ICONS.upArrow .. " | " .. _G.CONSTANTS.ICONS.downArrow, StyleSheet = TITLE_CSS, Alignment = {AlignCenter = true} },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "•", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.downArrow .. " Import Linked Comps", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button retrieves new compositions from AE", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Click", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.upArrow .. " Link Active Comp", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button on AE side to establish the link", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "•", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.upArrow .. " Replace Linked Layers With Nested AE Comp", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "to send to AE", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Click", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.downArrow .. " Import Linked Comps", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "on AE side to finalise the link", Weight = 1, WordWrap = true }
                },
                ui:Label{ FrameStyle = 4, Weight = 0 }
            },
            
            ui:VGroup{
                Weight = 0,
                ui:Label{ Text = "Markers " .. _G.CONSTANTS.ICONS.upTriangle .. " | " .. _G.CONSTANTS.ICONS.downTriangle, StyleSheet = TITLE_CSS, Alignment = {AlignCenter = true} },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "•", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.upTriangle .. " Export Markers", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button sends markers from timeline to AE comp", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Click", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.downTriangle .. " Import Markers", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button on AE side to update", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "•", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.downTriangle .. " Import Markers", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button receives markers from AE", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Click", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.upTriangle .. " Export Markers", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button on AE side to send from MotionBridgeMarkers", Weight = 1, WordWrap = true }
                },
                ui:Label{ FrameStyle = 4, Weight = 0 }
            },
            
            ui:VGroup{
                Weight = 0,
                ui:Label{ Text = "Renders " .. _G.CONSTANTS.ICONS.refresh, StyleSheet = TITLE_CSS, Alignment = {AlignCenter = true} },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "•", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.refresh .. " Refresh Render", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "button updates timeline nest with latest AE render", Weight = 1, WordWrap = true }
                },
                ui:HGroup{
                    Spacing = 5,
                    ui:Label{ Text = "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Click", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.plus .. " Queue", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "or", Weight = 0 },
                    ui:Label{ Text = _G.CONSTANTS.ICONS.play .. " Render", Weight = 0, StyleSheet = BUTTON_COLOR_CSS },
                    ui:Label{ Text = "buttons on AE side to generate new renders", Weight = 1, WordWrap = true }
                },
                ui:Label{
                    Text = "       " .. _G.CONSTANTS.ICONS.downRightArrow .. " Renders appear in '.../media/motionbridge/renders' folder",
                    WordWrap = true,
                    Alignment = {AlignLeft = true, AlignTop = true}
                }
            },
            ui:Label{ FrameStyle = 4, Weight = 0 },
            ui:Button{ ID = "LearnMore", Text = "Learn More", Weight = 0 }
        }
    })
    
    helpWin.On.LearnMore.Clicked = function()
        bmd.openurl(_G.CONSTANTS.WEBSITEURL)
    end
    
    helpWin.On.HelpDialog.Close = function()
        _G.disp:ExitLoop()
    end
    
    helpWin:RecalcLayout()
    helpWin:Show()
    _G.disp:RunLoop()
    helpWin:Hide()
end

function show_paginated_selection_dialog(config)
    -- config: {title, items, page_size, on_confirm}
    if #config.items == 0 then return nil end
    
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)
    
    local page_size = config.page_size or _G.CONSTANTS.PAGE_SIZE
    local total = #config.items
    local total_pages = math.ceil(total / page_size)
    local current_page = 1
    local selections = {}
    for i = 1, total do selections[i] = false end
    local cancelled = false
    
    local function page_range(page)
        local s = (page - 1) * page_size + 1
        local e = math.min(s + page_size - 1, total)
        return s, e
    end
    
    local checkboxes = {}
    local list_items = {}
    for i = 1, page_size do
        list_items[i] = ui:CheckBox{
            ID = "cb" .. i,
            Text = "",
            Checked = false,
            Visible = false
        }
    end
    
    local win = disp:AddWindow({
        ID = "PaginatedSelection_" .. os.time(),
        WindowTitle = config.title or "Select Items",
        Geometry = {300, 200, 700, 480},
        ui:VGroup{
            ui:Label{ ID = "TopLabel", Text = config.message or "Select items:", WordWrap = true },
            ui:VGap(6),
            ui:VGroup(list_items),
            ui:VGap(6),
            ui:HGroup{
                ui:Button{ ID = "Prev", Text = _G.CONSTANTS.ICONS.leftArrow .. " Prev" },
                ui:Label{ ID = "PageLabel", Text = "", Alignment = {AlignHCenter = true} },
                ui:Button{ ID = "Next", Text = "Next " ..  _G.CONSTANTS.ICONS.rightArrow },
                Weight = 0
            },
            ui:VGap(6),
            ui:HGroup{
                ui:Button{ ID = "Cancel", Text = "Cancel" },
                ui:Button{ ID = "SelectAll", Text = "Select All" },
                ui:Button{ ID = "Confirm", Text = config.confirm_text or "Confirm" }
            }
        }
    })
    
    local items = win:GetItems()
    for i = 1, page_size do
        checkboxes[i] = items["cb" .. i]
    end
    
    local function build_page(page)
        local s, e = page_range(page)
        local num_on_page = e - s + 1
        
        for display_idx = 1, page_size do
            local cb = checkboxes[display_idx]
            local file_idx = s + display_idx - 1
            
            if display_idx <= num_on_page then
                local item = config.items[file_idx]
                local display = item
                if #display > _G.CONSTANTS.FILE_DISPLAY_MAX_LENGTH then
                    display = "..." .. display:sub(-(_G.CONSTANTS.FILE_DISPLAY_MAX_LENGTH - 3))
                end
                
                cb.Text = display
                cb.ToolTip = item
                cb.Checked = selections[file_idx]
                cb.Visible = true
            else
                cb.Visible = false
            end
        end
        
        items.PageLabel.Text = "Page " .. page .. " / " .. total_pages
    end
    
    local function sync_page_selection()
        local s, e = page_range(current_page)
        for display_idx = 1, (e - s + 1) do
            local file_idx = s + display_idx - 1
            selections[file_idx] = checkboxes[display_idx].Checked
        end
    end
    
    function win.On.Prev.Clicked(ev)
        sync_page_selection()
        if current_page > 1 then
            current_page = current_page - 1
            build_page(current_page)
        end
    end
    
    function win.On.Next.Clicked(ev)
        sync_page_selection()
        if current_page < total_pages then
            current_page = current_page + 1
            build_page(current_page)
        end
    end
    
    function win.On.SelectAll.Clicked(ev)
        local s, e = page_range(current_page)
        for i = s, e do
            selections[i] = true
        end
        build_page(current_page)
    end
    
    function win.On.Cancel.Clicked(ev)
        cancelled = true
        disp:ExitLoop()
    end
    
    function win.On.Confirm.Clicked(ev)
        sync_page_selection()
        
        local selected = {}
        for i = 1, total do
            if selections[i] then
                table.insert(selected, config.items[i])
            end
        end
        
        if #selected == 0 then
            alert("No items selected.")
            return
        end
        
        disp:ExitLoop(selected)
    end
    
    function win.On.PaginatedSelection_.Close(ev)
        cancelled = true
        disp:ExitLoop()
    end
    
    build_page(current_page)
    win:Show()
    local result = disp:RunLoop()
    win:Hide()
    
    return cancelled and nil or result
end

-- RESOLVE/PROJECT HELPERS
function get_mpi_by_name(name, folder)
    folder = folder or _G.media_pool:GetRootFolder()
    local clips = folder:GetClipList()

    for _, clip in ipairs(clips) do
        if clip:GetName() == name then
            return clip
        end
    end

    for _, sub in ipairs(folder:GetSubFolderList()) do
        local found = get_mpi_by_name(name, sub)
        if found then
            return found
        end
    end

    return nil
end

function get_timeline_mpi(timeline)
    -- Check if GetMediaPoolItem method exists (V20+)
    if timeline.GetMediaPoolItem then
        local mpi = timeline:GetMediaPoolItem()
        if mpi then
            return mpi
        end
    end
    
    -- Fallback for V19
    return get_mpi_by_name(timeline:GetName())
end

function get_timeline_byID(id)
    if not id then
        print("Error: get_timeline_byID() called with nil ID.")
        return nil
    end
    
    local count = _G.project:GetTimelineCount()
    for i = 1, count do
        local tl = _G.project:GetTimelineByIndex(i)
        local item = get_timeline_mpi(tl)
        if item and item:GetMediaId() == id then
            return tl
        end
    end
    
    return nil
end

function set_a1_v1_tracks_locked(timeline, bool) 
    timeline:SetTrackLock("video", 1, bool)
    timeline:SetTrackLock("audio", 1, bool)
end

function get_or_create_folder(parent, name)
    for _, bin in ipairs(parent:GetSubFolderList()) do
        if bin:GetName() == name then return bin end
    end
    local new_folder = _G.project:GetMediaPool():AddSubFolder(parent, name)
    return new_folder
end

function step_timeline_frames(timeline, offset)
    local fps = timeline:GetSetting("timelineFrameRate")
    local h, m, s, f = string.match(timeline:GetCurrentTimecode(), "(%d+):(%d+):(%d+):(%d+)")
    local total = (h * 3600 + m * 60 + s) * fps + f + offset
    total = math.max(total, 0)
    local nh = math.floor(total / (3600 * fps))
    local nm = math.floor(total / (60 * fps) % 60)
    local ns = math.floor(total / fps % 60)
    local nf = total % fps
    timeline:SetCurrentTimecode(string.format("%02d:%02d:%02d:%02d", nh, nm, ns, nf))
end

function is_unique_timelinename(name)
    local count = _G.project:GetTimelineCount()
    for i = 1, count do
        local tl = _G.project:GetTimelineByIndex(i)
        if tl:GetName() == name then
            return false
        end
    end
    return true
end

function timecode_to_frame(timecode, fps)
    local h, m, s, f = timecode:match("(%d+):(%d+):(%d+):(%d+)")
    h, m, s, f = tonumber(h), tonumber(m), tonumber(s), tonumber(f)
    
    -- Simply use nominal (rounded) FPS for timecode calculation - Timecode ALWAYS displays at integer rates
    local nominal_fps = math.floor(fps + 0.5)
    
    return (h * 3600 + m * 60 + s) * nominal_fps + f
end

function frame_to_timecode(frame_number, fps)
    local nominal_fps = math.floor(fps + 0.5)
    local frames = frame_number % nominal_fps
    local total_seconds = math.floor(frame_number / nominal_fps)
    local secs = total_seconds % 60
    local total_minutes = math.floor(total_seconds / 60)
    local mins = total_minutes % 60
    local hours = math.floor(total_minutes / 60)
    return string.format("%02d:%02d:%02d:%02d", hours, mins, secs, frames)
end

function is_track_free(timeline, track_type, track_index, start_frame, end_frame)
    local items = timeline:GetItemsInTrack(track_type, track_index) or {}
    for _, item in pairs(items) do
        local clip_start = item:GetStart(true)
        local clip_end = item:GetEnd(true)
        if (clip_start < end_frame) and (clip_end > start_frame) then
            return false
        end
    end
    return true
end

function get_lowest_available_track(timeline, track_type, start_frame, end_frame)
    local track_count = timeline:GetTrackCount(track_type)

    for track = 1, track_count do
        if is_track_free(timeline, track_type, track, start_frame, end_frame) then
            return track
        end
    end

    timeline:AddTrack(track_type)
    return track_count + 1
end

function get_or_make_top_track(timeline, track_type, start_frame, end_frame)
    local track_count = timeline:GetTrackCount(track_type)
    local top_track = track_count > 0 and track_count or 1

    if track_count == 0 then
        timeline:AddTrack(track_type)
        return 1
    end

    if not is_track_free(timeline, track_type, top_track, start_frame, end_frame) then
        print("Top track occupied, adding new " .. track_type .. " track")
        timeline:AddTrack(track_type)
        return track_count + 1
    end

    return top_track
end

function link_and_color_clips(timeline, video_clip, audio_clip, color)
    timeline:SetClipsLinked({video_clip, audio_clip}, true)
    video_clip:SetClipColor(color)
    audio_clip:SetClipColor(color)
end

-- CONTEXT-SPECIFIC OPERATIONS
function resolve_context(data)
    local project = _G.project
    local current_timeline = project:GetCurrentTimeline()
    if not current_timeline then
        print("Error: No current timeline.")
        return nil
    end

    local item = get_timeline_mpi(current_timeline)
    if not item then
        print("Error: No media pool item for current timeline.")
        return nil
    end

    local current_id = item:GetMediaId()
    local compositions = data.compositions or {}

    -- CASE A: We are inside a nested timeline
    if compositions[current_id] then
        local updated_data = sync_timeline_properties(
            current_timeline,
            compositions[current_id],
            current_id
        )
        if not updated_data then return nil end
        delete_obsolete_nests(updated_data)

        return {
            mode = "nested",
            active_timeline = current_timeline,
            parent_timeline = nil,
            nested_timeline = current_timeline,
            parent_clip = nil,
            comp = updated_data.compositions[current_id],
            comp_id = current_id,
            updated_data = updated_data
        }
    end

    -- CASE B: Parent timeline with nested clip selected
    local clip = current_timeline:GetCurrentVideoItem()
    if not clip then
        print("No active clip selected in parent timeline.")
        return nil
    end

    local clip_item = clip:GetMediaPoolItem()
    if not clip_item then
        print("Error: Clip has no media pool item.")
        return nil
    end

    local nested_id = clip_item:GetMediaId()
    local nested_timeline = get_timeline_byID(nested_id)
    if not nested_timeline then
        print("Error: Could not find nested timeline for ID " .. tostring(nested_id))
        return nil
    end

    local comp = compositions[nested_id]
    if not comp then
        print("Error: No composition entry for nested timeline.")
        return nil
    end

    local updated_data = sync_timeline_properties(
        nested_timeline,
        comp,
        nested_id
    )
    if not updated_data then return nil end
    delete_obsolete_nests(updated_data)

    return {
        mode = "parent",
        active_timeline = nested_timeline,
        parent_timeline = current_timeline,
        nested_timeline = nested_timeline,
        parent_clip = clip,
        comp = updated_data.compositions[nested_id],
        comp_id = nested_id,
        updated_data = updated_data
    }
end

function get_context_help_message(button_name)
    local messages = {
        markers = "To use markers:\n\n• Work inside a linked nested timeline, OR\n• Bring playhead over a nested clip in parent timeline",
        refresh = "To refresh render:\n\n• Work inside a linked nested timeline, OR\n• Bring playhead over a nested clip in parent timeline",
        replace = "To replace with nested comp:\n\n1. Insert placeholder timeline at playhead\n2. Link clips to placeholder\n3. Click this button with placeholder selected"
    }
    return messages[button_name] or "Operation failed. Check console for details."
end

function sync_timeline_properties(timeline, comp_data, comp_id)
    -- Returns: updated_data or nil (if user cancels)
    local current_name = timeline:GetName()
    local current_fps = tonumber(timeline:GetSetting("timelineFrameRate"))
    
    local saved_name = comp_data.name
    local saved_fps = tonumber(comp_data.fps)
    
    local changes = {}
    local needs_update = false
    
    -- Check FPS mismatch
    if saved_fps ~= current_fps then
        needs_update = true
        table.insert(changes, "Frame Rate: " .. saved_fps .. " → " .. current_fps)
    end
    
    -- Check name mismatch
    if saved_name ~= current_name then
        local data = load_json_data(_G.json_path)
        for id, other_comp in pairs(data.compositions) do
            if id ~= comp_id and other_comp.name == current_name then
                alert("Cannot use name '" .. current_name .. "' – another composition already uses this name.\n\nPlease rename timeline or resolve the conflict.")
                return nil
            end
        end
        
        needs_update = true
        table.insert(changes, "Name: '" .. saved_name .. "' → '" .. current_name .. "'")
    end
    
    -- If no changes, return data unchanged
    if not needs_update then
        return load_json_data(_G.json_path)
    end
    
    local change_summary = table.concat(changes, "\n")
    local confirm_msg = "Timeline properties have changed:\n\n" .. 
                       change_summary .. 
                       "\n\nUpdate saved properties to match current timeline?"
    
    if not confirm(confirm_msg) then
        alert("Operation cancelled. Please revert timeline changes or update saved properties.")
        return nil
    end
    
    local data = load_json_data(_G.json_path)
    if current_fps ~= saved_fps then
        data.compositions[comp_id].fps = tostring(current_fps)
    end
    if current_name ~= saved_name then
        data.compositions[comp_id].name = current_name
    end
    
    save_json_data(data)
    print("Synced timeline properties for: " .. current_name)
    
    return data
end

-- MARKER OPERATIONS
function get_marker_color_index(color)
    for i, c in ipairs(_G.CONSTANTS.MARKER_COLORS) do
        if c == color then return i - 1 end
    end
    return 0
end

function add_markers_to_target(target, markers)
    target:DeleteMarkersByColor("All")
    local count = 0
    for _, m in ipairs(markers) do
        if target:AddMarker(
            m.frame,
            m.color or "Blue",
            (m.name and m.name ~= "") and m.name or " ",
            m.note or "",
            (tonumber(m.duration) or 1) < 1 and 1 or tonumber(m.duration)
        ) then
            count = count + 1
        end
    end
    return count
end


function add_markers_to_clip(clip)
    local mpi = clip:GetMediaPoolItem()
    if not mpi then return end

    local source_timeline = get_timeline_byID(mpi:GetMediaId())
    if not source_timeline then
        print("Could not find source timeline for clip markers.")
        return
    end

    local source_markers = source_timeline:GetMarkers()
    if not source_markers then return end

    local in_frame = clip:GetSourceStartFrame()
    local out_frame = clip:GetSourceEndFrame()

    local markers = {}

    for frame, data in pairs(source_markers) do
        if frame >= in_frame and frame <= out_frame then
            table.insert(markers, {
                frame = frame - in_frame,
                color = data.color or "Blue",
                name = data.name or "",
                note = data.note or "",
                duration = data.duration or 1
            })
        end
    end

    add_markers_to_target(clip, markers)
end

function add_markers_to_timeline(timeline, saved_comp)
    local markers = {}
    local src = saved_comp["markers"] or {}

    for _, m in ipairs(src) do
        local color_idx = tonumber(m.color) or 0
        local color = _G.CONSTANTS.MARKER_COLORS[color_idx + 1] or "Blue"

        table.insert(markers, {
            frame = tonumber(m.recordFrame),
            color = color,
            name = m.name,
            note = m.note,
            duration = m.duration
        })
    end

    local count = add_markers_to_target(timeline, markers)
    print("Imported " .. tostring(count) .. " markers to " .. timeline:GetName())
end

function import_markers()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    local ctx = resolve_context(data)
    if not ctx then return end

    save_json_data(ctx.updated_data)

    add_markers_to_timeline(ctx.active_timeline, ctx.comp)

    if ctx.parent_clip then
        add_markers_to_clip(ctx.parent_clip)
    end
    return true
end

function export_markers()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    local ctx = resolve_context(data)
    if not ctx then return end

    local source_markers, source_name
    
    if ctx.parent_clip then
        -- On parent timeline: export from CLIP markers (what user sees on parent)
        source_markers = ctx.parent_clip:GetMarkers() or {}
        source_name = "clip '" .. ctx.parent_clip:GetName() .. "'"
        
        -- Convert clip-relative frames to nested-timeline frames
        local json_markers = {}
        for frame, m in pairs(source_markers) do
            table.insert(json_markers, {
                name = m.name or "",
                note = m.note or "",
                recordFrame = frame,  -- Already relative to nested timeline start
                duration = m.duration or 0,
                color = get_marker_color_index(m.color or "Blue")
            })
        end
        
        ctx.comp.markers = json_markers
        save_json_data(ctx.updated_data)
        
        -- Push markers into nested timeline
        _G.project:SetCurrentTimeline(ctx.active_timeline)
        add_markers_to_timeline(ctx.active_timeline, ctx.comp)
        _G.project:SetCurrentTimeline(ctx.parent_timeline)
        
        print("Exported " .. #json_markers .. " markers from " .. source_name .. " to JSON + nested timeline")
        return true
    else
        -- Inside nested timeline: export from TIMELINE markers
        source_markers = ctx.active_timeline:GetMarkers() or {}
        source_name = "timeline '" .. ctx.active_timeline:GetName() .. "'"
        
        local json_markers = {}
        for frame, m in pairs(source_markers) do
            table.insert(json_markers, {
                name = m.name or "",
                note = m.note or "",
                recordFrame = frame,
                duration = m.duration or 0,
                color = get_marker_color_index(m.color or "Blue")
            })
        end
        
        ctx.comp.markers = json_markers
        save_json_data(ctx.updated_data)
        
        print("Exported " .. #json_markers .. " markers from " .. source_name .. " to JSON")
        return true
    end
end

-- SENDING/RECEIVING LINK AE
function insert_placeholder_timeline_at_playhead()
    if not require_initialisation() then return end
    if not _G.media_pool then
        print("Error: Could not access Media Pool.")
        return
    end

    if _G.resolve:GetCurrentPage() == "media" then return false end

    local placeholder_timeline = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not placeholder_timeline then
        print("Error: 'MotionBridgePlaceholder' not found in Media Pool.")
        return
    end

    local current_timeline = _G.project:GetCurrentTimeline()
    if not current_timeline then
        print("Error: No active timeline.")
        return
    end

    local fps = tonumber(current_timeline:GetSetting("timelineFrameRate"))
    local playhead_frame = timecode_to_frame(current_timeline:GetCurrentTimecode(), fps)
    playhead_frame = math.floor(playhead_frame + 0.5) -- Round to nearest integer frame
    
    local duration_frames = math.floor(_G.CONSTANTS.PLACEHOLDER_DURATION * fps)
    local end_frame = playhead_frame + duration_frames

    local video_track_index = get_or_make_top_track(current_timeline, "video", playhead_frame, end_frame)

    local appended = _G.media_pool:AppendToTimeline({{ mediaPoolItem = placeholder_timeline, startFrame = 0, endFrame = duration_frames, mediaType = 1, trackIndex = video_track_index, recordFrame = playhead_frame }})
    
    if appended and #appended > 0 then
        appended[1]:SetClipColor("Purple")
    end
    return true
end

function nested_timeline_has_audio(timeline)
    local audio_track_count = timeline:GetTrackCount("audio")
    
    for track = 1, audio_track_count do
        local clips = timeline:GetItemListInTrack("audio", track)
        if clips and #clips > 0 then
            return true
        end
    end
    
    return false
end

function is_track_range_free(timeline, track_type, track_index, start_frame, end_frame)
    if track_index > timeline:GetTrackCount(track_type) then -- Check if track exists
        return false
    end
    
    local clips = timeline:GetItemListInTrack(track_type, track_index)
    if not clips then
        return true 
    end
    
    -- Check for overlap with any existing clip
    for _, clip in ipairs(clips) do
        local clip_start = clip:GetStart()
        local clip_end = clip:GetEnd()
        
        if not (end_frame <= clip_start or start_frame >= clip_end) then
            return false
        end
    end
    
    return true
end

function get_available_track_pair(timeline, start_frame, end_frame, preferred_track_index, needs_audio)
    local video_track_count = timeline:GetTrackCount("video")
    local audio_track_count = timeline:GetTrackCount("audio")
    local track_index = preferred_track_index
    
    while true do
        if track_index > video_track_count then
            timeline:AddTrack("video")
            video_track_count = video_track_count + 1
        end
        
        local video_free = is_track_range_free(timeline, "video", track_index, start_frame, end_frame)
        
        if video_free then
            if needs_audio then
                if track_index > audio_track_count then
                    while audio_track_count < track_index do
                        timeline:AddTrack("audio")
                        audio_track_count = audio_track_count + 1
                    end
                end
                
                local audio_free = is_track_range_free(timeline, "audio", track_index, start_frame, end_frame)
                
                if audio_free then
                    return track_index -- Found a suitable pair
                end
            else
                -- No audio needed, just return the free video track
                return track_index
            end
        end
        
        track_index = track_index + 1
        
        if track_index > _G.CONSTANTS.SEARCH_SAFETY_LIMIT then
            alert("Warning: Could not find available track after checking 100 tracks. Delete empty tracks and try again.")
            return preferred_track_index
        end
    end
end

function replace_linked_with_aecomp(comp_name, use_custom_settings, custom_settings)
    if not require_initialisation() then return end
    get_motionbridge_folders()
    local placeholder_timeline = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not comp_name or comp_name:match("^%s*$") then
        alert("Please enter a valid composition name.")
        return
    end
    local base_timeline = _G.project:GetCurrentTimeline()
    local placeholder = base_timeline:GetCurrentVideoItem()

    if not placeholder or placeholder:GetName() ~= placeholder_timeline:GetName() then
        alert("Error: No MotionBridgePlaceholder in top active video layer.")
        return
    end

    if not is_unique_timelinename(comp_name) then
        alert("Unable to Create Timeline - The timeline '" .. comp_name .. "' already exists in this project.")
        return
    end

    -- Placeholder info
    local linked_to_placeholder = placeholder:GetLinkedItems()
    local placeholder_startFrame = placeholder:GetSourceStartFrame()
    local placeholder_time_in_base_timeline = placeholder:GetStart(true)
    local placeholder_duration = math.floor(placeholder:GetDuration(true))
    local placeholder_endFrame = placeholder_startFrame + placeholder_duration
    local track_type, placeholder_trackIndex = table.unpack(placeholder:GetTrackTypeAndIndex())
    local placeholder_end_time = placeholder_time_in_base_timeline + placeholder_duration

    -- Create nested timeline 
    local nested_timeline = _G.media_pool:CreateEmptyTimeline(comp_name)
    local nested_timeline_mpi = get_timeline_mpi(nested_timeline)
    _G.media_pool:MoveClips({ nested_timeline_mpi }, _G.comps_folder)
    print("Placed '" .. comp_name .. "' in Compositions bin.")
    local nested_timeline_id = nested_timeline_mpi:GetMediaId()
    local resolutionHeight = base_timeline:GetSetting("timelineResolutionHeight")
    local resolutionWidth = base_timeline:GetSetting("timelineResolutionWidth")
    local fps = base_timeline:GetSetting("timelineFrameRate")

    -- Configure nested timeline 
    nested_timeline:SetStartTimecode(_G.CONSTANTS.TIMECODE.START)
    nested_timeline:SetTrackName("video", 1, _G.CONSTANTS.TRACK_NAMES.RENDER_VIDEO)
    nested_timeline:SetTrackName("audio", 1, _G.CONSTANTS.TRACK_NAMES.RENDER_AUDIO)
    nested_timeline:AddTrack("video")
    nested_timeline:AddTrack("audio")
    nested_timeline:SetTrackName("video", 2, _G.CONSTANTS.TRACK_NAMES.COMPOUND_CLIP)
    nested_timeline:SetTrackName("audio", 2, _G.CONSTANTS.TRACK_NAMES.COMPOUND_CLIP)

    if use_custom_settings then
        resolutionHeight = custom_settings.customResolutionHeight
        resolutionWidth = custom_settings.customResolutionWidth
        nested_timeline:SetSetting("UseCustomResolution", "1")
        nested_timeline:SetSetting("timelineResolutionHeight", tostring(resolutionHeight))
        nested_timeline:SetSetting("timelineResolutionWidth", tostring(resolutionWidth))
        print("Custom resolution applied: " .. resolutionWidth .. "x" .. resolutionHeight)
    end

    write_compdata_tojson(nested_timeline_id, placeholder, linked_to_placeholder, comp_name, resolutionHeight, resolutionWidth, fps, placeholder_duration)

    -- Transfer markers from placeholder to nested timeline
    local data = load_json_data(_G.json_path)
    if data and data.compositions and data.compositions[nested_timeline_id] then
        add_markers_to_timeline(nested_timeline, data.compositions[nested_timeline_id])
    end

    -- Lock tracks in nest, append placeholder in case nothing is linked
    _G.project:SetCurrentTimeline(nested_timeline)
    set_a1_v1_tracks_locked(nested_timeline, false) 
    if #linked_to_placeholder == 0 then 
        _G.media_pool:AppendToTimeline({{ 
            mediaPoolItem = placeholder:GetMediaPoolItem(), 
            startFrame = placeholder_startFrame, 
            endFrame = placeholder_endFrame, 
            trackIndex = 2, 
            recordFrame = 0 
        }}) 
    end
    set_a1_v1_tracks_locked(nested_timeline, true)

    -- Replace placeholder in base timeline with nested timeline
    _G.project:SetCurrentTimeline(base_timeline)
    base_timeline:DeleteClips({ placeholder }, false)

    if #linked_to_placeholder > 0 then
        local layers_in_compound = {}
        for _, clip in ipairs(linked_to_placeholder) do
            if clip:GetName() ~= _G.CONSTANTS.PLACEHOLDER_TL_NAME then
                table.insert(layers_in_compound, clip)
            end
        end
        if #layers_in_compound == 1 then 
            local clip = layers_in_compound[1]:GetMediaPoolItem()
            _G.project:SetCurrentTimeline(nested_timeline)
            _G.media_pool:AppendToTimeline({{ mediaPoolItem = clip, trackIndex = 2, recordFrame = 0 }})   
            _G.project:SetCurrentTimeline(base_timeline)
        elseif #layers_in_compound > 1 then
            local compound_name = comp_name .. _G.CONSTANTS.LINKED_CLIPS_SUFFIX
            base_timeline:CreateCompoundClip(layers_in_compound, { name = compound_name })
            local compound_mpi = get_mpi_by_name(compound_name)
            _G.media_pool:MoveClips({ compound_mpi }, _G.compound_clips_folder)
            if compound_mpi then
                _G.project:SetCurrentTimeline(nested_timeline)
                _G.media_pool:AppendToTimeline({{ mediaPoolItem = compound_mpi, trackIndex = 2, recordFrame = 0 }})
                _G.project:SetCurrentTimeline(base_timeline)
                
                local compound_clip = base_timeline:GetCurrentVideoItem()
                local linked_audio = compound_clip:GetLinkedItems()[1]
                if compound_clip and compound_clip:GetName() == compound_name then
                    base_timeline:DeleteClips({compound_clip, linked_audio}, false)
                end
            end
        end
        
        for _, clip in ipairs(linked_to_placeholder) do
            base_timeline:DeleteClips({ clip }, false)
        end
    end

    local has_audio = nested_timeline_has_audio(nested_timeline)

    local final_track_index = get_available_track_pair(
        base_timeline,
        placeholder_time_in_base_timeline,
        placeholder_end_time,
        placeholder_trackIndex,
        has_audio
    )
    
    if final_track_index ~= placeholder_trackIndex then
        print("Original track " .. placeholder_trackIndex .. " was occupied. Using track " .. final_track_index .. " instead.")
    end

    -- Append nested timeline to base timeline
    local nest_clip = _G.media_pool:AppendToTimeline({ 
        { 
            mediaPoolItem = nested_timeline_mpi, 
            trackIndex = final_track_index, 
            recordFrame = placeholder_time_in_base_timeline 
        } 
    })
    
    if not nest_clip or #nest_clip == 0 then
        alert("Error: Failed to append nested timeline to base timeline")
        return
    end
    
    nest_clip[1]:SetClipColor("Purple")
    local linked_audio = nest_clip[1]:GetLinkedItems()[1]
    if linked_audio then 
        linked_audio:SetClipColor("Purple")
    elseif has_audio then
        print("Bug: Nested timeline has audio but no audio was linked to the appended clip")
    end

    add_markers_to_clip(nest_clip[1])

    -- Prevent duplicate timeline bug in Compositions bin
    _G.media_pool:SetCurrentFolder(_G.root_folder)
    alert("Media successfully nested. Open script in After Effects to load composition.")
    return nested_timeline
end

function import_new_comps()
    if not require_initialisation() then return end
    
    local current_timeline = _G.project:GetCurrentTimeline()
    if not current_timeline then
        alert("No active timeline. Please open a timeline first.")
        return false
    end
    
    local data = load_json_data(_G.json_path)
    local prelink_pattern = _G.CONSTANTS.PRELINK_PATTERN

    -- STEP 1: Collect prelink keys, delete non-prelink entries which no longer exist
    local prelink_keys = {}
    local keys = {}
    for k in pairs(data.compositions) do table.insert(keys, k) end

    for _, key in ipairs(keys) do
        local entry = data.compositions[key]

        if type(key) == "string" and key:match(prelink_pattern) then
            table.insert(prelink_keys, key)
        else
            local timeline_id_exists = get_timeline_byID(key)
            if not timeline_id_exists then
                alert(
                    "Timeline: \"" ..
                    entry.name .. 
                    "\" no longer exists in the project, link deleted. Create a new link from AE if needed."
                )
                data.compositions[key] = nil
                save_json_data(data)
            end
        end
    end

    if #prelink_keys == 0 then
        alert("No new compositions found from After Effects.\n\nUse 'Link Active Comp' button in AE first.")
        return false
    end

    -- STEP 2: Process prelink entries and create timelines
    local created_timelines = {}
    
    for _, key in ipairs(prelink_keys) do
        local entry = data.compositions[key]
        if entry then
            _G.media_pool:SetCurrentFolder(_G.comps_folder)

            local new_timeline = _G.media_pool:CreateEmptyTimeline(entry.name)
            if not new_timeline then
                print("Skipping:", entry.name, "(could not create timeline)")
            else
                local timeline_mpi = get_timeline_mpi(new_timeline)
                new_timeline:SetSetting("UseCustomResolution", "1")
                new_timeline:SetSetting("timelineResolutionHeight", entry.resolutionHeight)
                new_timeline:SetSetting("timelineResolutionWidth", entry.resolutionWidth)
                
                local comp_start_frame = entry.compStartFrame
                local comp_start_timecode = frame_to_timecode(comp_start_frame, entry.fps)
                new_timeline:SetStartTimecode(comp_start_timecode)
                
                _G.project:SetCurrentTimeline(new_timeline)

                -- Add render or placeholder
                local render_path = entry.renderPath
                if render_path then 
                    refresh_render_in_timeline(new_timeline, entry)
                else
                    local placeholder_clip_data = {
                        mediaPoolItem = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME),
                        startFrame = 0,
                        endFrame = entry.duration,
                        mediaType = 1,
                        trackIndex = 1,
                        recordFrame = 0
                    }
                    _G.media_pool:AppendToTimeline({placeholder_clip_data})
                end

                add_markers_to_timeline(new_timeline, entry)

                local media_id = timeline_mpi:GetMediaId()
                local new_entry = {}
                for k2, v2 in pairs(entry) do new_entry[k2] = v2 end
                new_entry.mediaId = media_id

                -- Store for appending later
                table.insert(created_timelines, {
                    timeline = new_timeline,
                    mpi = timeline_mpi,
                    entry = new_entry,
                    media_id = media_id,
                    old_key = key
                })

                print("Created timeline:", entry.name, "with ID:", media_id)
            end
        end
    end

    if #created_timelines == 0 then
        alert("No compositions were successfully created.")
        return false
    end

    -- STEP 3: Update JSON with new IDs
    for _, tl_data in ipairs(created_timelines) do
        data.compositions[tl_data.old_key] = nil
        data.compositions[tostring(tl_data.media_id)] = tl_data.entry
    end
    save_json_data(data)

    -- STEP 4: Return to parent timeline and append created timelines
    _G.project:SetCurrentTimeline(current_timeline)
    
    local needs_audio = false
    for _, tl_data in ipairs(created_timelines) do
        if nested_timeline_has_audio(tl_data.timeline) then
            needs_audio = true
            break
        end
    end

    -- Calculate starting position and total duration
    local fps = tonumber(current_timeline:GetSetting("timelineFrameRate"))
    local playhead_frame = timecode_to_frame(current_timeline:GetCurrentTimecode(), fps)
    playhead_frame = math.floor(playhead_frame + 0.5)
    
    local total_duration = 0
    for _, tl_data in ipairs(created_timelines) do
        total_duration = total_duration + tl_data.entry.duration
    end
    
    local end_frame = playhead_frame + total_duration

    local track_index = get_available_track_pair(
        current_timeline,
        playhead_frame,
        end_frame,
        1,  -- Start searching from track 1
        needs_audio
    )

    -- Append each timeline sequentially
    local current_record_frame = playhead_frame
    
    for _, tl_data in ipairs(created_timelines) do
        local duration = tl_data.entry.duration        
        local video_appended = _G.media_pool:AppendToTimeline({
            {
                mediaPoolItem = tl_data.mpi,
                startFrame = 0,
                endFrame = duration,
                mediaType = 1,
                trackIndex = track_index,
                recordFrame = current_record_frame
            }
        })
        
        if video_appended and #video_appended > 0 then
            video_appended[1]:SetClipColor("Purple")
            
            if needs_audio and nested_timeline_has_audio(tl_data.timeline) then
                local audio_appended = _G.media_pool:AppendToTimeline({
                    {
                        mediaPoolItem = tl_data.mpi,
                        startFrame = 0,
                        endFrame = duration,
                        mediaType = 2,
                        trackIndex = track_index,
                        recordFrame = current_record_frame
                    }
                })
                
                if audio_appended and #audio_appended > 0 then
                    audio_appended[1]:SetClipColor("Purple")
                    current_timeline:SetClipsLinked({video_appended[1], audio_appended[1]}, true)
                end
            end
            
            print("Appended timeline:", tl_data.entry.name, "at frame:", current_record_frame)
        else
            print("Warning: Failed to append timeline:", tl_data.entry.name)
        end
        
        current_record_frame = current_record_frame + duration
    end

    alert("Successfully imported " .. #created_timelines .. " composition(s) from After Effects.")
    return true
end

-- RENDER MANAGEMENT
function refresh_render()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    local ctx = resolve_context(data)
    if not ctx then return end

    save_json_data(ctx.updated_data)

    -- Switch to nested timeline before refreshing render
    local switched = false
    if ctx.parent_timeline then
        _G.project:SetCurrentTimeline(ctx.active_timeline)
        switched = true
    end

    local ok = refresh_render_in_timeline(ctx.active_timeline, ctx.comp)
    
    if switched then
        _G.project:SetCurrentTimeline(ctx.parent_timeline)
    end
    
    if not ok then return false end

    if ctx.parent_clip then
        if attach_nested_audio(ctx.parent_timeline, ctx.parent_clip, ctx.active_timeline) then 
            step_timeline_frames(ctx.parent_timeline, -1)
            import_markers()
        end
    end

    return true
end

function refresh_render_in_timeline(timeline, comp_data)
    local initial_folder = _G.media_pool:GetCurrentFolder()
    local render_path_base = comp_data["renderPath"]
    if not render_path_base then
        alert("No render found for this composition. Please render from After Effects.")
        return false
    end

    local filename = render_path_base:match("([^/\\]+)$")
    if not filename then
        print("Error: Could not extract filename from renderPath: " .. tostring(render_path_base))
        return false
    end

    local basename = filename:match("(.+)%..+$") or filename
    local paths = build_project_paths(_G.project_media_path)
    local search_dir = paths.renders

    -- Cross-platform file finding using Lua's built-in functions
    local function find_matching_render(dir, base)
        local separator = package.config:sub(1,1)
        local is_windows = separator == '\\'
        
        -- Normalise directory path
        dir = dir:gsub("\\", "/")
        
        local handle
        if is_windows then
            handle = io.popen('dir /b "' .. dir:gsub('/', '\\') .. '" 2>nul')
        else
            handle = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
        end
        
        if not handle then return nil end
        
        -- Search through directory listing for matching basename
        for filename in handle:lines() do
            local file_base = filename:match("^(.+)%..+$")
            if file_base == base and is_video_file(filename) then
                handle:close()
                return dir .. "/" .. filename
            end
        end
        
        handle:close()
        return nil
    end

    local render_path = find_matching_render(search_dir, basename)

    if not render_path or render_path == "" then
        alert("No render found in folder: " .. search_dir .. " for base name: " .. basename .. ".")
        return false
    end

    _G.media_pool:SetCurrentFolder(_G.renders_folder)
    local imported = _G.media_pool:ImportMedia({ render_path })
    if not imported or #imported == 0 then
        print("Error: Failed to import render " .. render_path)
        return false
    end

    set_a1_v1_tracks_locked(timeline, false) 

    local v1_items = timeline:GetItemsInTrack("video", 1)
    if v1_items then for _, item in pairs(v1_items) do timeline:DeleteClips({item}) end end
    local a1_items = timeline:GetItemsInTrack("audio", 1)
    if a1_items then for _, item in pairs(a1_items) do timeline:DeleteClips({item}) end end

    local video_clip_data = { mediaPoolItem = imported[1], startFrame = 0, endFrame = comp_data["duration"], mediaType = 1, trackIndex = 1, recordFrame = 0 }
    local audio_clip_data = { mediaPoolItem = imported[1], startFrame = 0, endFrame = comp_data["duration"], mediaType = 2, trackIndex = 1, recordFrame = 0 }
    local appended_video = _G.media_pool:AppendToTimeline({video_clip_data})
    local appended_audio = _G.media_pool:AppendToTimeline({audio_clip_data})

    set_a1_v1_tracks_locked(timeline, true) 

    if appended_video and #appended_video > 0 then
        timeline:SetTrackEnable("video", 2, false) -- Hide compound clip
        timeline:SetTrackEnable("audio", 1, false) -- Mute render audio by default
        print("Imported render: " .. render_path)
        _G.media_pool:SetCurrentFolder(initial_folder)
        return true
    end

    print("Error: Failed to append render to timeline.")
    return false
end

function replace_render_after_refresh()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    local ctx = resolve_context(data)
    if not ctx then return end

    local timeline = ctx.active_timeline
    local parent_timeline = ctx.parent_timeline
    local switched = false

    if parent_timeline then
        _G.project:SetCurrentTimeline(timeline)
        switched = true
    end

    step_timeline_frames(timeline, -1)
    local clip = timeline:GetCurrentVideoItem()
    if not clip then
        print("No active video item to replace.")
    else
        local mpi = clip:GetMediaPoolItem()
        if not mpi then
            print("No media pool item on selected clip.")
        else
            local props = mpi:GetClipProperty() or {}
            local media_path =
                props["File Path"] or
                props["Filepath"] or
                props["Filename"]

            if not media_path then
                print("Could not determine media path for replacement.")
            else
                mpi:ReplaceClip(media_path)
            end
        end
    end

    if switched then
        _G.project:SetCurrentTimeline(parent_timeline)
    end
end

function attach_nested_audio(parent_timeline, parent_clip, nested_timeline)
    if not parent_clip then return end
    local parent_mpi = parent_clip:GetMediaPoolItem()
    if not parent_mpi then return end
    local parent_clip_id = parent_mpi:GetMediaId()

    local has_audio = false
    local audio_tracks = nested_timeline:GetTrackCount("audio")

    for t = 1, audio_tracks do
        local items = nested_timeline:GetItemsInTrack("audio", t)
        if items and next(items) then
            has_audio = true
            break
        end
    end

    if not has_audio then return end

    -- Detect previously linked nested audio
    local linked = parent_clip:GetLinkedItems() or {}
    for _, linked_clip in ipairs(linked) do
        local track_type, track_index = table.unpack(linked_clip:GetTrackTypeAndIndex())
        if track_type == "audio" then
            local mpi = linked_clip:GetMediaPoolItem()
            if mpi and mpi:GetMediaId() == parent_clip_id then
                -- return as soon as linked nest audio found
                return
            end
        end
    end

    -- Append audio + video from nested timeline (appending audio alone causes issues)
    local clip_start_frame = parent_clip:GetSourceStartFrame()
    local clip_duration = parent_clip:GetDuration(true)
    local record_frame = parent_clip:GetStart(true)

    -- Video clip gets replaced in same track
    local video_track_index = parent_clip:GetTrackTypeAndIndex()[2]
    parent_timeline:DeleteClips({parent_clip})
    local audio_track_index = get_lowest_available_track(parent_timeline, "audio", record_frame, record_frame + clip_duration)
    append_and_link_mpi(parent_timeline, get_timeline_mpi(nested_timeline), clip_start_frame, clip_duration, video_track_index, audio_track_index, record_frame, "Purple")
    return true
end

-- TODO(later once proxies included): Also detect & delete corresponding proxy files when proxy system is integrated.
function confirm_and_delete_unused_renders()
    local data = load_json_data(_G.json_path)
    if not data or not data.compositions then
        print("Error: Invalid data structure (missing 'compositions').")
        return nil
    end

    local unused_files = get_unused_render_files(data)
    if #unused_files == 0 then
        print("No unused video renders found.")
        return nil
    end

    unused_files = natural_sort_files(unused_files)

    local selected = show_paginated_selection_dialog({
        title = "Delete Unused Renders",
        message = "Select files to permanently delete:",
        items = unused_files,
        confirm_text = "Delete Selected"
    })
    
    if not selected then
        print("File deletion cancelled.")
        return nil
    end

    -- Single confirmation with preview
    local preview = table.concat(selected, "\n", 1, math.min(#selected, 10))
    if #selected > 10 then
        preview = preview .. "\n... and " .. (#selected - 10) .. " more"
    end
    
    if not confirm("Permanently delete " .. #selected .. " file(s)?\n\n" .. preview) then
        print("Deletion cancelled.")
        return nil
    end

    local deleted = {}
    
    local function delete_from_media_pool(folder, target_path)
        local norm_target = target_path:gsub("//", "/"):lower()
        
        for _, item in ipairs(folder:GetClipList()) do
            local clip_path = (item:GetClipProperty("File Path") or "")
            local norm_clip = clip_path:gsub("//", "/"):lower():gsub("^file://", "")
            
            if norm_clip == norm_target or norm_clip:match(norm_target .. "$") then
                _G.media_pool:DeleteClips({item})
                return true
            end
        end
        
        for _, sub in ipairs(folder:GetSubFolderList()) do
            if delete_from_media_pool(sub, target_path) then
                return true
            end
        end
        
        return false
    end
    
    for _, fp in ipairs(selected) do
        if _G.media_pool and _G.root_folder then
            delete_from_media_pool(_G.root_folder, fp)
        end
        
        if os.remove(fp) then
            table.insert(deleted, fp)
            print("Deleted: " .. fp)
        else
            print("Failed to delete: " .. fp)
        end
    end
    
    if #deleted > 0 then
        alert(#deleted .. " file(s) deleted.")
    end
    
    return deleted
end

function append_and_link_mpi(parent_timeline, media_pool_item, clip_start_frame, clip_duration, video_track_index, audio_track_index, record_frame, clip_color)
    local video_clip_data = {mediaPoolItem = media_pool_item, startFrame = clip_start_frame, endFrame = clip_start_frame + clip_duration, mediaType = 1, trackIndex = video_track_index, recordFrame = record_frame}
    local audio_clip_data = {mediaPoolItem = media_pool_item, startFrame = clip_start_frame, endFrame = clip_start_frame + clip_duration, mediaType = 2, trackIndex = audio_track_index, recordFrame = record_frame}
    local appended_video = _G.media_pool:AppendToTimeline({video_clip_data})
    local appended_audio = _G.media_pool:AppendToTimeline({audio_clip_data})
    if appended_video and appended_audio and #appended_video > 0 and #appended_audio > 0 then
        link_and_color_clips(parent_timeline, appended_video[1], appended_audio[1], clip_color)
    else
        print("Error: Failed to append media pool item to timeline.")
    end
end

function delete_obsolete_nests(data)
    local removed = 0
    local compositions = data["compositions"]

    -- Collect keys to remove (to avoid modifying table while iterating)
    local obsolete_ids = {}
    for davinci_id, _ in pairs(compositions) do
        if not get_timeline_byID(davinci_id) then
            table.insert(obsolete_ids, davinci_id)
        end
    end

    for _, id in ipairs(obsolete_ids) do
        compositions[id] = nil
        removed = removed + 1
        print("Removed obsolete entry: " .. tostring(id))
    end

    if removed > 0 then
        save_json_data(data)
        print("Removed " .. removed .. " obsolete composition(s) from JSON.")
    end
end

function remove_orphaned_render_mpis()
    -- Extra cleanup: remove unused (0-usage) media pool items in the Renders bin
    -- In case render file was overwitten with different duration - this causes an orphaned reference for the old longer render
    get_motionbridge_folders()

    if _G.renders_folder then
        local clips = _G.renders_folder:GetClipList()
        local removed_count = 0

        for _, clip in ipairs(clips) do
            local usage = tonumber(clip:GetClipProperty("Usage") or "0")
            if usage == 0 then
                local name = clip:GetName()
                local ok = _G.media_pool:DeleteClips({clip})
                if ok then
                    removed_count = removed_count + 1
                    print("Removed orphaned render reference: " .. name)
                else
                    print("Failed to remove clip from Media Pool: " .. name)
                end
            end
        end
    else
        print("Renders bin not found — skipping orphan cleanup.")
    end
end

function get_known_render_bases(data)
    local known_bases = {}
    for _, comp in pairs(data["compositions"]) do
        local render_path = comp["renderPath"]
        if render_path then
            local fname = render_path:match("([^/\\]+)$")
            local base = fname and fname:gsub("%.%w+$", "") or ""
            if base ~= "" then known_bases[base] = true end
        end
    end
    return known_bases
end

function get_unused_render_files(data)
    local paths = build_project_paths(_G.project_media_path)
    
    -- Cross-platform directory listing
    local separator = package.config:sub(1,1)
    local is_windows = separator == '\\'
    
    local search_dir = paths.renders:gsub("\\", "/")
    
    local handle
    if is_windows then
        handle = io.popen('dir /b "' .. search_dir:gsub('/', '\\') .. '" 2>nul')
    else
        handle = io.popen('ls -1 "' .. search_dir .. '" 2>/dev/null')
    end
    
    if not handle then
        print("Error: Could not access Renders directory: " .. tostring(search_dir))
        return {}
    end

    local known_bases = get_known_render_bases(data)
    local unused_files = {}
    
    for file in handle:lines() do
        if is_video_file(file) then
            local base = file:gsub("%.%w+$", "")
            if not known_bases[base] then
                table.insert(unused_files, search_dir .. "/" .. file)
            end
        end
    end
    handle:close()
    
    return unused_files
end

function natural_sort_files(files)
    local function tokenise_filename(path)
        local name = path:match("([^/\\]+)$") or path
        name = name:lower()

        local tokens = {}
        local i = 1
        local len = #name
        while i <= len do
            local s, e = name:find("%d+", i)
            if s then
                if s > i then
                    table.insert(tokens, name:sub(i, s-1))
                end
                table.insert(tokens, tonumber(name:sub(s, e)))
                i = e + 1
            else
                table.insert(tokens, name:sub(i))
                break
            end
        end
        return tokens
    end

    local function natural_compare(a, b)
        local ta = tokenise_filename(a)
        local tb = tokenise_filename(b)
        local na, nb = #ta, #tb
        local n = math.min(na, nb)

        for i = 1, n do
            local va, vb = ta[i], tb[i]
            local ta_type = type(va)
            local tb_type = type(vb)
            if ta_type == tb_type then
                if ta_type == "number" then
                    if va ~= vb then return va < vb end
                else
                    if va ~= vb then return va < vb end
                end
            else
                return ta_type == "number"
            end
        end
        return na < nb
    end

    table.sort(files, natural_compare)
    return files
end

--[[ PROXY generation (commented out; enable when API supports required ExportAlpha for H.265)
function generate_proxy()
    Intended flow:
    1) determine nested timeline or selected nested clip
    2) build proxy path under project_media_path .. "/Renders/Proxy"
    3) set render format/codec and render settings (H.265 + alpha once supported)
    4) add render job, start rendering, then LinkProxyMedia on corresponding clip
end
]]

-- GUI LAYOUT
_G.ui = fu.UIManager
_G.disp = bmd.UIDispatcher(ui)
local MainWindow = disp:AddWindow({
    ID = "MainWind",
    WindowTitle = "MotionBridge",
    Geometry = { 950, 400, 420, 360 },

    ui:VGroup{
        ID = "root",
        Spacing = 10,
        Weight = 0,
        MaximumSize = { 950, 390 }, 
        ui:Label{ Text = "Connect to Project Folder", Alignment = {AlignCenter = true}, Weight = 0, StyleSheet = TITLE_CSS },
        ui:VGroup{
            ID = "ConnectToProjectPanel",
            ToolTip = "Click Browse and navigate to the current project's Media folder.\nImportant: Each project has its own separate motionbridge folder.",
            Weight = 0,
            Spacing = 5,
            ui:HGroup{
                Weight = 0,
                ui:Label{ ID = "FolderLabel", Text = "Folder Path:", Weight = 0.18 },
                ui:LineEdit{ ID = "FolderPath", PlaceholderText = "Select a folder...", ReadOnly = true, Weight = 0.62 },
                ui:Button{ ID = "Browse", Text = _G.CONSTANTS.ICONS.openFolder .. " Browse", Weight = 0.20 }
            },
            ui:HGroup{
                Weight = 0,
                ui:Button{ ID = "ImportNewComps", Text = _G.CONSTANTS.ICONS.downArrow .. " Import Linked Comps", Weight = 0.20 }
            },
            ui:Label{ FrameStyle = 4, Weight = 0 }
        },
        ui:VGroup{
            ID = "CreateCompositionPanel",
            ToolTip = "1. Link AV clips with " .. _G.CONSTANTS.PLACEHOLDER_TL_NAME .. " clip (placeholder at top).\n2. Bring playhead over placeholder.\n3. Replace with nested timeline (AE comp draft).\n" .. _G.CONSTANTS.ICONS.downRightArrow .. " Optionally use custom resolution, otherwise uses project settings.\n4. Import new comp in AE.",  
            Weight = 0,
            Spacing = 5,
            ui:Label{ Text = "Create Composition", Alignment = {AlignCenter = true}, Weight = 0, StyleSheet = TITLE_CSS },
            ui:HGroup{
                Weight = 0,
                ui:Label{ ID = "CompNameLabel", Text = "Comp Name:", Weight = 0.18 },
                ui:LineEdit{ ID = "CompName", PlaceholderText = "Enter new comp name...", Weight = 0.82 }
            },
            ui:HGroup{
                Weight = 0,
                ui:CheckBox{ ID = "UseCustomResolution", Text = "Use Custom Resolution", Checked = false, Weight = 1 },
                ui:Button{ ID = "InsertPlaceholderTimelineAtPlayhead", Text = _G.CONSTANTS.ICONS.downToBarArrow .. " Insert Placeholder" }
            },
            ui:HGroup{
                Weight = 0,
                ui:Button{ ID = "NestLinkedInAEComp", Text = _G.CONSTANTS.ICONS.upArrow .. " Replace Linked Layers With Nested AE Comp" }          
            },
            ui:Label{ FrameStyle = 4, Weight = 0 }
        },
        ui:VGroup{
            ID = "LinkedNestPanel",
            ToolTip = "Bring Playhead over nest clip from working timeline, or inside nested timeline.\nUse markers to communicate animation timings.\nRefresh Render keeps nest contents up to date.",  
            Weight = 0,
            Spacing = 5,
            ui:Label{ Text = "Linked Nest", Alignment = {AlignCenter = true}, Weight = 0, StyleSheet = TITLE_CSS },
            ui:HGroup{
                Weight = 0,
                ui:Button{ ID = "ImportMarkers", Text = _G.CONSTANTS.ICONS.downTriangle .. " Import Markers", Weight = 0.5 },
                ui:Button{ ID = "ExportMarkers", Text = _G.CONSTANTS.ICONS.upTriangle .. " Export Markers", Weight = 0.5 }
            },
            ui:HGroup{
                Weight = 0,
                ui:Button{ ID = "RefreshRender", Text = _G.CONSTANTS.ICONS.refresh .. " Refresh Render", Weight = 0.5 }
                -- ui:Button{ ID = "GenerateProxy", Text = "▶ Generate Proxy", Weight = 0.5 }
            },
            ui:Label{ FrameStyle = 4, Weight = 0 }
        }, 
        ui:VGroup{
            ID = "BrandingPanel",
            Weight = 0,
            Spacing = 5,
            ui:HGroup{
                Spacing = 5,
                ui:TextEdit{ ID = "Logo", HTML = "<a href='" .. _G.CONSTANTS.WEBSITEURL .. "'><img src='".._G.CONSTANTS.ICONS.logoB64 .."' width='20' height='20' style='vertical-align:middle;'>", ReadOnly = true, FrameStyle = 0, FixedSize = {30, 30}, Events = { AnchorClicked = true }, Weight = 0},
                ui:Label{ Text = "MotionBridge v" .. _G.CONSTANTS.MOTIONBRIDGE_VERSION .. " beta | " .. _G.CONSTANTS.ICONS.copyright .. " 2025-2026 Nathan Stassin ", Alignment = {AlignVCenter = true}, Weight = 0.8, StyleSheet = BRANDING_CSS},
                ui:Button{ ID = "Help", Text = _G.CONSTANTS.ICONS.help, Weight = 0, MinimumSize = {30, 30}, MaximumSize = {30, 30}, StyleSheet = BRANDING_CSS }
            }
        }
    }
})

_G.ui_items = MainWindow:GetItems()

-- GUI FUNCTIONS
function LinkClick(ev)
    bmd.openurl(ev.URL)
end

MainWindow.On.Logo.AnchorClicked = LinkClick

function set_ui_enabled(bool)
    ui_items.ImportNewComps.Enabled = bool
    ui_items.InsertPlaceholderTimelineAtPlayhead.Enabled = bool
    ui_items.NestLinkedInAEComp.Enabled = bool
    ui_items.UseCustomResolution.Enabled = bool
    ui_items.ImportMarkers.Enabled = bool
    ui_items.ExportMarkers.Enabled = bool
    ui_items.RefreshRender.Enabled = bool
    -- ui_items.GenerateProxy.Enabled = bool
    ui_items.CompName.Enabled = bool
end
-- Disable all function buttons initially
set_ui_enabled(false)

function MainWindow.On.Browse.Clicked(ev)
    local chosenPath = fu:RequestDir("Choose MotionBridge Folder...")
    if not chosenPath or chosenPath == "" then
        print("No folder selected.")
        return
    end

    -- Normalise and store the path
    _G.project_media_path = chosenPath:gsub("\\", "/"):gsub("/+$", "")
    ui_items.FolderPath.Text = _G.project_media_path

    local success = initialise(_G.project_media_path)
    if not success then
        set_ui_enabled(false)
        return
    end

    set_ui_enabled(true)
    update_project_fps()
    if refresh_project_globals() == false then return end
end

function MainWindow.On.ImportNewComps.Clicked(ev)
    if refresh_project_globals() == false then return end
    update_project_fps()
    import_new_comps()
end 

function MainWindow.On.InsertPlaceholderTimelineAtPlayhead.Clicked(ev)
    if refresh_project_globals() == false then return end
    update_project_fps()
    local success = insert_placeholder_timeline_at_playhead()
    if not success then
        alert("Failed to insert placeholder.\nMake sure you have an active timeline open.")
    end
end

function MainWindow.On.NestLinkedInAEComp.Clicked(ev)
    if refresh_project_globals() == false then return end
    update_project_fps()
    local comp_name = ui_items.CompName.Text
    if comp_name == "" then
        alert("Please enter a comp name before creating.")
        return
    end
    print("Running replace_linked_with_aecomp() with comp name: " .. comp_name)
    local use_custom_settings = ui_items.UseCustomResolution.Checked
    local custom_settings = nil

    if use_custom_settings then
        custom_settings = prompt_custom_settings()
        if not custom_settings then
            print("Cancelled custom settings input.")
            return
        end
    end

    replace_linked_with_aecomp(comp_name, use_custom_settings, custom_settings)
end

function MainWindow.On.ImportMarkers.Clicked(ev)
    if refresh_project_globals() == false then return end
    if not import_markers() then alert(get_context_help_message("markers")) end
end

function MainWindow.On.ExportMarkers.Clicked(ev)
    if refresh_project_globals() == false then return end
    update_project_fps()
    if not export_markers() then 
        alert(get_context_help_message("markers"))
    else 
        alert("Markers exported!")
    end 
end

function MainWindow.On.RefreshRender.Clicked(ev)
    if refresh_project_globals() == false then return end
    update_project_fps()
    local refreshed = refresh_render()
    -- Slightly janky solution to reset pointer - replace file with itself after refreshing it lmao - Solves extended duration render media offline bug 
    if refreshed then 
        replace_render_after_refresh() 
    else
        alert(get_context_help_message("refresh"))
    end
    
    confirm_and_delete_unused_renders()
    remove_orphaned_render_mpis()
end

--[[
function MainWindow.On.GenerateProxy.Clicked(ev)
    print("Generating proxy")
    generate_proxy()
end 
]]

function MainWindow.On.Help.Clicked(ev)
    show_help_window()
end

function MainWindow.On.MainWind.Close(ev)
    disp:ExitLoop()
end

-- Run
MainWindow:RecalcLayout()
MainWindow:Show()
disp:RunLoop()
MainWindow:Hide()