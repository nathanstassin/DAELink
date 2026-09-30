--[[
    DAELink | v0.9 Beta | © 2026 Nathan Stassin

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

    Description:  Links timeline nests with compositions in After Effects via a GUI window.
                  Automated render management and shared markers across programs.

    Author:       Nathan Stassin  |  https://www.nathanstassin.com

    Requirements: DaVinci Resolve Studio V20 or later
                  OR DaVinci Resolve Free 19.0.3

    Installation: Drag this file into the Fusion Utility Scripts folder on your computer.
                  Mac: ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
                  Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\

    Privacy:      All data stored locally. No data is transmitted to external servers.

    Version History:
    - 0.9 Beta - 30/09/2026 - Initial public beta release.
]]

-- GLOBALS
_G.resolve = app:GetResolve() or bmd.scriptapp("Resolve")
_G.project = nil
_G.project_id = nil
_G.media_pool = nil
_G.root_folder = nil
_G.project_media_path = nil 
_G.json_path = nil 
_G.daelink_folder = nil 
_G.comps_folder = nil 
_G.renders_folder = nil 
_G.compound_clips_folder = nil
_G.json_backup_done = {}   -- json path -> true, so the .bak is written once per session
_G.settings_dir_warned = false  -- so the settings-path warning prints once, not per connection

-- Capture the script's own directory at the top level, where debug.getinfo is reliable.
-- Inside functions, debug.getinfo returns the call site, not the script file.
do
    local src = debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", ""):gsub("\\", "/")
    local dir = src:match("^(.*)/[^/]+$")
    _G.SCRIPT_DIR = dir or ""
end

_G.CONSTANTS = {
    DAELINK_VERSION = 0.9,
    SCHEMA_VERSION = 1,
    PLACEHOLDER_TL_NAME = "0_DAELinkPlaceholder",
    FOLDER_NAMES = {
        DAELINK = "0_DAELink",
        COMPOUNDCLIPS = "0_Compound Clips",
        RENDERS = "1_Renders", 
        LINKEDCOMPS = "Linked Nests"
    },
    DIRECTORY_NAMES = { 
        ROOT = "daelink",
        RENDERS = "renders",
        SUPPORT = "support"
    },
    MARKER_COLORS = {'Blue', 'Cyan', 'Green', 'Yellow', 'Red', 'Pink', 'Purple', 'Fuchsia', 'Rose', 'Lavender', 'Sky', 'Mint', 'Lemon', 'Sand', 'Cocoa', 'Cream'},
    PAR_MAP = { ["1.25"] = 1.25, ["1.33"] = 1.3333333333333333, ["1.3x Anamorphic"] = 1.2999999523162842, ["1.5"] = 1.5, ["1.8"] = 1.7999999523162842, ["16mm HD Anamorphic"] = 0.7845, ["2.0"] = 2.0, ["35mm Full Aperture HD Anamorphic"] = 0.740, ["NTSC"] = 0.9090909090909091, ["NTSC 16:9"] = 1.2121212121212122, ["NTSC DV"] = 0.9090909090909091, ["NTSC DV 16:9"] = 1.2121212121212122, ["PAL"] = 1.0909090909090908, ["PAL 16:9"] = 1.4545454545454546, ["Square"] = 1.0, ["Super16 HD Anamorphic"] = 0.9090909090909091 },
    VIDEO_EXTENSIONS = {".mov", ".mp4", ".mxf", ".avi", ".mkv", ".m4v", ".wmv", ".flv", ".webm", ".mpg", ".mpeg", ".tif", ".tiff"},
    -- Used only by is_still_clip(), as a fallback when GetClipProperty("Type") is unreadable.
    -- Overlaps VIDEO_EXTENSIONS on purpose: .tif is a render container there and a still here,
    -- and the two lists answer different questions.
    STILL_EXTENSIONS = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".tga", ".bmp", ".gif", ".webp", ".heic", ".psd", ".exr", ".dpx"},
    -- Characters illegal in a file name on Windows or Mac. Comp names are used as render file
    -- names, so these must never reach a path. Keep in sync with ILLEGAL_NAME_PATTERN in daelink.jsx.
    ILLEGAL_NAME_PATTERN = '[/\\:%*%?"<>|]',
    -- Names Windows reserves for devices, illegal as a file name with or without an extension.
    -- Keep in sync with RESERVED_DEVICE_NAMES in daelink.jsx.
    RESERVED_DEVICE_NAMES = {
        CON = true, PRN = true, AUX = true, NUL = true,
        COM1 = true, COM2 = true, COM3 = true, COM4 = true, COM5 = true,
        COM6 = true, COM7 = true, COM8 = true, COM9 = true,
        LPT1 = true, LPT2 = true, LPT3 = true, LPT4 = true, LPT5 = true,
        LPT6 = true, LPT7 = true, LPT8 = true, LPT9 = true
    },
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
    JSON_FILENAME = "daelink.json",
    SETTINGS_FILENAME = "daelink_projects.json",
    COMMENT_ID_PREFIX = "ID(DONOTDELETE):",
    PRELINK_PATTERN = "^prelink%d+$",
    LINKED_CLIPS_SUFFIX = " linked clips",
    CUSTOM_SETTINGS = {
        DEFAULT_WIDTH = 1920,
        DEFAULT_HEIGHT = 1080
    },
    RESOLUTION_PRESETS = {
        { label = "Match Project",  width = nil,  height = nil  },
        { label = "1920 × 1080",    width = 1920, height = 1080 },
        { label = "3840 × 2160",    width = 3840, height = 2160 },
        { label = "1280 × 720",     width = 1280, height = 720  },
        { label = "1080 × 1920",    width = 1080, height = 1920 },
        { label = "1080 × 1080",    width = 1080, height = 1080 },
        { label = "2048 × 1080",    width = 2048, height = 1080 },
        { label = "4096 × 2160",    width = 4096, height = 2160 },
        { label = "Custom...",      width = nil,  height = nil  },
    },
    SEARCH_SAFETY_LIMIT = 100,  
    ICONS = {
        logoB64        = [[data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAAsTAAALEwEAmpwYAAAD6ElEQVR4nN2auYsUURDG34w3GIj+CyqoaCiiqIhXopEH4gGiK6gg4gXKgqKCB6KYaGIkRqaGezPTGyz7V4giInjgfeHPoLtxtu2r6r2+9oMKduZVdX/fq1dV3bPGFIiBgQEDpNl94EHamrGxsSJvsTgMDg5mkT/HP/Snre10OlXTkWFoaEhCPpcI3W63alr5kIP8+Rjy00MEYdqrRKjtcVCm/fTIBIu03w5sarQIFuSP9Kw5oBGh8uMwPDycRf5CArGjMWsPakTwPK8a8hYFry/F51AjMsGi4KWRtxKhtJpgceaP5SBfbxEKSvtmHAeLtI8reM3KBEetTmuqFulMhIrJW4lgfRwc93lbK3dOKLng5bVyCmPBfb4SEXLXhJL6fD1FqGnal3McSuzzy4GVwCJgJjADWBh8tqIMEf7LhJJa3RLgUSDYUmAu0Aq+mwMsBg4Ha5YL4trNCSMjI2WQD3fqZI61fcFaSWapRPA8z2QFdtHnjysE2xf4nBb4qOaEtIAuCt7GwKcj8AltIPDdJvAR14Qiyc8CPgd+mxQCrAl8fwLzihIhLoCrPn858PuFX+WlAswHvgUxbgl9c4tQxM6H9jbw/YCfDVJ/A7wOYnzCb5nORchDXvNgs67H30UGAGxRxMgUISvttY+0ZyJxNitirIvEuKi8l9QWafB/oo7iOzrFQ7sRifdMEeNpJMY9i/tZD3yN4fmwbYyZnfBo8DPf41MsWpG/dxpjNgj8Vxtj9lpcP4ofCZ/PDhXqj00S2K9U/GxMrK/Aqhy+y4CPMf6XlPeyJ4HbNZhaBJNEOKi46PqEWH+AU8R3hTZwAr/vx0EyEIW2N418VIA0EQ4JL9wC3ifEAngBPAGuBPYYeJ6y/gvyVppJnhgBXIpwPYWQFHeF185FngQBXIkwl/jKK8Vv/JnAOXlSBHAlwlYV5anYIbieiDwZArgSoS8hRh7keX+QRf5qmp8ZHx/XinBAcHM7gTcC4u+AXYL4uzXkJycn/Wmg2+1qRZDMCQuAm8DLFOKvgDv47wvzxk3t80k2MTFhWq2eec1CBOmcMAt/zD4D3A7sLH6fnyOMJT7zIfl2u/3/XNjpdLQiSFukC1OTn7LzUVhkQpkiuN35holQLPmaH4di0r4hmaDq8+KddyiCZE7IMlWfV++8QxG07xN6Td3nrXbeoQia9wnWZ94p+RAlF8ZyC15elFQY67XzJYtQb/IhCjoO9Uz7JDjOhGr6fIUi9M4J1fb5CkXYCKxN+K5eZz4LFiI0n3wIi8IoIl+LtE+CZSY0c+ejUIowPciHEB6HZqd9EkZHR7NEeIj/j5GJazzPK3Tn/wKe3UL0/v4G+AAAAABJRU5ErkJggg==]],
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
    WEBSITEURL = "https://nathanstassin.com/daelink"
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

-- SETTINGS PERSISTENCE (per-project path memory)
-- Stored in daelink_projects.json alongside the script file.
-- Dict format: { [davinci_project_uuid] = "/path/to/media/folder", ... }
-- Called on every connection attempt, so neither branch may print unconditionally.
-- The success path is silent (the location is fixed and documented); the warning
-- prints once per session so a real problem is still visible without repeating.
function get_settings_path()
    if _G.SCRIPT_DIR and _G.SCRIPT_DIR ~= "" then
        return _G.SCRIPT_DIR .. "/" .. _G.CONSTANTS.SETTINGS_FILENAME
    end
    if not _G.settings_dir_warned then
        _G.settings_dir_warned = true
        print("DAELink: WARNING - could not determine script directory for settings file.")
    end
    return _G.CONSTANTS.SETTINGS_FILENAME
end

-- Minimal encode/decode for a flat string→string dict.
-- Avoids dependency on the local json variable defined later in the file.
function settings_encode(dict)
    local parts = {}
    for k, v in pairs(dict) do
        local ek = tostring(k):gsub('\\', '\\\\'):gsub('"', '\\"')
        local ev = tostring(v):gsub('\\', '\\\\'):gsub('"', '\\"')
        table.insert(parts, '"' .. ek .. '":"' .. ev .. '"')
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function settings_decode(str)
    local dict = {}
    if not str or str:match("^%s*$") then return dict end
    for k, v in str:gmatch('"(.-[^\\])"%s*:%s*"(.-[^\\])"') do
        -- Unescape basic sequences
        k = k:gsub('\\"', '"'):gsub('\\\\', '\\')
        v = v:gsub('\\"', '"'):gsub('\\\\', '\\')
        dict[k] = v
    end
    return dict
end

function load_project_settings()
    local path = get_settings_path()
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    return settings_decode(content)
end

function save_project_settings(settings)
    local path = get_settings_path()
    local f = io.open(path, "w")
    if not f then print("DAELink: Failed to write settings file: " .. path); return end
    f:write(settings_encode(settings))
    f:close()
end

function save_project_path(project_id, media_path)
    local settings = load_project_settings()
    settings[project_id] = media_path
    save_project_settings(settings)
end

function load_project_path(project_id)
    local settings = load_project_settings()
    return settings[project_id]
end

function try_auto_initialise()
    -- Attempt to restore previous session path for this project without user interaction.
    -- Returns the media path string on success, nil on failure.
    refresh_project_globals()
    if not _G.project_id then return nil end

    local saved_path = load_project_path(_G.project_id)
    if not saved_path or saved_path == "" then return nil end

    -- Validate the saved path still has a daelink folder
    local paths = build_project_paths(saved_path)
    if not file_exists(paths.json) then
        print("DAELink: saved path no longer valid - " .. saved_path)
        return nil
    end

    local success = initialise(saved_path, true)
    return success and saved_path or nil
end

function connect_to_folder(chosen_path, silent)
    -- Normalise a picked or recalled path and run full initialisation.
    -- Mirrors JSX's connectToFolder(folder). Used by connect_to_project() for
    -- both silent reconnect (silent=true) and user-picker paths. initialise()
    -- sets _G.project_media_path on success only, so failure leaves state clean.
    if not chosen_path or chosen_path == "" then return false end

    local normalised = chosen_path:gsub("\\", "/"):gsub("/+$", "")
    local success = initialise(normalised, silent)
    if success then
        update_project_fps()
        ui_items.BrandingName.ToolTip = "Project folder: " .. _G.project_media_path
    end
    return success
end

function connect_to_project()
    -- Called at the top of every button handler.
    -- Returns true if we have a valid connection, false otherwise.
    -- Handles project switches by attempting silent reconnect from saved settings.

    local current_project = _G.resolve:GetProjectManager():GetCurrentProject()
    if not current_project then
        alert("No project open in DaVinci Resolve.")
        return false
    end
    local current_project_id = current_project:GetUniqueId()

    -- Already connected to the right project
    if _G.json_path and file_exists(_G.json_path) and current_project_id == _G.project_id then
        _G.project = current_project
        _G.media_pool = _G.project:GetMediaPool()
        _G.root_folder = _G.media_pool:GetRootFolder()
        return true
    end

    -- Project has changed (or first run) - update globals and clear stale state
    _G.project = current_project
    _G.project_id = current_project_id
    _G.media_pool = _G.project:GetMediaPool()
    _G.root_folder = _G.media_pool:GetRootFolder()
    _G.json_path = nil
    _G.project_media_path = nil

    local saved_path = load_project_path(_G.project_id)

    if saved_path and saved_path ~= "" then
        local paths = build_project_paths(saved_path)
        if file_exists(paths.json) then
            -- Case 1: Path saved and valid - reconnect silently
            if connect_to_folder(saved_path, true) then return true end
            -- Init failed despite valid path (e.g. version mismatch) - fall through to picker
        else
            -- Case 2: Path saved but folder has moved - notify, then fall through to picker
            alert("DAELink project folder not found at:\n" .. saved_path .. "\n\nPlease navigate to its new location.")
        end
    end

    -- Case 2 (folder moved) or Case 3 (no saved path) - open picker
    local chosen_path = fu:RequestDir("Select this project's daelink media folder...")
    return connect_to_folder(chosen_path)
end

function initialise(project_media_path, silent)
    -- Globals (_G.project_media_path, _G.json_path) are only set on the success
    -- path at the end of this function. All failure paths leave them untouched
    -- so connect_to_project()'s "already connected" check can't be fooled by
    -- half-initialised state.
    if not project_media_path or project_media_path == "" then
        notify(silent, "No media path provided.")
        return false
    end

    -- Normalise path: convert backslashes to forward slashes and remove trailing slashes
    project_media_path = project_media_path:gsub("\\", "/"):gsub("/+$", "")

    local normalised_path = project_media_path
    local lower_path = normalised_path:lower()

    if lower_path:match("/daelink/?$") then
        -- User selected project root folder, strip it off to get parent
        project_media_path = normalised_path:match("^(.*)/[^/]+/?$") or normalised_path
    end

    local paths = build_project_paths(project_media_path)
    if not paths then return false end

    refresh_project_globals()

    local initial_timeline = _G.project:GetCurrentTimeline()
    local placeholder_state = validate_placeholder(silent)

    if not placeholder_state then
        return false
    end

    local is_first_init = placeholder_state == "missing"
    local local_json_path = paths.json

    if is_first_init then
        -- First-time setup requires user interaction; abort silently during auto-reconnect
        if silent then return false end

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

        _G.json_path = local_json_path

        get_daelink_folders()

        if not create_placeholder_timeline() then
            _G.json_path = nil
            return false
        end

        if not initialise_json() then
            _G.json_path = nil
            return false
        end

        alert("DAELink project initialised.\n\nConnect to the same folder from After Effects using the DAELink panel.")
    else
        if not directory_exists(paths.root) then
            notify(silent, "No daelink folder found!")
            return false
        end

        -- Validate the remaining directories exist (paths.root is checked above)
        local checks = {
            {paths.support, "Project/Support folder missing."},
            {paths.renders, "Project/Renders folder missing."}
        }

        for _, check in ipairs(checks) do
            if not directory_exists(check[1]) then
                notify(silent, check[2])
                return false
            end
        end

        if not file_exists(local_json_path) then
            notify(silent, "daelink.json not found. Cannot rebind.")
            return false
        end

        -- Temporarily set json_path so version_check/load_and_validate_json can read it.
        -- Cleared on any failure below to avoid partial-state leak.
        _G.json_path = local_json_path

        if not version_check(silent) then
            _G.json_path = nil
            return false
        end
        if not load_and_validate_json(silent) then
            _G.json_path = nil
            return false
        end

        get_daelink_folders()
    end

    if initial_timeline then
        _G.project:SetCurrentTimeline(initial_timeline)
    end

    -- Commit globals only after all validation has passed
    _G.project_media_path = project_media_path
    _G.json_path = local_json_path
    save_project_path(_G.project_id, project_media_path)
    return true
end

function validate_placeholder(silent)
    -- Returns: "missing", "valid", or false (error)
    local placeholder_timeline = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)

    if not placeholder_timeline then
        return "missing"
    end

    local props = placeholder_timeline:GetClipProperty()
    local comment = props["Comments"] or ""

    if comment == "" then
        notify(silent, "Error: Comment with ID deleted from DAELink Placeholder.\n\nDelete timeline and re-initialise project")
        return false
    end

    local pattern = _G.CONSTANTS.COMMENT_ID_PREFIX:gsub("([%(%)%-])", "%%%1") .. "%s*([%w%-]+)"
    local embedded_id = comment:match(pattern)
    if not embedded_id then
        notify(silent, "Invalid DAELink placeholder comment format")
        return false
    end

    if embedded_id ~= _G.project:GetUniqueId() then
        notify(silent, "DAELink placeholder belongs to a different project. Aborting.")
        return false
    end

    return "valid"
end

function create_placeholder_timeline()
    _G.media_pool:SetCurrentFolder(_G.daelink_folder)

    local tl = _G.media_pool:CreateEmptyTimeline(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not tl then
        alert("Failed to create DAELink placeholder timeline.")
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
        daelinkVersion = _G.CONSTANTS.DAELINK_VERSION,
        schemaVersion = _G.CONSTANTS.SCHEMA_VERSION,
        projectFPS = _G.project:GetSetting("timelineFrameRate"),
        compositions = {}
    })
end

function load_and_validate_json(silent)
    local data = load_json_data(_G.json_path)
    if not data then
        notify(silent, "Failed to read daelink.json.")
        return false
    end

    if data.projectid ~= _G.project_id then
        notify(silent, "daelink folder belongs to a different project.")
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
    -- Windows' mkdir errors (exit code 1) on an already-existing directory, unlike Unix's
    -- idempotent mkdir -p. paths.root is the first directory the init loop creates, so
    -- without this check any pre-existing daelink/ folder fails initialisation outright.
    -- Checking first makes both platforms behave like mkdir -p.
    if directory_exists(path) then
        return true
    end

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

-- Strips a KNOWN video extension only. Deliberately not "everything after the last dot":
-- comp names legitimately contain dots ("Title v1.2") and renderPath is stored without an
-- extension, so a greedy strip would truncate the basename and break render lookup.
function strip_video_extension(filename)
    local lower = filename:lower()
    for _, ext in ipairs(_G.CONSTANTS.VIDEO_EXTENSIONS) do
        if lower:sub(-#ext) == ext then
            return filename:sub(1, #filename - #ext)
        end
    end
    return filename
end

-- NAME SANITISING
-- Comp names become render file names (see renderPath), so any character that is illegal in a
-- file name on either platform breaks the render round trip. "/" is the worst offender: AE reads
-- it as a directory separator and writes into a folder that does not exist.
function illegal_name_chars(name)
    local found = {}
    local seen = {}
    for ch in tostring(name or ""):gmatch(_G.CONSTANTS.ILLEGAL_NAME_PATTERN) do
        if not seen[ch] then
            seen[ch] = true
            table.insert(found, ch)
        end
    end
    if tostring(name or ""):match("[%.%s]$") then
        table.insert(found, "trailing dot or space")
    end
    if is_reserved_device_name(name) then
        table.insert(found, "reserved Windows device name")
    end
    return found
end

-- Windows refuses these as file names whatever the extension, so a nest named "CON" would
-- render to CON.mp4 and fail. Keep in sync with RESERVED_DEVICE_NAMES in daelink.jsx.
function is_reserved_device_name(name)
    local upper = tostring(name or ""):upper()
    return _G.CONSTANTS.RESERVED_DEVICE_NAMES[upper] == true
end

-- Returns: sanitised_name, was_changed
function sanitize_name(name)
    local original = tostring(name or "")
    local cleaned = original:gsub(_G.CONSTANTS.ILLEGAL_NAME_PATTERN, "-")
    cleaned = cleaned:gsub("%c", "")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    -- Trailing dots and spaces are illegal on Windows even though the chars themselves are fine
    cleaned = cleaned:gsub("[%.%s]+$", "")
    -- Suffix rather than replace, so two nests can't collapse onto the same file name
    if is_reserved_device_name(cleaned) then cleaned = cleaned .. "-1" end
    return cleaned, (cleaned ~= original)
end

-- GLOBAL REFRESHES
function version_check(silent)
    local data = load_json_data(_G.json_path)
    if not data then return false end

    -- schemaVersion gates cross-script JSON compatibility. Early-beta
    -- projects have no schemaVersion field; treat them as schema 1.
    local saved_schema = data.schemaVersion or 1
    local script_schema = _G.CONSTANTS.SCHEMA_VERSION

    if saved_schema ~= script_schema then
        notify(silent, "DAELink schema mismatch detected.\n\nProject schema: v" .. saved_schema .. "\nScript schema: v" .. script_schema .. "\n\nThe project was created by an incompatible version of DAELink. Please align script versions in both AE and Resolve.")
        return false
    end
    return true
end

function refresh_project_globals()
    local current_project = _G.resolve:GetProjectManager():GetCurrentProject()
    if not current_project then
        alert("No project open in DaVinci Resolve.")
        return false
    end
    _G.project = current_project
    _G.project_id = current_project:GetUniqueId()
    _G.media_pool = _G.project:GetMediaPool()
    _G.root_folder = _G.media_pool:GetRootFolder()
    return true
end

function update_project_fps()
    -- Potential edge case: user changes project frame rate in DaVinci without updating JSON,
    -- sends aecomp, then loads with mismatching fps. Not currently an issue - DaVinci doesn't
    -- allow project FPS changes once media is imported.
    local data = load_json_data(_G.json_path)
    if not data then return end
    data["projectFPS"] = _G.project:GetSetting("timelineFrameRate")
    save_json_data(data)
end

function get_daelink_folders()
    _G.daelink_folder = get_or_create_folder(_G.root_folder, _G.CONSTANTS.FOLDER_NAMES.DAELINK)
    -- MediaPoolFolder has no SetName() - detect legacy folder and keep using it; new projects get "Linked Nests"
    _G.comps_folder = nil
    for _, bin in ipairs(_G.daelink_folder:GetSubFolderList()) do
        if bin:GetName() == "Linked Compositions" then _G.comps_folder = bin; break end
    end
    if not _G.comps_folder then
        _G.comps_folder = get_or_create_folder(_G.daelink_folder, _G.CONSTANTS.FOLDER_NAMES.LINKEDCOMPS)
    end
    _G.renders_folder = get_or_create_folder(_G.comps_folder, _G.CONSTANTS.FOLDER_NAMES.RENDERS)
    _G.compound_clips_folder = get_or_create_folder(_G.comps_folder, _G.CONSTANTS.FOLDER_NAMES.COMPOUNDCLIPS)
end 

-- Encode a Unicode code point as UTF-8. Fusion's Lua has no utf8 library, and this is
-- needed to turn a decoded \uXXXX escape back into real text.
function utf8_from_codepoint(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40),
                           0x80 + (cp % 0x40))
    elseif cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 0x1000),
                           0x80 + (math.floor(cp / 0x40) % 0x40),
                           0x80 + (cp % 0x40))
    else
        return string.char(0xF0 + math.floor(cp / 0x40000),
                           0x80 + (math.floor(cp / 0x1000) % 0x40),
                           0x80 + (math.floor(cp / 0x40) % 0x40),
                           0x80 + (cp % 0x40))
    end
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
    -- Must be a function, not the table alone: gsub leaves a match UNCHANGED when the table
    -- lookup returns nil, so any control character without an entry above (\1-\31 other than
    -- b f n r t) used to be written into the file raw. Raw control characters are illegal
    -- inside a JSON string, and AE's JSON.parse rejects the whole file rather than just that
    -- value, which takes the entire link down. Anything unmapped now falls back to \uXXXX.
    s = s:gsub('[%z\1-\31\\"]', function(c)
      return replacements[c] or string.format("\\u%04x", c:byte())
    end)
    -- U+2028 / U+2029 are legal raw inside a JSON string but illegal inside a JavaScript
    -- string literal, so they break the AE side's eval-based JSON.parse fallback. Escaping
    -- them here mirrors what safeJSONStringify does in daelink.jsx. These are their UTF-8
    -- byte sequences, since this runs on bytes rather than code points.
    s = s:gsub("\226\128\168", "\\u2028"):gsub("\226\128\169", "\\u2029")
    return s
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
            if n == "u" then
                -- \uXXXX. Without this the escape fell through to `map[n] or n` and a
                --   arrived as the literal text "u2028". The AE side emits \uXXXX
                -- for control characters and for U+2028/U+2029 specifically, so this is
                -- exactly the payload that used to corrupt on the way in.
                local cp = tonumber(str:sub(i + 2, i + 5), 16)
                if cp then
                    i = i + 6
                    -- A non-BMP character arrives as a surrogate pair; combine the two
                    -- halves back into one code point before encoding.
                    if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i, i + 1) == "\\u" then
                        local low = tonumber(str:sub(i + 2, i + 5), 16)
                        if low and low >= 0xDC00 and low <= 0xDFFF then
                            cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
                            i = i + 6
                        end
                    end
                    s[#s+1] = utf8_from_codepoint(cp)
                else
                    -- Malformed escape, keep the character rather than losing it
                    s[#s+1] = n
                    i = i + 2
                end
            else
                local map = { b="\b", f="\f", n="\n", r="\r", t="\t", ['"']='"', ["\\"]="\\", ["/"]="/" }
                s[#s+1] = map[n] or n
                i = i + 2
            end
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
        print("DAELink: Error opening JSON file: " .. tostring(err))
        return nil
    end
    local content = file:read("*a")
    file:close()

    -- An empty file is what the disabled-script-permissions incident left behind.
    -- Both of these paths MUST return nil rather than an empty default: handing back
    -- { compositions = {} } looks like a valid project with no links, so the next save
    -- writes that empty table over the real file and every existing link is lost.
    -- Callers are expected to abort on nil.
    if not content or content:match("^%s*$") then
        print("DAELink: daelink.json is empty." .. backup_note(path))
        alert("daelink.json is empty and cannot be read.\n\nDAELink has stopped rather than overwrite it, so nothing has been changed." ..
              backup_note(path) .. "\n\nRestore that backup over daelink.json to recover the project's links.")
        return nil
    end

    local ok, result = pcall(function() return json.decode(content) end)
    if not ok then
        print("DAELink: error parsing JSON: " .. tostring(result) .. backup_note(path))
        alert("daelink.json could not be read: " .. tostring(result) ..
              "\n\nDAELink has stopped rather than overwrite it, so nothing has been changed." ..
              backup_note(path) .. "\n\nRestore that backup over daelink.json to recover the project's links.")
        return nil
    end

    rotate_json_backup(path, content)
    return result
end

function backup_note(path)
    if path and file_exists(path .. ".bak") then
        return " A backup from earlier this session is available at: " .. path .. ".bak"
    end
    return ""
end

-- First successful load of a given JSON file in a session leaves a known-parseable copy beside
-- it as daelink.json.bak. Written from the text that just decoded, so the backup can never hold
-- the corrupt state it exists to protect against. The AE side does the same on its first load.
function rotate_json_backup(path, content)
    if not path or _G.json_backup_done[path] then return end
    -- Flag first: a failing backup must never be retried on every load
    _G.json_backup_done[path] = true

    local backup, err = io.open(path .. ".bak", "w")
    if not backup then
        print("DAELink: could not write JSON backup: " .. tostring(err))
        return
    end
    backup:write(content)
    backup:close()
    print("DAELink: JSON backup written to " .. path .. ".bak")
end

function save_json_data(data)
    -- Encode FIRST so an encoder error never reaches the file.
    local ok, encoded = pcall(function() return json.encode(data) end)
    if not ok then
        print("DAELink: Error encoding JSON (file left untouched): " .. tostring(encoded))
        return false
    end
    if type(encoded) ~= "string" or #encoded == 0 then
        print("DAELink: Encoded JSON was empty (file left untouched).")
        return false
    end

    -- Write to a sibling .tmp, verify by re-parse, then atomically swap.
    -- Survives mid-write failures (permissions revoked, disk full, etc).
    local tmp_path = _G.json_path .. ".tmp"
    local file, err = io.open(tmp_path, "w")
    if not file then
        print("DAELink: Error opening JSON temp file (original preserved): " .. tostring(err))
        return false
    end
    local write_ok, write_err = file:write(encoded)
    file:close()
    if not write_ok then
        os.remove(tmp_path)
        print("DAELink: Error writing JSON temp file (original preserved): " .. tostring(write_err))
        return false
    end

    -- Verify the temp file round-trips before swapping.
    local verify_file, verify_err = io.open(tmp_path, "r")
    if not verify_file then
        os.remove(tmp_path)
        print("DAELink: Failed to verify JSON temp file (original preserved): " .. tostring(verify_err))
        return false
    end
    local roundtrip = verify_file:read("*a")
    verify_file:close()
    local parse_ok = pcall(function() return json.decode(roundtrip) end)
    if not parse_ok then
        os.remove(tmp_path)
        print("DAELink: JSON temp file is corrupt (original preserved).")
        return false
    end

    -- os.rename overwrites the target on Mac/Linux; on Windows it fails if the
    -- target exists, so remove the original first there. Both paths preserve
    -- the original until the temp file is known-good above.
    if package.config:sub(1,1) == "\\" then
        os.remove(_G.json_path)
    end
    local rename_ok, rename_err = os.rename(tmp_path, _G.json_path)
    if not rename_ok then
        print("DAELink: Could not swap JSON temp file into place: " .. tostring(rename_err) ..
              "\nLatest data is in: " .. tmp_path)
        return false
    end
    return true
end

function write_compdata_tojson(nested_timeline_id, placeholder, linked_to_placeholder, comp_name, resolutionHeight, resolutionWidth, fps, duration)
    -- No "or {}" fallback here. Substituting an empty structure for an unreadable file
    -- would write this one comp over every existing link. load_json_data has already
    -- told the user why; abort so the file on disk is left exactly as it was.
    local data = load_json_data(_G.json_path)
    if not data then return false end
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

        -- A layer with no path can never import, and AE reports it as "File not found:"
        -- with nothing after the colon, which reads like the file moved rather than like
        -- DaVinci never supplied one. Say so here, where the clip that caused it is known.
        if file_path == "" then
            print(string.format("DAELink: No file path for clip '%s' (media pool item %s). It will be written to the JSON as a layer AE cannot import.",
                tostring(clip:GetName()),
                media_item and "found, but reports no File Path" or "missing"))
        end

        local track_info = clip:GetTrackTypeAndIndex()
        -- Reuse media_item from above rather than calling GetMediaPoolItem() again. The
        -- empty-path branch prints a diagnostic and deliberately carries on, so the nil case
        -- reaches here, and a second unchecked call turned that into a crash on the next
        -- line. find_unimportable_clips() normally refuses these before we get here, but this
        -- function is also reachable from other entry points.
        local parLabel = media_item and media_item:GetClipProperty("PAR") or nil
        local pixelAspectRatio = "N/A"
        local flipX = "N/A"
        local flipY = "N/A"
        if track_info[1] == "video" then 
            -- PAR needs the media pool item; the flips below come from the timeline clip and
            -- do not, so an unreadable media item must not cost us those too.
            if parLabel then
                if parLabel ~= "Square" then 
                    if confirm("Legacy pixel aspect ratio detected for clip: " .. clip:GetName() .. ". Change to square (recommended)?") then 
                        media_item:SetClipProperty("PAR", "Square")
                        parLabel = "Square"
                    else 
                        alert("Non-square pixel aspect ratios may not translate reliably to After Effects.\n" .. "Unless this clip is intentionally anamorphic or SD archival media, square pixels are recommended.")
                    end
                end

                pixelAspectRatio = _G.CONSTANTS.PAR_MAP[parLabel]

                if not pixelAspectRatio then
                    pixelAspectRatio = tonumber(parLabel)
                end
            end

            flipX = tostring(clip:GetProperty("FlipX"))
            flipY = tostring(clip:GetProperty("FlipY"))
        end 
    

        -- Known limitation: anchorpoints behave differently, so ommiting from layerData intentionally: AE (position + rotation) | Resolve (only rotation)
        table.insert(comp_entry["layers"], {
            layerName = clip:GetName(),
            filePath = file_path,
            mediaType = track_info[1],
            trackIndex = track_info[2],
            sourceStartFrame = clip:GetSourceStartFrame(),
            recordFrame = clip:GetStart(true) - record_frame_offset,
            duration = clip:GetDuration(true),
            zoomX = clip:GetProperty("ZoomX") or "N/A",
            zoomY = clip:GetProperty("ZoomY") or "N/A",
            pan = clip:GetProperty("Pan") or "N/A",
            tilt = clip:GetProperty("Tilt") or "N/A",
            rotationAngle = clip:GetProperty("RotationAngle") or "N/A",
            flipX = flipX, 
            flipY = flipY, 
            opacity = clip:GetProperty("Opacity") or "N/A",
            pixelAspect = pixelAspectRatio
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
    if not ok then
        print("DAELink: Failed to write JSON data.")
    end
end

-- POPUP UTILITIES
function show_dialog(config)
    -- config: {title, message, buttons = {"OK"} or {"Yes", "No"}}
    if not _G.disp then
        print("DAELink: [" .. (config.title or "DIALOG") .. "]", config.message)
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

    -- The ID is unique per dialog so nested dialogs cannot collide. It must be captured in a
    -- local, because the Close handler below has to be registered against this exact ID:
    -- a handler registered against a different name is simply never called, which left
    -- disp:RunLoop() spinning with no way out when the user dismissed an alert with the
    -- window close button instead of the OK button.
    local dialog_id = "Dialog_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
    local win = _G.disp:AddWindow({
        ID = dialog_id,
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

    win.On[dialog_id .. ".Close"] = function()
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

function notify(silent, message)
    -- Dispatches to alert() for user-initiated actions, print() during silent auto-init
    -- so startup reconnect failures don't fire modal dialogs.
    if silent then
        print("DAELink: " .. message)
    else
        alert(message)
    end
end

function confirm(message)
    return show_dialog({
        title = "Confirm",
        message = message,
        buttons = {"No", "Yes"}
    })
end

function prompt_new_comp_dialog()
    -- Returns: { name, use_custom, customResolutionWidth, customResolutionHeight }
    -- or nil if cancelled
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)
    local result = nil
    local win_id = "NewCompDialog"

    -- Build preset label list for the combo box
    local preset_labels = {}
    for _, p in ipairs(_G.CONSTANTS.RESOLUTION_PRESETS) do
        table.insert(preset_labels, p.label)
    end

    local win = disp:AddWindow({
        ID = win_id,
        WindowTitle = "New Composition",
        Geometry = {950, 400, 280, 180},
        ui:VGroup{
            Spacing = 8,
            ui:HGroup{
                ui:Label{ Text = "Comp Name:", Weight = 0.35 },
                ui:LineEdit{ ID = "name", PlaceholderText = "Enter comp name...", Weight = 0.65 }
            },
            ui:HGroup{
                ui:Label{ Text = "Resolution:", Weight = 0.35 },
                ui:ComboBox{ ID = "preset", Weight = 0.65 }
            },
            ui:HGroup{
                ID = "CustomGroup",
                Visible = false,
                ui:Label{ Text = "W × H:", Weight = 0.35 },
                ui:LineEdit{ ID = "width",  Text = tostring(_G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_WIDTH),  Weight = 0.3 },
                ui:Label{ Text = "×", Weight = 0, Alignment = {AlignHCenter = true} },
                ui:LineEdit{ ID = "height", Text = tostring(_G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_HEIGHT), Weight = 0.3 }
            },
            ui:HGroup{
                Spacing = 8,
                ui:Button{ ID = "ok",     Text = "OK"     },
                ui:Button{ ID = "cancel", Text = "Cancel" }
            }
        }
    })

    local items = win:GetItems()

    -- Populate combo box
    for _, label in ipairs(preset_labels) do
        items.preset:AddItem(label)
    end
    items.preset.CurrentIndex = 0  -- "Match Project" default

    function win.On.preset.CurrentIndexChanged(ev)
        local idx = items.preset.CurrentIndex + 1  -- 1-based
        local is_custom = (_G.CONSTANTS.RESOLUTION_PRESETS[idx].label == "Custom...")
        items.CustomGroup.Visible = is_custom
        win:RecalcLayout()
    end

    function win.On.ok.Clicked(ev)
        local name = items.name.Text or ""
        if name:match("^%s*$") then
            alert("Please enter a valid comp name.")
            return
        end

        -- The comp name becomes the render file name, so strip anything a file system rejects
        local cleaned, changed = sanitize_name(name)
        if cleaned == "" then
            alert("Please enter a comp name containing at least one usable character.")
            return
        end
        if changed then
            if not confirm("'" .. name .. "' contains characters that can't be used in a file name.\n\n" ..
                           "Create the composition as '" .. cleaned .. "' instead?") then
                return
            end
            items.name.Text = cleaned
            name = cleaned
        end

        local idx = items.preset.CurrentIndex + 1
        local preset = _G.CONSTANTS.RESOLUTION_PRESETS[idx]
        local use_custom = false
        local custom_w, custom_h = nil, nil

        if preset.label == "Custom..." then
            use_custom = true
            custom_w = tonumber(items.width.Text)  or _G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_WIDTH
            custom_h = tonumber(items.height.Text) or _G.CONSTANTS.CUSTOM_SETTINGS.DEFAULT_HEIGHT
        elseif preset.width ~= nil then
            -- Named preset with explicit dimensions
            use_custom = true
            custom_w = preset.width
            custom_h = preset.height
        end
        -- "Match Project" → use_custom stays false, custom_w/h stay nil

        result = {
            name = name,
            use_custom = use_custom,
            customResolutionWidth  = custom_w,
            customResolutionHeight = custom_h
        }
        disp:ExitLoop()
    end

    function win.On.cancel.Clicked(ev)
        disp:ExitLoop()
    end

    win.On[win_id .. ".Close"] = function(ev)
        disp:ExitLoop()
    end

    win:Show()
    disp:RunLoop()
    win:Hide()
    return result
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
    
    -- Captured in a local for the same reason as show_dialog: the Close handler has to be
    -- registered against this exact ID or it never fires.
    local win_id = "PaginatedSelection_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
    local win = disp:AddWindow({
        ID = win_id,
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
    
    win.On[win_id .. ".Close"] = function(ev)
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
        print("DAELink: Error: get_timeline_byID() called with nil ID.")
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

-- Parses "HH:MM:SS:FF" or the drop-frame "HH:MM:SS;FF" into four numbers.
-- Returns nil plus the raw value when the string does not match, so callers can
-- report what Resolve actually handed back instead of dying on nil arithmetic.
-- GetCurrentTimecode() has produced unparseable values in the field more than once
-- (drop-frame semicolons were the first case) and the raw string is the only clue
-- a bug report can carry, so every failure prints it.
function parse_timecode(timecode)
    if type(timecode) ~= "string" then
        return nil, tostring(timecode)
    end

    local h, m, s, f = timecode:match("(%d+):(%d+):(%d+)[;:](%d+)")
    if h then
        return tonumber(h), tonumber(m), tonumber(s), tonumber(f)
    end

    -- Resolve 21 added "Edit page timecode options for frames, subframes or audio samples",
    -- so with the display set to frames the playhead comes back as a bare number and not as
    -- HH:MM:SS:FF at all. That is the leading explanation for the field crash in the first
    -- Insert Placeholder bug report, which arrived as a screenshot with no timecode in it.
    -- A bare count is already the value callers want, so report it as 0:0:0:<frames> and let
    -- the nominal-rate arithmetic carry it through unchanged.
    local bare = timecode:match("^%s*(%d+)%s*$")
    if bare then
        return 0, 0, 0, tonumber(bare)
    end

    return nil, timecode
end

function report_bad_timecode(timecode, context)
    print("DAELink: could not read the timeline timecode in " .. context .. ".")
    print("DAELink: Resolve returned: [" .. tostring(timecode) .. "]")
    print("DAELink: please report this line at https://nathanstassin.com/daelink so it can be fixed.")
end

function step_timeline_frames(timeline, offset)
    -- Nominal-rate rounding and drop-frame handling both live in timecode_to_frame() and
    -- frame_to_timecode() now, so the raw rate is passed straight through to them.
    local raw_fps = tonumber(timeline:GetSetting("timelineFrameRate"))
    if not raw_fps then
        report_bad_timecode("timelineFrameRate unreadable", "step_timeline_frames")
        return false
    end
    local raw = timeline:GetCurrentTimecode()
    local drop = timeline_is_drop_frame(timeline)

    -- Decode and re-encode through the same pair of functions, so both directions agree about
    -- drop frame. Doing the arithmetic inline here is what made stepping by -1 cross a minute
    -- boundary onto a timecode drop frame skips, which Resolve then snapped somewhere else.
    local total = timecode_to_frame(raw, raw_fps, drop)
    if not total then
        report_bad_timecode(raw, "step_timeline_frames")
        return false
    end

    total = math.max(total + offset, 0)
    timeline:SetCurrentTimecode(frame_to_timecode(total, raw_fps, drop))
    return true
end

-- The one place the playhead position is turned into a timeline frame number.
-- Returns frame, or nil plus the raw timecode so the caller can report it.
--
-- Two things are absorbed here that neither call site handled:
--  * Resolve 21's "frames" timecode display makes GetCurrentTimecode() return a bare number.
--    parse_timecode() reads that as 0:0:0:<n>, but whether Resolve counts that from zero or
--    from the timeline's start timecode is not documented. Rather than guess, the result is
--    checked against the timeline's own frame range: a value below GetStartFrame() can only
--    be relative, so the start frame is added to it.
--  * GetSetting("timelineFrameRate") returning something unreadable. timecode_to_frame()
--    does math.floor(fps + 0.5), which is an arithmetic-on-nil crash, and that is the same
--    class of failure parse_timecode() was introduced to stop.
function get_playhead_frame(timeline)
    local raw = timeline:GetCurrentTimecode()
    local fps = tonumber(timeline:GetSetting("timelineFrameRate"))
    if not fps then
        return nil, "timelineFrameRate was unreadable (timecode was [" .. tostring(raw) .. "])"
    end

    local frame = timecode_to_frame(raw, fps, timeline_is_drop_frame(timeline))
    if not frame then
        return nil, raw
    end
    frame = math.floor(frame + 0.5)

    -- Only meaningful when GetStartFrame exists and reports a non-zero start
    local ok, start_frame = pcall(function() return timeline:GetStartFrame() end)
    if ok and type(start_frame) == "number" and start_frame > 0 and frame < start_frame then
        print(string.format("DAELink: playhead read as frame %d, below the timeline start (%d). " ..
            "Treating it as relative to the timeline start.", frame, start_frame))
        frame = frame + start_frame
    end

    return frame
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

-- DROP-FRAME TIMECODE
--
-- Resolve's internal frame numbering is itself drop-frame aware, which is the fact all of this
-- rests on. Measured on 21.1: a 29.97 timeline whose start timecode is 01:00:00;00 reports
-- GetStartFrame() == 107892, not 108000, and a 59.94 one reports 215784, not 216000. The frame
-- numbers AppendToTimeline takes as recordFrame live in that same space: a clip appended at
-- recordFrame 109692 reports GetStart() == 109692.
--
-- So non-drop arithmetic does not merely mislabel a position, it puts the clip in the wrong
-- place. The error is 2 frames per minute at 29.97 and 4 at 59.94, except every tenth minute,
-- which reaches 108 and 216 frames at the one-hour mark. An 01:00:00:00 start is the broadcast
-- default, so this was 3.6 seconds of misplacement on an ordinary NTSC timeline.
--
-- Both directions were validated against Resolve before being written: 22,500 consecutive
-- frames at 29.97 and 41,500 at 59.94 round-trip exactly, and every spot check agrees with
-- GetStartFrame(), including the minute boundaries where frames are skipped (frame 1800 is
-- 00:01:00;02 at 29.97, not 00:01:00;00) and the tenth minutes where they are not
-- (frame 17982 is 00:10:00;00).
--
-- Drop frame only exists for the NTSC family, so it is applied only when the nominal rate is a
-- multiple of 30. A 23.976 or 25 timeline with the flag somehow set is treated as non-drop
-- rather than having a meaningless correction applied to it.
function drop_frames_per_minute(nominal_fps)
    if nominal_fps % 30 ~= 0 then return 0 end
    return nominal_fps / 15   -- 2 at 30, 4 at 60, 8 at 120
end

-- Reads the timeline's drop-frame flag. GetSetting returns the string "1" or "0".
function timeline_is_drop_frame(timeline)
    if not timeline then return false end
    local ok, value = pcall(function() return timeline:GetSetting("timelineDropFrameTimecode") end)
    if not ok then return false end
    return tostring(value) == "1"
end

-- Returns nil when the timecode cannot be read, so callers must check before use.
-- `drop` is optional and defaults to false, which keeps every non-drop timeline behaving
-- exactly as before.
function timecode_to_frame(timecode, fps, drop)
    local h, m, s, f = parse_timecode(timecode)
    if not h then
        return nil
    end

    -- Nominal (rounded) rate throughout: timecode ALWAYS counts at an integer rate, even on
    -- 23.976 and 29.97. Using the fractional rate makes 3600 * fps land below one hour and
    -- collapses the hours field to zero.
    local nominal_fps = math.floor((tonumber(fps) or 24) + 0.5)
    if nominal_fps < 1 then nominal_fps = 24 end

    local total = (h * 3600 + m * 60 + s) * nominal_fps + f

    if drop then
        local dpm = drop_frames_per_minute(nominal_fps)
        if dpm > 0 then
            local total_minutes = h * 60 + m
            total = total - dpm * (total_minutes - math.floor(total_minutes / 10))
        end
    end

    return total
end

-- Inverse of timecode_to_frame, and the exact inverse: validated by round-tripping every
-- frame across several hours at both 29.97 and 59.94, and by checking the output against
-- GetStartFrame(). It never produces a timecode that drop frame skips, which matters because
-- Resolve snaps an invalid one to the next valid frame and the position would silently move.
--
-- The separator stays ":" even on a drop-frame timeline. Resolve accepts a colon as input and
-- interprets it as drop frame on a drop-frame timeline (verified: SetStartTimecode
-- "01:00:00:00" yields GetStartTimecode "01:00:00;00" and GetStartFrame 107892), and
-- parse_timecode() reads both separators, so there is nothing to gain from emitting ";".
--
-- Both arguments are guarded because one caller feeds it straight from the JSON
-- (entry.compStartFrame, entry.fps). A hand-edited or older entry missing either key used to
-- be an arithmetic-on-nil crash partway through import_new_comps(), after timelines had
-- already been created. Same class of failure parse_timecode() exists to stop.
function frame_to_timecode(frame_number, fps, drop)
    frame_number = tonumber(frame_number) or 0
    local nominal_fps = math.floor((tonumber(fps) or 24) + 0.5)
    if nominal_fps < 1 then nominal_fps = 24 end
    if frame_number < 0 then frame_number = 0 end

    if drop then
        local dpm = drop_frames_per_minute(nominal_fps)
        if dpm > 0 then
            -- Walk the frame count back up into timecode space by re-inserting the numbers
            -- drop frame skips, ten minutes at a time.
            local frames_per_10min = nominal_fps * 600 - dpm * 9
            local frames_per_min = nominal_fps * 60 - dpm
            local tens = math.floor(frame_number / frames_per_10min)
            local rem = frame_number % frames_per_10min
            frame_number = frame_number + dpm * 9 * tens
            if rem >= dpm then
                frame_number = frame_number + dpm * math.floor((rem - dpm) / frames_per_min)
            end
        end
    end

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
        print("DAELink: Top track occupied, adding new " .. track_type .. " track")
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
        print("DAELink: Error: No current timeline.")
        return nil
    end

    local item = get_timeline_mpi(current_timeline)
    if not item then
        print("DAELink: Error: No media pool item for current timeline.")
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
        print("DAELink: No active clip selected in parent timeline.")
        return nil
    end

    local clip_item = clip:GetMediaPoolItem()
    if not clip_item then
        print("DAELink: Error: Clip has no media pool item.")
        return nil
    end

    local nested_id = clip_item:GetMediaId()
    local nested_timeline = get_timeline_byID(nested_id)
    if not nested_timeline then
        print("DAELink: Error: Could not find nested timeline for ID " .. tostring(nested_id))
        return nil
    end

    local comp = compositions[nested_id]
    if not comp then
        print("DAELink: Error: No composition entry for nested timeline.")
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

-- Never compare two frame rates with ~=. A comp that originated on the AE side stores the
-- rate as After Effects reports it, and AE holds frameRate as a 32-bit float, so a 59.94
-- project reads back as 59.939998626709 and a 23.976 one as 23.975999832153. That is correct
-- to about two millionths of a frame and works everywhere, but it is not the "59.94" string
-- DaVinci's GetSetting returns, so ~= called every NTSC-family project a mismatch and popped
-- "Update saved properties?" on the first action against each linked comp.
-- Same tolerance and same reasoning as fpsNameStartFrameCheck in daelink.jsx.
function fps_differs(a, b)
    local na, nb = tonumber(a), tonumber(b)
    -- One of them unreadable: fall back to a plain comparison rather than claiming a match
    if not na or not nb then return a ~= b end
    return math.abs(na - nb) > 0.01
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
    if fps_differs(saved_fps, current_fps) then
        needs_update = true
        table.insert(changes, "Frame Rate: " .. tostring(saved_fps) .. " → " .. tostring(current_fps))
    end
    
    -- Check name mismatch
    if saved_name ~= current_name then
        -- Refuse to adopt a renamed timeline whose name can't survive a round trip through a
        -- render file name. Renaming is the user's call, so we block rather than silently fix.
        local bad_chars = illegal_name_chars(current_name)
        if #bad_chars > 0 then
            alert("The timeline '" .. current_name .. "' contains characters that can't be used in a file name: " ..
                  table.concat(bad_chars, "  ") ..
                  "\n\nThe composition name becomes the render file name, so please rename the timeline " ..
                  "(suggested: '" .. sanitize_name(current_name) .. "') and try again.")
            return nil
        end

        local data = load_json_data(_G.json_path)
        if not data then return nil end
        for id, other_comp in pairs(data.compositions or {}) do
            if id ~= comp_id and other_comp.name == current_name then
                alert("Cannot use name '" .. current_name .. "' - another composition already uses this name.\n\nPlease rename timeline or resolve the conflict.")
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
    if not data or not data.compositions or not data.compositions[comp_id] then return nil end
    if fps_differs(current_fps, saved_fps) then
        data.compositions[comp_id].fps = tostring(current_fps)
    end
    if current_name ~= saved_name then
        data.compositions[comp_id].name = current_name
    end
    
    save_json_data(data)
    
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
        print("DAELink: Could not find source timeline for clip markers.")
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
    print("DAELink: Imported " .. tostring(count) .. " markers to " .. timeline:GetName())
end

function import_markers()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    if not data then return end
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
    if not data then return end
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
        
        return #json_markers, ctx.parent_clip:GetName()
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

        return #json_markers, ctx.active_timeline:GetName()
    end
end

-- SENDING/RECEIVING LINK AE
function insert_placeholder_timeline_at_playhead()
    if not require_initialisation() then return end
    if not _G.media_pool then
        print("DAELink: Error: Could not access Media Pool.")
        return
    end

    if _G.resolve:GetCurrentPage() == "media" then return false end

    local placeholder_timeline = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not placeholder_timeline then
        print("DAELink: Error: 'DAELinkPlaceholder' not found in Media Pool.")
        return
    end

    local current_timeline = _G.project:GetCurrentTimeline()
    if not current_timeline then
        print("DAELink: Error: No active timeline.")
        return
    end

    local fps = tonumber(current_timeline:GetSetting("timelineFrameRate"))
    local playhead_frame, bad_value = get_playhead_frame(current_timeline)
    if not playhead_frame then
        report_bad_timecode(bad_value, "Insert Placeholder")
        alert("Could not read the playhead position on this timeline.\n\nNothing was changed. The Fusion console has the details, please include them in a bug report at nathanstassin.com/daelink.")
        return false
    end

    -- fps is only used for the placeholder length from here on, so a default keeps the
    -- button working even when the rate is unreadable but the playhead was not.
    local duration_frames = math.floor(_G.CONSTANTS.PLACEHOLDER_DURATION * (fps or 24))
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

-- RETIME DETECTION
-- Speed and duration changes are NOT transferred. The Resolve scripting API (checked against the
-- 21.0 Beta docs in Developer/Scripting/README.txt) exposes no speed getter, no speed setter and
-- no access to the retime curve. The only retime-adjacent properties are RetimeProcess and
-- MotionEstimation, which are interpolation quality settings, not the speed value. That means a
-- retime can neither be described to After Effects nor rebuilt inside a nest we create, so the
-- only honest behaviour is to detect it and stop before anything is created.
--
-- Detection is by inference: an untouched clip consumes exactly as many source frames as it
-- occupies on the timeline. A retime breaks that equality. Reverse clips report a source end
-- before the source start, giving a negative ratio; a freeze frame consumes a single source frame
-- over many timeline frames.
-- RETIME DETECTION IS ADVISORY, NOT A GATE.
-- There is no speed value in the API, so this infers one by comparing source frames against
-- timeline frames, and that inference cannot be made exact: two clips both at 100% measured
-- a frame apart in opposite directions (source 0 to 214 over 215, and source 0 to 79 over
-- 79). Tightening the tolerance to catch small retimes refuses real 100% clips instead.
-- So the result is used to warn, and the user decides. Do not turn this back into a refusal
-- without a real speed property to test against.

-- A still has no source duration to measure against: one source frame is stretched over
-- however many timeline frames the clip occupies, so the span-versus-duration test flags
-- every single one. That signature is identical to a freeze frame, which IS a retime worth
-- catching, so the two can only be told apart by what the media is, not by its numbers.
-- Hence the media type check rather than a "one source frame is fine" rule.
-- GetClipProperty("Type") is asked first because it distinguishes a still from an image
-- sequence, which has a real duration and can genuinely be retimed. The extension list is
-- only a fallback for when that property cannot be read, and it does not make that
-- distinction: a retimed image sequence would slip through. Missing that is a far smaller
-- cost than refusing every project with a PNG in it.
function is_still_clip(clip)
    local ok, mpi = pcall(function() return clip:GetMediaPoolItem() end)
    if not ok or not mpi then return false end

    local ok_type, clip_type = pcall(function() return mpi:GetClipProperty("Type") end)
    if ok_type and type(clip_type) == "string" and clip_type ~= "" then
        return clip_type:lower():find("still", 1, true) ~= nil
    end

    local ok_path, path = pcall(function() return mpi:GetClipProperty("File Path") end)
    if not ok_path or type(path) ~= "string" then return false end
    local lower = path:lower()
    for _, ext in ipairs(_G.CONSTANTS.STILL_EXTENSIONS) do
        if lower:sub(-#ext) == ext then return true end
    end
    return false
end

function get_clip_speed_ratio(clip)
    -- Returns: ratio, source_span, duration, src_start, src_end (nil if unreadable)
    local ok, src_start, src_end, duration = pcall(function()
        return clip:GetSourceStartFrame(), clip:GetSourceEndFrame(), clip:GetDuration(true)
    end)
    if not ok then return nil end
    if type(src_start) ~= "number" or type(src_end) ~= "number" or type(duration) ~= "number" then
        return nil
    end
    if duration <= 0 then return nil end
    -- The +1 is correct: GetSourceEndFrame is INCLUSIVE, unlike GetEnd against GetStart.
    -- Measured, not assumed. An untouched clip reports source 0 to 214 over 215 timeline
    -- frames, so frames 0..214 inclusive is exactly the 215 the clip occupies. A 102%
    -- retime of the same media reports source 0 to 90 over 89, and 91/89 is 1.022.
    -- Dropping this made every untouched clip read one frame short, which passed only
    -- because the tolerance had been loosened to hide it, and let sub-2% retimes through.
    -- Signed so a reversed clip reports a negative ratio rather than a plausible one.
    local direction = (src_end < src_start) and -1 or 1
    local source_span = (math.abs(src_end - src_start) + 1) * direction
    return source_span / duration, source_span, duration, src_start, src_end
end

-- Resolve 21.1 exposes TimelineItem:GetSpeed(), returning { Percentage = <float>, ... } with
-- 0.0 meaning freeze frame. That is the real speed value everything below has been inferring
-- from frame counts, so where it exists it is authoritative and the inference is skipped.
--
-- It does NOT exist on every supported target. DAELink still supports Studio 20 and Free
-- 19.0.3, and the 21.0 developer README documented no speed getter at all, which is why the
-- frame-count inference stays as the fallback instead of being deleted. Same capability-check
-- idiom as get_timeline_mpi() uses for Timeline:GetMediaPoolItem().
-- Returns: percentage (number), or nil when the API is absent or unreadable.
function get_clip_speed_percentage(clip)
    if not clip.GetSpeed then return nil end
    local ok, opts = pcall(function() return clip:GetSpeed() end)
    if not ok or type(opts) ~= "table" then return nil end
    return tonumber(opts.Percentage or opts.percentage)
end

function is_clip_retimed(clip)
    -- Returns: is_retimed, ratio, source_span, duration, src_start, src_end, exact_percentage
    --
    -- Exact path, where the running Resolve provides it. No frame-sized tolerance is needed
    -- here: this is the number the user typed into the speed dialog, not one recovered from
    -- integer frame counts, so a tenth of a percent is plenty. 0 is Resolve's freeze frame,
    -- which is a retime worth catching, and it falls out of the same comparison.
    local exact_pct = get_clip_speed_percentage(clip)
    if exact_pct then
        return math.abs(exact_pct - 100) > 0.1, exact_pct / 100, nil, nil, nil, nil, exact_pct
    end

    -- Returns: is_retimed, ratio, source_span, duration
    local ratio, source_span, duration, src_start, src_end = get_clip_speed_ratio(clip)
    if not ratio then return false end
    -- A frame and a half, and it cannot go lower. Two clips both reported as untouched
    -- measured one frame apart in opposite directions: `source 0 to 214` over 215 frames
    -- (matching the inclusive reading) and `source 0 to 79` over 79 (matching the exclusive
    -- one). So an untouched clip is only reliably within one frame of its duration, whatever
    -- the endpoint convention is, and 0.5 refuses real 100% clips.
    -- The cost is real and accepted: a retime moving this by less than two frames is not
    -- detectable, so on a short clip anything under roughly 2% transfers as a small timing
    -- drift inside that layer rather than being refused. That is the better failure. A miss
    -- is a sub-frame shift the user will not see; a false positive blocks a legitimate
    -- project outright, which is what 0.5 did.
    -- This whole test is inference. If TimelineItem ever exposes a real speed property, use
    -- it and delete this.
    return math.abs(source_span - duration) > 1.5, ratio, source_span, duration, src_start, src_end
end

-- Returns a list of "name (speed%)" strings for every retimed clip in the list, plus a flag
-- saying whether any of those figures was inferred from frame counts rather than read from
-- GetSpeed(). The caller uses the flag to decide whether to warn about false positives, which
-- only the inferred path can produce.
function find_retimed_clips(clips)
    local retimed = {}
    local any_estimated = false
    local already_listed = {}
    for _, clip in ipairs(clips or {}) do
        if clip:GetName() ~= _G.CONSTANTS.PLACEHOLDER_TL_NAME then
            local name = tostring(clip:GetName())
            local still = is_still_clip(clip)
            local flagged, ratio, source_span, duration, src_start, src_end, exact_pct = is_clip_retimed(clip)
            if still then flagged = false end
            -- Logged for every clip, not just the flagged ones, so a mis-detection can be
            -- diagnosed from the console without re-running a separate probe. The raw source
            -- frames are here too, because the inclusive-versus-exclusive question above can
            -- only be settled from them.
            if exact_pct then
                -- Nothing to diagnose on this path: the value is read, not inferred.
                print(string.format("DAELink retime check: %s | GetSpeed reports %.2f%%%s",
                    name, exact_pct, still and " | still, exempt" or ""))
            else
                print(string.format("DAELink retime check: %s | source %s to %s (%s frames) | timeline frames %s | ratio %s%s",
                    name,
                    tostring(src_start or "?"),
                    tostring(src_end or "?"),
                    tostring(source_span or "?"),
                    tostring(duration or "?"),
                    ratio and string.format("%.4f", ratio) or "unreadable",
                    still and " | still, exempt" or ""))
            end
            -- A linked video and its audio arrive as two clips sharing one name, so without
            -- this the alert lists the same file twice and reads like two problems.
            if flagged and not already_listed[name] then
                already_listed[name] = true
                if exact_pct then
                    table.insert(retimed, string.format("%s  (%.1f%%)", name, exact_pct))
                else
                    -- Approximate by nature: the timeline duration is an integer, so the
                    -- speed the user typed is not recoverable from it. Expect this to sit
                    -- within a percent or two of what was applied.
                    any_estimated = true
                    table.insert(retimed, string.format("%s  (%.0f%%, estimated)", name, ratio * 100))
                end
            end
        end
    end
    return retimed, any_estimated
end

-- Clips whose media pool item has no file on disk: compound clips, nested timelines,
-- generators, titles, adjustment clips, Fusion compositions. An AE layer is a file, so
-- there is nothing to hand over. Letting one through writes a layer with an empty filePath,
-- which importAndAddLayers reports as "File not found:" with nothing after the colon,
-- pointing the user at a missing file rather than at media that never had one.
-- Checked alongside the retime refusal, before anything is created, so the project is
-- left untouched and the alert can name the clip.
function find_unimportable_clips(clips)
    local unimportable = {}
    local already_listed = {}
    for _, clip in ipairs(clips or {}) do
        local name = tostring(clip:GetName())
        if name ~= _G.CONSTANTS.PLACEHOLDER_TL_NAME and not already_listed[name] then
            local file_path = nil
            local ok, mpi = pcall(function() return clip:GetMediaPoolItem() end)
            if ok and mpi then
                local ok_path, value = pcall(function() return mpi:GetClipProperty("File Path") end)
                if ok_path and type(value) == "string" and value ~= "" then file_path = value end
            end
            if not file_path then
                already_listed[name] = true
                table.insert(unimportable, name)
            end
        end
    end
    return unimportable
end

function replace_linked_with_aecomp(comp_name, use_custom_settings, custom_settings)
    if not require_initialisation() then return end
    get_daelink_folders()
    local placeholder_timeline = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not comp_name or comp_name:match("^%s*$") then
        alert("Please enter a valid composition name.")
        return
    end

    -- Second line of defence: the dialog sanitises, but this entry point is also reachable
    -- with a name from elsewhere, and an illegal character here breaks the render path.
    local cleaned_name, name_changed = sanitize_name(comp_name)
    if cleaned_name == "" then
        alert("Please enter a composition name containing at least one usable character.")
        return
    end
    if name_changed then
        print("DAELink: Composition name sanitised for file-system safety: '" .. comp_name .. "' -> '" .. cleaned_name .. "'")
        comp_name = cleaned_name
    end
    local base_timeline = _G.project:GetCurrentTimeline()
    local placeholder = base_timeline:GetCurrentVideoItem()

    if not placeholder or placeholder:GetName() ~= placeholder_timeline:GetName() then
        alert("Error: No DAELinkPlaceholder in top active video layer.")
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

    -- Retimes are warned about, not refused (see find_retimed_clips). The detection is
    -- inference and cannot be made exact, so this asks rather than blocks: a wrong guess
    -- costs one click, where refusing cost the user the whole operation. Runs before the
    -- timeline is created, so declining leaves the project exactly as it was.
    local retimed_clips, retimes_estimated = find_retimed_clips(linked_to_placeholder)
    if #retimed_clips > 0 then
        -- The false-positive caveat only applies to figures inferred from frame counts. When
        -- every figure came from GetSpeed() the numbers are exact, and telling the user they
        -- might be wrong would be untrue and would make a real warning easier to dismiss.
        local caveat = ""
        if retimes_estimated then
            caveat = "The percentages marked 'estimated' are inferred from frame counts, and a clip at " ..
                     "normal speed is occasionally listed by mistake.\n\n"
        end
        local proceed = confirm("These clips linked to the placeholder are retimed:\n\n" ..
              table.concat(retimed_clips, "\n") ..
              "\n\nA retime cannot be carried across to After Effects, so these layers will transfer at " ..
              "100% speed and will not match what you see in DaVinci.\n\n" ..
              caveat ..
              "To keep the timing, cancel and render the retimed clip out, then link the result.\n\n" ..
              "Create the comp anyway?")
        if not proceed then return end
    end

    -- Media with no file on disk cannot become an AE layer (see find_unimportable_clips).
    -- Same reasoning as the retime check above: refuse before creating anything.
    local unimportable_clips = find_unimportable_clips(linked_to_placeholder)
    if #unimportable_clips > 0 then
        alert("Clips that are not media files are not supported.\n\n" ..
              "These clips linked to the placeholder have no file on disk:\n\n" ..
              table.concat(unimportable_clips, "\n") ..
              "\n\nCompound clips, nested timelines, titles, generators and adjustment clips exist only " ..
              "inside DaVinci, so there is no file for After Effects to import.\n\n" ..
              "Link the original media instead, or render these out and link the result.\n\n" ..
              "Operation aborted.")
        return
    end

    -- Create nested timeline
    local nested_timeline = _G.media_pool:CreateEmptyTimeline(comp_name)
    local nested_timeline_mpi = get_timeline_mpi(nested_timeline)
    _G.media_pool:MoveClips({ nested_timeline_mpi }, _G.comps_folder)
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
        -- Earliest linked-clip start (for placing the content at its offset relative to the placeholder)
        local earliest_start = nil
        for _, c in ipairs(layers_in_compound) do
            local s = c:GetStart(true)
            if earliest_start == nil or s < earliest_start then
                earliest_start = s
            end
        end
        local content_offset = (earliest_start or placeholder_time_in_base_timeline) - placeholder_time_in_base_timeline
        if content_offset < 0 then content_offset = 0 end

        if #layers_in_compound == 1 then
            local timeline_clip = layers_in_compound[1]
            local mpi = timeline_clip:GetMediaPoolItem()
            local src_start = timeline_clip:GetSourceStartFrame()
            local src_end = timeline_clip:GetSourceEndFrame()
            _G.project:SetCurrentTimeline(nested_timeline)
            _G.media_pool:AppendToTimeline({{
                mediaPoolItem = mpi,
                startFrame = src_start,
                endFrame = src_end,
                trackIndex = 2,
                recordFrame = content_offset
            }})
            _G.project:SetCurrentTimeline(base_timeline)
        elseif #layers_in_compound > 1 then
            local compound_name = comp_name .. _G.CONSTANTS.LINKED_CLIPS_SUFFIX
            base_timeline:CreateCompoundClip(layers_in_compound, { name = compound_name })
            local compound_mpi = get_mpi_by_name(compound_name)
            _G.media_pool:MoveClips({ compound_mpi }, _G.compound_clips_folder)
            if compound_mpi then
                _G.project:SetCurrentTimeline(nested_timeline)
                _G.media_pool:AppendToTimeline({{ mediaPoolItem = compound_mpi, trackIndex = 2, recordFrame = content_offset }})
                _G.project:SetCurrentTimeline(base_timeline)
                
                local compound_clip = base_timeline:GetCurrentVideoItem()
                if compound_clip and compound_clip:GetName() == compound_name then
                    -- Built as a list rather than passed inline: a compound clip with no
                    -- audio returns an empty GetLinkedItems(), and { clip, nil } is a table
                    -- with a hole in it rather than a one-element list.
                    local to_delete = { compound_clip }
                    local linked_audio = (compound_clip:GetLinkedItems() or {})[1]
                    if linked_audio then table.insert(to_delete, linked_audio) end
                    base_timeline:DeleteClips(to_delete, false)
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
        print("DAELink: Original track " .. placeholder_trackIndex .. " was occupied. Using track " .. final_track_index .. " instead.")
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
        print("DAELink: Bug: Nested timeline has audio but no audio was linked to the appended clip")
    end

    add_markers_to_clip(nest_clip[1])

    -- Prevent duplicate timeline bug in Compositions bin
    _G.media_pool:SetCurrentFolder(_G.root_folder)
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
    if not data or not data.compositions then return false end
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
                print("DAELink: Skipping:", entry.name, "(could not create timeline)")
            else
                local timeline_mpi = get_timeline_mpi(new_timeline)
                -- tostring: SetSetting expects strings, and these arrive from the JSON as
                -- numbers because the AE side writes activeComp.width / .height. Passing the
                -- raw number is silently ignored, which left the comp at the project
                -- resolution instead of its own. replace_linked_with_aecomp() has always
                -- wrapped the same two calls.
                new_timeline:SetSetting("UseCustomResolution", "1")
                new_timeline:SetSetting("timelineResolutionHeight", tostring(entry.resolutionHeight))
                new_timeline:SetSetting("timelineResolutionWidth", tostring(entry.resolutionWidth))
                
                local comp_start_frame = entry.compStartFrame
                local comp_start_timecode = frame_to_timecode(
                    comp_start_frame, entry.fps, timeline_is_drop_frame(new_timeline))
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

                print("DAELink: Created timeline:", entry.name, "with ID:", media_id)
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
    local playhead_frame, bad_value = get_playhead_frame(current_timeline)
    if not playhead_frame then
        -- The comps and their JSON entries are already committed at this point, so the
        -- only thing lost is the placement onto the parent timeline. Say that plainly
        -- rather than aborting in a way that reads like nothing happened.
        report_bad_timecode(bad_value, "Import Linked Comps")
        alert("The comps were created, but the playhead position could not be read so they were not placed on the timeline.\n\nDrag them in from the Media Pool. The Fusion console has the details, please include them in a bug report at nathanstassin.com/daelink.")
        return false
    end

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
            
        else
            print("DAELink: Warning: Failed to append timeline:", tl_data.entry.name)
        end
        
        current_record_frame = current_record_frame + duration
    end

    print("DAELink: Successfully imported " .. #created_timelines .. " composition(s) from After Effects.")
    return true
end

-- RENDER MANAGEMENT
function refresh_render()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    if not data then return end
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

    -- Persist the renderFile that refresh_render_in_timeline just resolved
    save_json_data(ctx.updated_data)

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
        print("DAELink: Error: Could not extract filename from renderPath: " .. tostring(render_path_base))
        return false
    end

    local basename = strip_video_extension(filename)
    local paths = build_project_paths(_G.project_media_path)
    local search_dir = paths.renders

    -- Cross-platform file finding using Lua's built-in functions
    local function find_matching_render(dir, base)
        local separator = package.config:sub(1,1)
        local is_windows = separator == '\\'

        -- Normalise directory path
        dir = dir:gsub("\\", "/")

        -- Listing is sorted newest-first so that when the same comp has been rendered to more
        -- than one container (e.g. an old comp.mov beside a new comp.mp4) we pick the current
        -- render rather than whichever name happens to sort first.
        local handle
        if is_windows then
            handle = io.popen('dir /b /o-d "' .. dir:gsub('/', '\\') .. '" 2>nul')
        else
            handle = io.popen('ls -1t "' .. dir .. '" 2>/dev/null')
        end

        if not handle then return nil end

        -- Search through directory listing for matching basename
        for filename in handle:lines() do
            if is_video_file(filename) and strip_video_extension(filename) == base then
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
        print("DAELink: Error: Failed to import render " .. render_path)
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
        local render_has_audio = appended_audio and #appended_audio > 0
        timeline:SetTrackEnable("audio", 1, render_has_audio) -- Unmute A1 only when render carries audio
        -- Log the file actually used, extension included. renderPath is extensionless (AE decides
        -- the container at render time), so this is the only record of what is currently linked.
        comp_data["renderFile"] = render_path
        print("DAELink: Imported render: " .. render_path)
        _G.media_pool:SetCurrentFolder(initial_folder)
        return true
    end

    print("DAELink: Error: Failed to append render to timeline.")
    return false
end

function replace_render_after_refresh()
    if not require_initialisation() then return end

    local data = load_json_data(_G.json_path)
    if not data then return end
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
        print("DAELink: No active video item to replace.")
    else
        local mpi = clip:GetMediaPoolItem()
        if not mpi then
            print("DAELink: No media pool item on selected clip.")
        else
            local props = mpi:GetClipProperty() or {}
            local media_path =
                props["File Path"] or
                props["Filepath"] or
                props["Filename"]

            if not media_path then
                print("DAELink: Could not determine media path for replacement.")
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

function confirm_and_delete_unused_renders()
    local data = load_json_data(_G.json_path)
    if not data or not data.compositions then
        print("DAELink: Error: Invalid data structure (missing 'compositions').")
        return nil
    end

    local unused_files = get_unused_render_files(data)
    if #unused_files == 0 then
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
        return nil
    end

    -- Single confirmation with preview
    local preview = table.concat(selected, "\n", 1, math.min(#selected, 10))
    if #selected > 10 then
        preview = preview .. "\n... and " .. (#selected - 10) .. " more"
    end
    
    if not confirm("Permanently delete " .. #selected .. " file(s)?\n\n" .. preview) then
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
            print("DAELink: Deleted: " .. fp)
        else
            print("DAELink: Failed to delete: " .. fp)
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
        print("DAELink: Error: Failed to append media pool item to timeline.")
    end
end

function delete_obsolete_nests(data)
    local removed = 0
    local compositions = data["compositions"]

    -- Collect keys to remove (to avoid modifying table while iterating)
    --
    -- prelink keys are skipped. They are NOT media IDs: the AE side writes "prelink1",
    -- "prelink2" and so on for comps it has linked but which have no DaVinci nest yet, and
    -- import_new_comps() is what turns them into real timelines. get_timeline_byID() can
    -- never match one, so without this guard every pending link was silently deleted by the
    -- next Refresh Render, marker action or Open AE click, and the user then got
    -- "No new compositions found from After Effects" with no hint that their link had ever
    -- existed. Same guard the STEP 1 loop in import_new_comps() already applies.
    local obsolete_ids = {}
    for davinci_id, _ in pairs(compositions) do
        local is_prelink = type(davinci_id) == "string"
            and davinci_id:match(_G.CONSTANTS.PRELINK_PATTERN) ~= nil
        if not is_prelink and not get_timeline_byID(davinci_id) then
            table.insert(obsolete_ids, davinci_id)
        end
    end

    for _, id in ipairs(obsolete_ids) do
        compositions[id] = nil
        removed = removed + 1
        print("DAELink: Removed obsolete entry: " .. tostring(id))
    end

    if removed > 0 then
        save_json_data(data)
        print("DAELink: Removed " .. removed .. " obsolete composition(s) from JSON.")
    end
end

function remove_orphaned_render_mpis()
    -- Extra cleanup: remove unused (0-usage) media pool items in the Renders bin
    -- In case render file was overwitten with different duration - this causes an orphaned reference for the old longer render
    get_daelink_folders()

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
                    print("DAELink: Removed orphaned render reference: " .. name)
                else
                    print("DAELink: Failed to remove clip from Media Pool: " .. name)
                end
            end
        end
    else
        print("DAELink: Renders bin not found - skipping orphan cleanup.")
    end
end

function get_known_render_bases(data)
    local known_bases = {}
    local function add(path)
        if not path then return end
        local fname = path:match("([^/\\]+)$")
        local base = fname and strip_video_extension(fname) or ""
        if base ~= "" then known_bases[base] = true end
    end
    for _, comp in pairs(data["compositions"]) do
        add(comp["renderPath"])
        -- renderFile is the file actually imported by the last Refresh Render. If renderPath and
        -- the real file ever disagree again, the file in use must still never be offered for
        -- deletion - that mismatch is what made a fresh render look like an orphan.
        add(comp["renderFile"])
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
        print("DAELink: Error: Could not access Renders directory: " .. tostring(search_dir))
        return {}
    end

    local known_bases = get_known_render_bases(data)
    local unused_files = {}
    
    for file in handle:lines() do
        if is_video_file(file) then
            -- Keyed by basename, so a superseded render in a different container (comp.mov left
            -- beside a newer comp.mp4) still counts as "known" and is never offered for deletion.
            local base = strip_video_extension(file)
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

-- Open After Effects with no project loaded. Used when nothing is linked yet, so there is
-- no .aep to open and nothing for a script to act on.
-- Windows has no `open -a` equivalent, but find_afterfx_com() already locates the newest
-- install and AfterFX.exe sits beside AfterFX.com in the same Support Files folder.
-- Returns false when there is no install to launch, and stays silent about it: every caller
-- is already saying something of its own, and two stacked modals help nobody.
function launch_ae_bare(is_windows)
    if not is_windows then
        os.execute('open -a "Adobe After Effects"')
        return true
    end

    local afterfx_com = find_afterfx_com()
    if not afterfx_com then return false end

    local exe = afterfx_com:gsub("AfterFX%.com$", "AfterFX.exe")
    os.execute('cmd /c start "" "' .. exe:gsub("/", "\\") .. '"')
    return true
end

-- OPEN AE PROJECT
-- Reads aeProjectPath from daelink.json (written by the JSX side on every successful
-- connection). When a DAELink nest clip is under the playhead, uses osascript (Mac)
-- to open that specific composition in AE. Otherwise opens the linked project file.
-- Outcomes when no nest is detected:
--   1. JSON missing / aeProjectPath empty → launch AE with no project
--   2. Path present, file exists         → launch that .aep/.aet
--   3. Path present, file missing        → alert the user, then launch AE with no project
function open_ae_project()
    local separator = package.config:sub(1,1)
    local is_windows = separator == '\\'

    local data = nil
    local ae_path = nil
    if _G.json_path and file_exists(_G.json_path) then
        data = load_json_data(_G.json_path)
        if data then ae_path = data.aeProjectPath end
    end

    if not ae_path or ae_path == "" then
        if not launch_ae_bare(is_windows) then
            alert("No linked After Effects project yet.\n\nOpen After Effects and connect this DaVinci project from the DAELink panel.")
        end
        return
    end

    if not file_exists(ae_path) then
        alert("Linked AE project not found at:\n" .. ae_path .. "\n\nThe file may have been moved or renamed.\n\nOpen After Effects and connect from the DAELink panel to re-link.")
        launch_ae_bare(is_windows)
        return
    end

    -- Check if a DAELink nest clip is under the playhead - if so, open that comp directly
    if data then
        local ctx = resolve_context(data)
        if ctx and ctx.comp and ctx.comp.aeID then
            open_ae_comp(ae_path, ctx.comp.aeID, ctx.comp.name, is_windows)
            return
        end
    end

    if is_windows then
        local native_path = ae_path:gsub("/", "\\")
        os.execute('cmd /c start "" "' .. native_path .. '"')
    else
        os.execute('open "' .. ae_path .. '"')
    end
end

-- Escape a string for embedding inside a double-quoted ExtendScript string literal.
-- Paths reaching here are normally forward-slashed, but nothing guarantees that, and a lone
-- backslash would silently turn into an escape sequence inside the generated script.
local function jsx_string_literal(s)
    return (tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"'))
end

-- Run ExtendScript inside After Effects, opening ae_path first if it is not already the
-- current project. This is the shared transport, not a feature: open_ae_comp() sends a
-- "find this comp and show it" payload, push_new_comps_to_ae() sends an "import the
-- pending comps" one. Returns false only if the temp file could not be written, in which
-- case it falls back to opening the project so the click still does something.
-- wait_seconds is Windows-only (see run_jsx_in_ae_windows); Mac polls and ignores it.
function run_jsx_in_ae(ae_path, jsx_source, is_windows, wait_seconds)
    local tmp_jsx = os.tmpname() .. ".jsx"
    local f = io.open(tmp_jsx, "w")
    if not f then
        print("DAELink: Could not create temp script, falling back to project open.")
        if is_windows then
            os.execute('cmd /c start "" "' .. ae_path:gsub("/", "\\") .. '"')
        else
            os.execute('open "' .. ae_path .. '"')
        end
        return false
    end
    f:write(jsx_source)
    f:close()

    if is_windows then
        run_jsx_in_ae_windows(ae_path, tmp_jsx, wait_seconds)
    else
        run_jsx_in_ae_mac(ae_path, tmp_jsx)
    end
    return true
end

-- Open the AE project and navigate to a specific comp by its AE item ID.
function open_ae_comp(ae_path, ae_comp_id, comp_name, is_windows)
    local jsx = 'var targetID = ' .. tostring(ae_comp_id) .. ';\n'
        .. 'var comp = null;\n'
        .. 'for (var i = 1; i <= app.project.numItems; i++) {\n'
        .. '    var item = app.project.item(i);\n'
        .. '    if ((item instanceof CompItem) && item.id == targetID) {\n'
        .. '        comp = item;\n'
        .. '        break;\n'
        .. '    }\n'
        .. '}\n'
        .. 'if (comp) {\n'
        .. '    try {\n'
        .. '        comp.openInViewer();\n'
        .. '    } catch (e) {\n'
        .. '        // AE throws "layer does not have a source" on comps with Null/Camera/Light/Text/Shape\n'
        .. '        // layers. Suppress the dialog -- the comp is still shown in the viewer.\n'
        .. '        // Select it in the Project panel as a fallback so the timeline can be opened manually.\n'
        .. '        comp.selected = true;\n'
        .. '    }\n'
        .. '}\n'

    print("DAELink: Opening comp '" .. comp_name .. "' in After Effects...")
    run_jsx_in_ae(ae_path, jsx, is_windows)
end

-- Windows: find AfterFX.com and use -r to run the script in AE.
-- AfterFX.com -r targets a running instance or launches AE if needed.
-- Opens the project file first if AE isn't running or has a different project.
-- wait_seconds is the settle time between the two, defaulting to the 3 seconds this has
-- always used. There is no readiness signal to poll from cmd, so callers whose payload
-- must not run against a half-loaded project pass a longer value (see ae_settle_seconds).
function run_jsx_in_ae_windows(ae_path, tmp_jsx, wait_seconds)
    -- Find AfterFX.com by scanning Program Files for versioned AE installs (newest first)
    local afterfx = find_afterfx_com()
    if not afterfx then
        print("DAELink: Could not find AfterFX.com. Opening project file instead.")
        os.execute('cmd /c start "" "' .. ae_path:gsub("/", "\\") .. '"')
        os.execute('del "' .. tmp_jsx:gsub("/", "\\") .. '" >nul 2>&1')
        return
    end

    local native_ae = ae_path:gsub("/", "\\")
    local native_jsx = tmp_jsx:gsub("/", "\\")
    local native_afterfx = afterfx:gsub("/", "\\")

    local wait = tostring(math.max(1, math.floor(tonumber(wait_seconds) or 3)))

    -- Open the project file first (brings AE to front / opens project),
    -- then run the script via AfterFX.com -r.
    -- cmd /c start opens the .aep asynchronously; AfterFX.com -r waits for AE to be ready.
    -- Wrap in a start /b so we don't block the Resolve UI.
    local cmd = 'start /b cmd /c "'
        .. 'start "" "' .. native_ae .. '" && '
        .. 'timeout /t ' .. wait .. ' /nobreak >nul && '
        .. '"' .. native_afterfx .. '" -r "' .. native_jsx .. '" && '
        .. 'del "' .. native_jsx .. '" >nul 2>&1'
        .. '"'

    os.execute(cmd)
end

-- Parse an AE install folder name into a comparable (family, version) key so the
-- newest install can be found by actual version, not folder-name alphabetical order.
-- Reverse-alphabetical folder sort puts "CS6" ahead of "2026", since 'C' sorts above '2'.
-- Ordering (oldest to newest): "CS<n>" < "CC" < "CC <year>[.<minor>]" < "<year>"
-- (Adobe dropped the "CC" prefix and reset to plain year numbers starting with the
-- "2020" release.)
local function afterfx_folder_version_key(name)
    local cs_num = name:match("^Adobe After Effects CS(%d+)$")
    if cs_num then
        return 0, tonumber(cs_num)
    end
    if name == "Adobe After Effects CC" then
        return 1, 0
    end
    local cc_year, cc_minor = name:match("^Adobe After Effects CC (%d+)%.?(%d*)$")
    if cc_year then
        local minor = tonumber(cc_minor) or 0
        return 1, tonumber(cc_year) + minor / 10
    end
    local plain_year = name:match("^Adobe After Effects (%d+)$")
    if plain_year then
        return 2, tonumber(plain_year)
    end
    return -1, 0
end

-- Scan Program Files for the newest Adobe After Effects install containing AfterFX.com.
-- Candidates are sorted by parsed version, not folder-name order, so a mixed set of
-- installs (e.g. CS6 through 2026 on the same machine) resolves to the real newest one.
function find_afterfx_com()
    local base = "C:\\Program Files\\Adobe"
    local handle = io.popen('dir /b "' .. base .. '\\Adobe After Effects*" 2>nul')
    if not handle then return nil end

    local candidates = {}
    for line in handle:lines() do
        local family, version = afterfx_folder_version_key(line)
        if family >= 0 then
            table.insert(candidates, { name = line, family = family, version = version })
        end
    end
    handle:close()

    table.sort(candidates, function(a, b)
        if a.family ~= b.family then return a.family > b.family end
        return a.version > b.version
    end)

    for _, c in ipairs(candidates) do
        local candidate = base .. "\\" .. c.name .. "\\Support Files\\AfterFX.com"
        local test = io.open(candidate, "r")
        if test then
            test:close()
            return candidate
        end
    end
    return nil
end

-- Mac: use osascript + AppleScript to run the script in AE.
-- Detects whether AE is already running and whether the correct project is open,
-- skipping unnecessary launches and polling for readiness instead of blind sleeping.
function run_jsx_in_ae_mac(ae_path, tmp_jsx)
    -- Write a temp AppleScript that:
    -- 1. Checks if AE is already running (System Events) - avoids cold-launching just to check
    -- 2. If running, checks if the correct project is already open (DoScript + temp file)
    -- 3. Only calls `open` on the .aep if needed, then polls until AE is responsive
    -- 4. Calls DoScriptFile to run the payload
    -- Uses bundle ID (com.adobe.AfterEffects.application) so it works across AE versions.
    local tmp_scpt = os.tmpname() .. ".applescript"
    local escaped_ae_path = ae_path:gsub('"', '\\"')
    local applescript = [[
set jsxFile to "]] .. tmp_jsx .. [["
set aePath to "]] .. escaped_ae_path .. [["

-- Check if AE is already running (without launching it)
tell application "System Events"
    set aeRunning to exists process "After Effects"
end tell

set needsOpen to true
if aeRunning then
    -- AE is running - check if the correct project is already open
    try
        tell application id "com.adobe.AfterEffects.application"
            set checkFile to jsxFile & ".check"
            set checkScript to "var f = app.project.file; var out = new File('" & checkFile & "'); out.open('w'); out.write(f ? f.fsName : ''); out.close();"
            DoScript checkScript
        end tell
        set currentPath to do shell script "cat " & quoted form of (jsxFile & ".check") & " 2>/dev/null; rm -f " & quoted form of (jsxFile & ".check")
        if currentPath is equal to aePath then
            set needsOpen to false
        end if
    end try
end if

if needsOpen then
    do shell script "open " & quoted form of aePath
    -- Stage 1: wait for AE's scripting engine to wake up (responds to any DoScript)
    set maxAttempts to 30
    repeat maxAttempts times
        delay 1
        try
            tell application id "com.adobe.AfterEffects.application"
                DoScript "1"
            end tell
            exit repeat
        end try
    end repeat
    -- Stage 2: wait for the correct project to finish loading.
    -- AE's scripting engine can respond (stage 1 passes) before the project file is
    -- fully loaded, so app.project.numItems may be 0 or items uninitialized. Poll
    -- until the project file path matches AND at least one item is loaded.
    set maxAttempts to 30
    repeat maxAttempts times
        delay 1
        try
            tell application id "com.adobe.AfterEffects.application"
                set result to DoScript "app.project.file && app.project.numItems > 0 ? app.project.file.fsName : ''"
            end tell
            if result is equal to aePath then
                exit repeat
            end if
        end try
    end repeat
end if

-- Run the payload. AE is brought to the front deliberately: the import path can need to
-- ask the user something (unsaved project, live-link takeover, relocated folder), and a
-- modal behind a background app would hang AE with no visible cause.
tell application id "com.adobe.AfterEffects.application"
    activate
    DoScriptFile jsxFile
end tell
]]

    local f = io.open(tmp_scpt, "w")
    if not f then
        print("DAELink: Could not create temp AppleScript, falling back to project open.")
        os.execute('rm -f "' .. tmp_jsx .. '"')
        os.execute('open "' .. ae_path .. '"')
        return
    end
    f:write(applescript)
    f:close()

    -- Run in background so we don't block the Resolve UI
    local cmd = '(osascript "' .. tmp_scpt .. '"; rm -f "' .. tmp_jsx .. '" "' .. tmp_scpt .. '") &'
    os.execute(cmd)
end

-- PUSH NEW COMPS TO AE
-- Second half of "Make AE Comp From Placeholder". The nest exists and the entry is in
-- daelink.json, so this tells AE to turn it into a comp, making one click in DaVinci do
-- what used to take a click in each app. It sends exactly the call the AE-side
-- "Import Linked Comps" button makes, so the result is identical either way, and that
-- button stays as the manual path for when this does not land.

-- Windows has no readiness signal to poll, only the fixed settle time in
-- run_jsx_in_ae_windows. A warm AE needs almost none; a cold launch needs far more than
-- the 3 seconds Open AE has always used, and running the import payload against a
-- half-loaded project is the one outcome worth avoiding. Probe once and pick.
-- If cold launches still miss, the better fix is a poll inside the payload itself
-- (app.scheduleTask) rather than a longer guess here.
function ae_settle_seconds()
    local handle = io.popen('tasklist /FI "IMAGENAME eq AfterFX.exe" /NH 2>nul')
    if not handle then return 20 end
    local out = handle:read("*a") or ""
    handle:close()
    if out:find("AfterFX.exe", 1, true) then return 3 end
    return 20
end

-- The payload. Two guards, in order:
--   1. The open project must be the linked one. Without this a Windows cold launch that
--      outran the settle time would create the comp in whatever untitled project AE came
--      up with and write its aeID into the JSON, which is worse than importing nothing.
--   2. The panel's remote entry point must exist. It is registered by buildUI() in
--      daelink.jsx, so it is there whenever the panel is loaded. When it is not, the
--      script file is loaded directly, which registers it and shows the panel as a
--      floating palette.
-- Either guard failing leaves the user exactly where they were before this feature
-- existed, plus an alert naming the button that finishes the job.
function build_import_payload(ae_path, ae_script)
    local expected = jsx_string_literal(ae_path)
    local script_src = jsx_string_literal(ae_script or "")

    local template = [[
(function () {
    var expected = "__EXPECTED__";
    var scriptPath = "__SCRIPT__";
    var current = app.project.file ? app.project.file.fsName.replace(/\\/g, "/") : "";

    if (current !== expected) {
        alert("DAELink: the After Effects project linked to this DaVinci project is not open.\n\nOpen it, then click Import Linked Comps in the DAELink panel to create the comp.");
        return;
    }

    var run = $.global.DAELink_importNewComps;
    if (!run && scriptPath !== "") {
        var scriptFile = new File(scriptPath);
        if (scriptFile.exists) {
            $.evalFile(scriptFile);
            run = $.global.DAELink_importNewComps;
        }
    }
    if (!run) {
        alert("DAELink: open the DAELink panel from the Window menu, then click Import Linked Comps to create the comp.");
        return;
    }

    run();
})();
]]

    -- Function replacements, not strings: a path containing % would otherwise be read as
    -- a gsub capture reference.
    template = template:gsub("__EXPECTED__", function() return expected end)
    template = template:gsub("__SCRIPT__", function() return script_src end)
    return template
end

function push_new_comps_to_ae()
    local separator = package.config:sub(1,1)
    local is_windows = separator == '\\'

    local data = nil
    if _G.json_path and file_exists(_G.json_path) then
        data = load_json_data(_G.json_path)
    end
    local ae_path = data and data.aeProjectPath or nil
    local ae_script = data and data.aeScriptPath or nil

    -- Nothing has ever connected from AE, so there is no project to import into. DaVinci to
    -- AE is the primary direction and only one AE project can be linked at a time, so a user
    -- who has not connected one almost certainly has not made one yet. Open AE empty and let
    -- them save a project and connect it.
    if not ae_path or ae_path == "" then
        print("DAELink: No linked After Effects project yet. Opening After Effects - save a project there, then connect it from the DAELink panel to create the comp.")
        if not launch_ae_bare(is_windows) then
            alert("The nest was created, but no After Effects project is linked yet.\n\nOpen After Effects, save your project, then connect it from the DAELink panel to create the comp.")
        end
        return
    end

    if not file_exists(ae_path) then
        alert("The nest was created, but the linked After Effects project was not found at:\n" .. ae_path ..
              "\n\nThe file may have been moved or renamed.\n\nOpen your AE project, connect it from the DAELink panel, then click " ..
              _G.CONSTANTS.ICONS.downArrow .. " Import Linked Comps to create the comp.")
        launch_ae_bare(is_windows)
        return
    end

    print("DAELink: Sending the new comp to After Effects...")
    local wait_seconds = nil
    if is_windows then wait_seconds = ae_settle_seconds() end
    run_jsx_in_ae(ae_path, build_import_payload(ae_path, ae_script), is_windows, wait_seconds)
end

-- GUI LAYOUT
_G.ui = fu.UIManager
_G.disp = bmd.UIDispatcher(ui)
local DIVIDER_CSS = "QLabel { background-color: rgba(90, 90, 90, 255); margin: 0; padding: 0; border: 0; }"

local MainWindow = disp:AddWindow({
    ID = "MainWind",
    WindowTitle = "DAELink",
    Geometry = { 950, 400, 330, 210 },

    ui:VGroup{
        ID = "root",
        Spacing = 6,
        Weight = 0,
        FixedSize = { 320, 182 },
        ContentsMargins = { 0, 0, 0, 0 },
        ui:HGroup{
            Weight = 0,
            ui:Button{ ID = "ImportNewComps", Text = _G.CONSTANTS.ICONS.downArrow .. " Import Linked Comps", Weight = 0.5, ToolTip = "Imports compositions pre-linked from AE (via " .. _G.CONSTANTS.ICONS.upArrow .. " Link Active Comp) as new linked nests in this project." },
            ui:Button{ ID = "InsertPlaceholderTimelineAtPlayhead", Text = _G.CONSTANTS.ICONS.downToBarArrow .. " Insert Placeholder", Weight = 0.5, ToolTip = "Drops a placeholder clip at the playhead - the starting block for creating a new AE comp from DaVinci.\nOptionally link (image, video, audio) clips to it (Select All -> R Click -> Link Clips) to bundle them into the new comp." }
        },
        ui:HGroup{
            Weight = 0,
            ui:Button{ ID = "NestLinkedInAEComp", Text = _G.CONSTANTS.ICONS.upArrow .. " Make AE Comp From Placeholder", Weight = 1, ToolTip = "Converts the placeholder under the playhead into a nested timeline, then opens After Effects and creates the linked comp there.\nIf the comp does not arrive, click " .. _G.CONSTANTS.ICONS.downArrow .. " Import Linked Comps in AE." }
        },
        ui:VGroup{
            Weight = 0,
            Spacing = 0,
            ContentsMargins = { 0, 0, 0, 0 },
            ui:Label{ Text = "", Weight = 0, MinimumSize = {0, 1}, MaximumSize = {10000, 1}, StyleSheet = DIVIDER_CSS },
            ui:HGroup{
                Weight = 0,
                ui:Button{ ID = "ImportMarkers", Text = _G.CONSTANTS.ICONS.downTriangle .. " Import Markers", Weight = 0.5, ToolTip = "Pulls markers from the linked AE comp into this nest.\nUse after clicking " .. _G.CONSTANTS.ICONS.upTriangle .. " Export Markers in AE." },
                ui:Button{ ID = "ExportMarkers", Text = _G.CONSTANTS.ICONS.upTriangle .. " Export Markers", Weight = 0.5, ToolTip = "Sends markers from this nest to the linked AE comp.\nApply in AE with " .. _G.CONSTANTS.ICONS.downTriangle .. " Import Markers." }
            }
        },
        ui:HGroup{
            Weight = 0,
            ui:Button{ ID = "RefreshRender", Text = _G.CONSTANTS.ICONS.refresh .. " Refresh Render", Weight = 0.5, ToolTip = "Replaces this nest's video/audio with the latest render from AE." }
        },
        ui:VGroup{
            Weight = 0,
            Spacing = 0,
            ContentsMargins = { 0, 0, 0, 0 },
            ui:Label{ Text = "", Weight = 0, MinimumSize = {0, 1}, MaximumSize = {10000, 1}, StyleSheet = DIVIDER_CSS },
            ui:HGroup{
            Spacing = 5,
            ui:TextEdit{ ID = "Logo", HTML = "<a href='" .. _G.CONSTANTS.WEBSITEURL .. "'><img src='".._G.CONSTANTS.ICONS.logoB64 .."' width='20' height='20' style='vertical-align:middle;'>", ReadOnly = true, FrameStyle = 0, FixedSize = {30, 30}, Events = { AnchorClicked = true }, Weight = 0},
            ui:Label{
                ID = "BrandingName",
                Text = "<span style='color:rgb(200,200,200); font-size:11px;'>DAELink v" .. _G.CONSTANTS.DAELINK_VERSION .. " beta</span>",
                Alignment = { AlignLeft = true, AlignVCenter = true },
                Weight = 0.8
            },
            ui:Button{ ID = "Browse", Text = _G.CONSTANTS.ICONS.openFolder, Weight = 0, MinimumSize = {30, 30}, MaximumSize = {30, 30}, ToolTip = "Re-select this project's daelink folder.\nUse if the folder has moved or you need to re-link." },
            ui:Button{ ID = "OpenAE", Text = "AE", Weight = 0, MinimumSize = {30, 30}, MaximumSize = {30, 30}, ToolTip = "Opens the linked After Effects project.\nIf a DAELink nest is under the playhead, opens that comp directly.\nLaunches AE if no project is linked yet." }
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
    ui_items.ImportMarkers.Enabled = bool
    ui_items.ExportMarkers.Enabled = bool
    ui_items.RefreshRender.Enabled = bool
    ui_items.OpenAE.Enabled = bool
end

-- Auto-initialise from saved path on startup (silent, best-effort)
do
    local restored_path = try_auto_initialise()
    if restored_path then
        ui_items.BrandingName.ToolTip = "Project folder: " .. restored_path
    else
        print("DAELink: no saved project path found. Click 📂 to connect.")
    end
    -- Always enable buttons - connect_to_project() handles the gate on each action
    set_ui_enabled(true)
end

function handle_browse(ev)
    local chosenPath = fu:RequestDir("Choose DAELink Project Media Folder...")
    if not chosenPath or chosenPath == "" then
        return
    end

    connect_to_folder(chosenPath)
end

function handle_import_new_comps(ev)
    if not connect_to_project() then return end
    update_project_fps()
    import_new_comps()
end 

function handle_insert_placeholder(ev)
    if not connect_to_project() then return end
    update_project_fps()
    local success = insert_placeholder_timeline_at_playhead()
    if not success then
        alert("Failed to insert placeholder.\nMake sure you have an active timeline open.")
    end
end

function handle_nest_linked_in_ae_comp(ev)
    if not connect_to_project() then return end
    update_project_fps()

    -- Validate placeholder is under the playhead before showing the dialog
    local placeholder_mpi = get_mpi_by_name(_G.CONSTANTS.PLACEHOLDER_TL_NAME)
    if not placeholder_mpi then
        alert("Error: DAELinkPlaceholder timeline not found in Media Pool.")
        return
    end
    local base_timeline = _G.project:GetCurrentTimeline()
    if not base_timeline then
        alert("Error: No active timeline.")
        return
    end
    local placeholder = base_timeline:GetCurrentVideoItem()
    if not placeholder or placeholder:GetName() ~= placeholder_mpi:GetName() then
        alert("Error: No DAELinkPlaceholder in top active video layer.\n\nBring the playhead over a placeholder clip before using this button.")
        return
    end

    local comp_params = prompt_new_comp_dialog()
    if not comp_params then return end

    -- Returns the new nested timeline on success and nothing on every abort path, so this
    -- is the signal that the entry actually reached daelink.json. Nothing in
    -- replace_linked_with_aecomp writes the JSON after write_compdata_tojson, so by the
    -- time it returns DaVinci is finished with the file and AE can safely open it.
    local nested_timeline = replace_linked_with_aecomp(comp_params.name, comp_params.use_custom, {
        customResolutionWidth  = comp_params.customResolutionWidth,
        customResolutionHeight = comp_params.customResolutionHeight
    })

    if nested_timeline then push_new_comps_to_ae() end
end

function handle_import_markers(ev)
    if not connect_to_project() then return end
    if not import_markers() then alert(get_context_help_message("markers")) end
end

function handle_export_markers(ev)
    if not connect_to_project() then return end
    update_project_fps()
    local count, name = export_markers()
    if not count then
        alert(get_context_help_message("markers"))
    else
        print("DAELink: " .. count .. " markers exported from nest: " .. name)
    end
end

function handle_refresh_render(ev)
    if not connect_to_project() then return end
    update_project_fps()
    local refreshed = refresh_render()
    if refreshed then 
        replace_render_after_refresh() 
    else
        alert(get_context_help_message("refresh"))
    end
    
    confirm_and_delete_unused_renders()
    remove_orphaned_render_mpis()
end

function handle_open_ae(ev)
    if not connect_to_project() then return end
    open_ae_project()
end

function MainWindow.On.MainWind.Close(ev)
    disp:ExitLoop()
end

-- ERROR TRAPPING
-- Every button handler is registered through guarded(). Without it, an unhandled error
-- anywhere below a button surfaces to the user as a bare Lua traceback in the Fusion
-- console, with no name for what failed and no indication that it is worth reporting.
-- That is exactly what the first field bug report looked like, and it cost a round trip
-- to work out which button had even been pressed. pcall names the action, keeps the
-- panel alive instead of leaving the click half-applied, and tells the user where to
-- send it. The alert is itself wrapped, because a UI in a bad enough state to crash a
-- handler can also fail to open a dialog, and the console line must survive that.
function guarded(action_name, handler)
    return function(ev)
        local ok, err = pcall(handler, ev)
        if ok then return end

        print("DAELink: '" .. action_name .. "' failed with an unexpected error.")
        print("DAELink: " .. tostring(err))
        pcall(alert, "Something went wrong during '" .. action_name .. "'.\n\n" ..
            tostring(err) ..
            "\n\nThe Fusion console has the full details. Please report this at nathanstassin.com/daelink.")
    end
end

MainWindow.On.Browse.Clicked = guarded("Connect Project Folder", handle_browse)
MainWindow.On.ImportNewComps.Clicked = guarded("Import Linked Comps", handle_import_new_comps)
MainWindow.On.InsertPlaceholderTimelineAtPlayhead.Clicked = guarded("Insert Placeholder", handle_insert_placeholder)
MainWindow.On.NestLinkedInAEComp.Clicked = guarded("Make AE Comp From Placeholder", handle_nest_linked_in_ae_comp)
MainWindow.On.ImportMarkers.Clicked = guarded("Import Markers", handle_import_markers)
MainWindow.On.ExportMarkers.Clicked = guarded("Export Markers", handle_export_markers)
MainWindow.On.RefreshRender.Clicked = guarded("Refresh Render", handle_refresh_render)
MainWindow.On.OpenAE.Clicked = guarded("Open AE", handle_open_ae)

-- Run
MainWindow:RecalcLayout()
MainWindow:Show()
disp:RunLoop()
MainWindow:Hide()