function DAELink(thisObj) {
    /*
    DAELink  | v0.9 Beta | © 2026 Nathan Stassin

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

    Description:  Links compositions to nests in DaVinci Resolve with a dockable UI panel.
                  1-click renders and shared markers across programs.

    Author:       Nathan Stassin  |  https://www.nathanstassin.com

    Requirements: Adobe After Effects 2025 or later

    Installation: Drag this file into the ScriptUI Panels folder on your computer.
                  Mac: /Applications/After Effects #version#/Scripts/ScriptUI Panels/
                  Windows: \Program Files\Adobe\Adobe After Effects #version#\Support Files\Scripts\ScriptUI Panels\

    Privacy:      All data stored locally. No data is transmitted to external servers.

    Version History:
    - 0.9 Beta - 30/09/2026 - Initial public beta release.
    */
    // GLOBAL VARIABLES
    // Captured while the script is being evaluated, not deferred into a button handler.
    // $.fileName reports the file of the script AE is currently running, so read later from
    // a callback it can name something else entirely - the same trap _G.SCRIPT_DIR works
    // around on the Lua side. Stored in daelink.json as aeScriptPath so the DaVinci side
    // can load this panel when it needs to.
    var SCRIPT_PATH = $.fileName;

    var CONFIG = {
        scriptName: "DAELink",
        version: 0.9,
        schemaVersion: 1,
        websiteurl: "https://nathanstassin.com/daelink",
        projectIDPrefix: "DAELinkProjectID:",
        folderNames: {
            linkedComps: "0_LinkedComps",
            importedMedia: "0_DAELinkImports"
        },
        // Lower case deliberately, and it must stay that way: the Lua side creates these
        // directories on disk and creates them lower case. Reading them back capitalised
        // only worked because macOS and Windows are case-insensitive by default; on a
        // case-sensitive volume (a case-sensitive APFS container, or a Linux/NAS export,
        // both ordinary in post) the JSX side could not find daelink.json in a folder
        // DaVinci had just created.
        // Keep in sync with CONSTANTS.DIRECTORY_NAMES in daelink.lua.
        directoryNames: {
            root: "daelink",
            renders: "renders",
            support: "support"
        },
        fileNames: {
            json: "daelink.json"
        }
    };

    var ICONS = {
        logoData: String.fromCharCode(137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,24,0,0,0,24,8,4,0,0,0,74,126,245,115,0,0,0,32,99,72,82,77,0,0,122,38,0,0,128,132,0,0,250,0,0,0,128,232,0,0,117,48,0,0,234,96,0,0,58,152,0,0,23,112,156,186,81,60,0,0,0,2,98,75,71,68,0,255,135,143,204,191,0,0,0,9,112,72,89,115,0,0,11,19,0,0,11,19,1,0,154,156,24,0,0,0,7,116,73,77,69,7,233,12,22,10,17,28,7,82,255,33,0,0,1,62,73,68,65,84,56,203,141,148,77,78,194,64,0,70,191,10,129,233,78,126,148,107,32,110,185,128,241,10,198,181,137,87,192,22,22,38,46,16,15,128,18,41,120,3,14,66,196,83,232,158,89,62,23,148,58,253,129,58,179,105,210,247,58,111,166,105,165,204,64,8,195,152,103,12,66,37,3,33,234,12,176,88,2,234,37,74,140,63,176,229,131,37,91,194,163,138,131,47,105,209,36,194,30,81,82,120,27,33,90,71,20,7,95,112,134,226,217,102,94,168,164,158,254,135,239,148,252,42,5,49,53,170,84,169,21,134,21,196,116,233,227,227,211,231,162,32,44,23,211,99,68,3,33,78,9,185,204,134,9,195,192,137,169,240,202,125,178,131,59,102,84,156,176,0,35,198,241,185,239,144,115,62,121,74,132,71,54,116,226,235,38,17,91,38,39,242,228,201,61,53,116,163,107,25,213,117,165,91,73,158,115,199,147,39,12,1,150,40,94,163,194,20,248,97,197,138,111,96,70,53,78,122,199,50,196,223,109,58,196,18,197,187,232,178,97,63,190,232,57,248,8,67,114,172,33,150,121,162,76,89,179,230,45,143,187,111,34,76,133,117,232,164,98,70,169,175,131,124,216,126,22,225,25,101,238,40,135,240,3,97,199,240,156,210,164,81,130,103,148,5,81,41,238,40,1,22,203,240,255,255,13,195,132,23,252,34,252,23,246,181,14,208,87,176,67,142,0,0,0,37,116,69,88,116,100,97,116,101,58,99,114,101,97,116,101,0,50,48,50,53,45,49,50,45,50,49,84,49,51,58,50,48,58,48,52,43,48,48,58,48,48,160,116,189,185,0,0,0,37,116,69,88,116,100,97,116,101,58,109,111,100,105,102,121,0,50,48,50,53,45,49,50,45,50,49,84,49,51,58,49,57,58,53,48,43,48,48,58,48,48,8,113,98,185,0,0,0,40,116,69,88,116,100,97,116,101,58,116,105,109,101,115,116,97,109,112,0,50,48,50,53,45,49,50,45,50,50,84,49,48,58,49,55,58,50,56,43,48,48,58,48,48,236,133,236,151,0,0,0,0,73,69,78,68,174,66,96,130),
        link: "\uD83D\uDD17",
        openFolder: "\uD83D\uDCC2\uFE0E",
        closedFolder: "\uD83D\uDCC1\uFE0E",
        upTriangle: "\u25B2",
        downTriangle: "\u25BC",
        upArrow: "\u2B06",
        downRightArrow: "\u21B3",
        downArrow: "\u2B07",
        plus: "\u271A", 
        play: "\u25B6", 
        square: "\u2610",
        gear: "\u2699\uFE0E"
    };

    var STYLES = {
        buttonSize: [22, 22],
        spacing: {
            mainPanel: 12,
            horizontalGroup: 8,
            buttonGroup: 5,
            footerGroup: 8,
            brandingColumn: 2
        },
        margins: {
            mainPanel: 16,
            panel: 12,
            buttonGroup: 4,
            footer: [0, 0, 0, 4]
        },
        sizes: {
            logo: [32, 32],
            pathTextCharacters: 40
        },
        customLayouts: {
            footer: {
                orientation: "row",
                alignment: ["fill", "bottom"],
                alignChildren: ["left", "center"]
            }
        }
    };

    var JSONfilePath;
    var jsonFile;
    var linkedCompsFolder;
    var importedMediaFolder;
    var projectMediaPath, templateDropdown;
    var activeComp = app.project.activeItem;
    // Comp names already warned about in this session, so the render-name notice fires once
    var renderNameNotices = {};
    // Keyed by folder / file path so the write-access check and the JSON backup happen once
    // per session rather than on every button press. writeAccessState holds "ok" or "failed":
    // "ok" stops further probing, "failed" keeps probing so recovery is noticed, and only the
    // transition into "failed" alerts.
    var writeAccessState = {};
    var jsonBackupDone = {};

    (function(passedObj) {
        var myScriptPal = buildUI(passedObj);
        // The regression suite (tools/test, dev-only) sets DAELINK_TEST before loading this
        // file: the panel is built but never shown, and handed to the suite, which clicks its
        // buttons directly. Unset in normal use, so this changes nothing for anyone else.
        if ($.global.DAELINK_TEST) {
            $.global.DAELINK_TEST.panel = myScriptPal;
            return;
        }
        if (myScriptPal instanceof Window) {
            myScriptPal.center();
            myScriptPal.show();
        } else {
            myScriptPal.layout.layout(true);
        }
    })(thisObj);

    function buildUI(thisObj) {
        defineJSON();

        var myPanel = (thisObj instanceof Panel)
            ? thisObj
            : new Window("palette", CONFIG.scriptName, undefined, { resizeable: true });
        

        myPanel.orientation = "column";
        myPanel.alignChildren = ["fill", "top"];
        myPanel.margins = STYLES.margins.mainPanel;
        myPanel.spacing = STYLES.spacing.mainPanel;

        // PANEL 1 - Link Compositions
        var linkCompositionsPanel = myPanel.add("panel", undefined, "Link Compositions");
        setPanelMargins(linkCompositionsPanel, STYLES.margins.panel);
        var hGroup1 = createButtonGroup(linkCompositionsPanel);
        var importNewCompsBtn = hGroup1.add("button", undefined, ICONS.downArrow + " Import Linked Comps");
        importNewCompsBtn.helpTip = "Creates new AE comps from nests already linked in DaVinci.\n" + ICONS.upArrow + " Make AE Comp From Placeholder in DaVinci normally does this for you - use this button if a comp did not arrive.";
        var linkActiveCompBtn = hGroup1.add("button", undefined, ICONS.upArrow + " Link Active Comp");
        linkActiveCompBtn.helpTip = "Links active comp to a new DaVinci Nest.\nClick " + ICONS.downArrow + " Import Linked Comps in DaVinci to complete the link.";

        // PANEL 2 - Linked Active Comp
        var activeCompPanel = myPanel.add("panel", undefined, "Linked Active Comp");
        setPanelMargins(activeCompPanel, STYLES.margins.panel);

        // Marker buttons
        var hGroup2 = createButtonGroup(activeCompPanel);
        var importMarkersBtn = hGroup2.add("button", undefined, ICONS.downTriangle + " Import Markers");
        importMarkersBtn.helpTip = "Pulls markers from the linked DaVinci nest onto the active comp as comp markers.\nUse after clicking " + ICONS.upTriangle + " Export Markers in DaVinci.";
        var exportMarkersBtn = hGroup2.add("button", undefined, ICONS.upTriangle + " Export Markers");
        exportMarkersBtn.helpTip = "Sends the active comp's markers to the linked DaVinci nest.\nApply in DaVinci with " + ICONS.downTriangle + " Import Markers.";

        // Template + Add to Queue
        var hGroup3 = createButtonGroup(activeCompPanel);
        templateDropdown = hGroup3.add("dropdownlist", undefined, []);
        templateDropdown.helpTip = "Output module template to use when adding this comp to the render queue.";

        // Render buttons
        var hGroup4 = createButtonGroup(activeCompPanel);
        var addToQBtn = hGroup4.add("button", undefined, ICONS.plus + " Queue");
        addToQBtn.helpTip = "Adds the active comp to the AE render queue with the selected output template.";
        var renderBtn = hGroup4.add("button", undefined, ICONS.play + " Render");
        renderBtn.helpTip = "Adds the active comp to the render queue with the selected template and immediately starts rendering the queue.\nClick Refresh Render in DaVinci afterward to pick up the new file.";

        // Branding - in footer group
        var footerGroup = myPanel.add("group");
        footerGroup.orientation = STYLES.customLayouts.footer.orientation;
        footerGroup.alignment = STYLES.customLayouts.footer.alignment;
        footerGroup.alignChildren = STYLES.customLayouts.footer.alignChildren;
        footerGroup.spacing = STYLES.spacing.footerGroup;
        footerGroup.margins = STYLES.margins.footer; 
        var logoImage = footerGroup.add("image", undefined, ICONS.logoData);
        logoImage.preferredSize = STYLES.sizes.logo;
        logoImage.alignment = ["left", "center"];
        logoImage.helpTip = "Open DAELink documentation";
        // ScriptUI "image" elements never fire .onClick. addEventListener("click", ...) does,
        // and stays scoped to this control rather than bubbling to the rest of the panel.
        logoImage.addEventListener("click", function () {
            try {
                if ($.os.indexOf("Windows") !== -1) {
                    system.callSystem("cmd /c start " + CONFIG.websiteurl);
                } else {
                    system.callSystem("open " + CONFIG.websiteurl);
                }
            } catch (error) {
                alert("Could not open URL.\nPlease visit: " + CONFIG.websiteurl);
            }
        });
        var brandingColumn = footerGroup.add("group");
        brandingColumn.orientation = "column";
        brandingColumn.alignChildren = ["left", "center"];
        brandingColumn.spacing = STYLES.spacing.brandingColumn;
        brandingColumn.margins = [0, 0, 0, 0];
        brandingColumn.add("statictext", undefined, CONFIG.scriptName + " v" + CONFIG.version + " beta");
        footerGroup.add("statictext", undefined, "").alignment = ["fill", "fill"];
        var buttonGroup = footerGroup.add("group");
        buttonGroup.alignment = ["right", "bottom"];
        buttonGroup.spacing = STYLES.spacing.buttonGroup;
        buttonGroup.margins = STYLES.margins.buttonGroup;
        var browseBtn = createSquareButton(buttonGroup, ICONS.openFolder, "Change project folder");

        // All buttons start enabled - connection is resolved on first use
        var uiElements = [importNewCompsBtn, linkActiveCompBtn, renderBtn, addToQBtn, importMarkersBtn, exportMarkersBtn, templateDropdown]; 
        for (var i = 0; i < uiElements.length; i++) {
            uiElements[i].alignment = ["fill", "center"];
        }
        myPanel.onResizing = myPanel.onResize = function() { this.layout.resize(); }

        // CONNECTION LOGIC
        // Called at the top of every button handler.
        // Returns true if we have a valid active connection, false otherwise.
        function connectToProject() {
            // If we appear to be connected, validate that the AE project hasn't changed
            // by checking the 0_LinkedComps folder comment against the JSON's projectid.
            // On mismatch/missing: null state and fall through to reconnect logic.
            if (jsonFile && jsonFile.exists) {
                var data = loadJSONData();
                var linkedMatches = findFoldersByName(CONFIG.folderNames.linkedComps, null);

                if (linkedMatches.length > 1) {
                    alert("Multiple folders named '" + CONFIG.folderNames.linkedComps + "' found. Please resolve before continuing.");
                    return false;
                }

                if (linkedMatches.length === 1 && linkedMatches[0].comment === CONFIG.projectIDPrefix + data.projectid) {
                    // Re-resolve the folder references even though the link is intact. They
                    // are held across button presses, so after opening another .aep linked to
                    // the same DaVinci project (a version-up, say) they still point into the
                    // closed project and the next parentFolder assignment throws "Object is invalid".
                    if (!findOrCreateDAELinkFolders()) return false;
                    return ensureAEProjectPathMatches();
                }

                jsonFile = null;
                projectMediaPath = null;
            }

            // Read the DaVinci projectid from the 0_LinkedComps folder comment -
            // this is the stable identity for this AE project's link
            var projectID = getLinkedProjectID();

            if (projectID) {
                // This AE project has been linked - look up its saved folder path
                var savedPath = loadProjectPath(projectID);

                if (savedPath) {
                    var testJson = new File(savedPath + "/" + CONFIG.directoryNames.root + "/" + CONFIG.directoryNames.support + "/" + CONFIG.fileNames.json);
                    if (testJson.exists) {
                        // Path still valid - connect silently
                        JSONfilePath = savedPath + "/" + CONFIG.directoryNames.root + "/" + CONFIG.directoryNames.support + "/" + CONFIG.fileNames.json;
                        jsonFile = new File(JSONfilePath);
                        if (!versionCheck()) { jsonFile = null; return false; }
                        if (findOrCreateDAELinkFolders()) {
                            projectMediaPath = savedPath;
                            if (templateDropdown.items.length <= 1) { loadTemplates(); templateDropdown.selection = 0; }
                            return ensureAEProjectPathMatches();
                        }
                        jsonFile = null;
                        return false;
                    }
                    // Linked, path saved, but folder has moved - ask to relocate
                    alert("DAELink project folder not found at:\n" + savedPath + "\n\nPlease navigate to its new location.");
                }
                // Linked but no path in settings yet - fall through to folder picker
            }
            // No folder comment - first time connecting this AE project

            var folder = Folder.selectDialog("Open this project's daelink folder");
            if (!folder) return false;
            return connectToFolder(folder);
        }

        function connectToFolder(folder) {
            var normalizedPath = folder.fsName.replace(/\\/g, "/");
            var lowerPath = normalizedPath.toLowerCase();

            // Accept either the media folder or the daelink folder inside it
            if (lowerPath.match(/\/daelink\/?$/i)) {
                var lastSlash = lowerPath.lastIndexOf("/daelink");
                if (lastSlash !== -1) normalizedPath = normalizedPath.substring(0, lastSlash);
            }

            var daelinkFolder = new Folder(normalizedPath + "/" + CONFIG.directoryNames.root);
            if (!daelinkFolder.exists) {
                alert("No daelink folder found at that location.");
                return false;
            }

            JSONfilePath = normalizedPath + "/" + CONFIG.directoryNames.root + "/" + CONFIG.directoryNames.support + "/" + CONFIG.fileNames.json;
            jsonFile = new File(JSONfilePath);

            if (!versionCheck()) { jsonFile = null; return false; }

            // findOrCreateDAELinkFolders writes the DaVinci projectid into the folder comment
            // (or validates it if already set). After it runs, getLinkedProjectID() is reliable.
            if (findOrCreateDAELinkFolders()) {
                projectMediaPath = normalizedPath;
                var projectID = getLinkedProjectID();
                if (projectID) saveProjectPath(projectID, projectMediaPath);
                if (templateDropdown.items.length <= 1) { loadTemplates(); templateDropdown.selection = 0; }
                return ensureAEProjectPathMatches();
            }
            jsonFile = null;
            return false;
        }

        // BUTTON HANDLERS
        browseBtn.onClick = function () {
            // Force a fresh folder selection regardless of current state
            jsonFile = null;
            projectMediaPath = null;
            var folder = Folder.selectDialog("Open this project's daelink folder");
            if (!folder) return;
            connectToFolder(folder);
        };

        importNewCompsBtn.onClick = function () { 
            if (!connectToProject()) return;
            importNewComps();
        };

        linkActiveCompBtn.onClick = function () {
            if (!connectToProject()) return;
            activeComp = app.project.activeItem;
            if (activeComp && activeComp instanceof CompItem) {
                linkWithDavinci();
            }
        };

        renderBtn.onClick = function () {
            if (!connectToProject()) return;
            if (refreshComp() && addToQ(templateDropdown)) app.project.renderQueue.render();
        };

        addToQBtn.onClick = function () {
            if (!connectToProject()) return;
            if (refreshComp()) addToQ(templateDropdown);
        };

        importMarkersBtn.onClick = function () {
            if (!connectToProject()) return;
            if (refreshComp()) importMarkers();
        };

        exportMarkersBtn.onClick = function () {
            if (!connectToProject()) return;
            if (refreshComp()) exportMarkers();
        };

        templateDropdown.onActivate = function () {
            if (!connectToProject()) return;
            // Set selection alongside the reload, matching the two connect paths above.
            // loadTemplates() begins with removeAll(), so leaving selection unset here would
            // leave the dropdown populated but with nothing selected.
            if (templateDropdown.items.length <= 1) { loadTemplates(); templateDropdown.selection = 0; }
        };

        // REMOTE ENTRY POINT
        // The DaVinci side finishes "Make AE Comp From Placeholder" by running a small
        // ExtendScript inside AE (see push_new_comps_to_ae in daelink.lua) that calls this.
        // Registered here rather than at file scope because connectToProject lives in this
        // closure. daelink.jsx declares no #targetengine, so the panel runs in AE's main
        // engine - the same one DoScriptFile and AfterFX.com -r evaluate into - and this
        // stays reachable for the rest of the AE session.
        // Namespaced because the main engine is shared with every other script AE runs.
        $.global.DAELink_importNewComps = function () {
            if (!connectToProject()) return false;
            return importNewComps(true);
        };

        return myPanel;
    }

    // SETTINGS PERSISTENCE
    // app.settings holds one entry: SETTINGS_DICT_KEY → JSON string of
    // { "davinci_project_uuid": "/folder/path", ... }
    // The key for each project is the DaVinci projectid, read from the
    // 0_LinkedComps folder comment - the same anchor already used by the script.
    var SETTINGS_SECTION = CONFIG.scriptName;
    var SETTINGS_DICT_KEY = "projectFolderMap";

    function loadProjectSettings() {
        try {
            if (app.settings.haveSetting(SETTINGS_SECTION, SETTINGS_DICT_KEY)) {
                return JSON.parse(app.settings.getSetting(SETTINGS_SECTION, SETTINGS_DICT_KEY));
            }
        } catch(e) {}
        return {};
    }

    function saveProjectSettings(dict) {
        try {
            app.settings.saveSetting(SETTINGS_SECTION, SETTINGS_DICT_KEY, JSON.stringify(dict));
        } catch(e) {}
    }

    function getLinkedProjectID() {
        // Read the DaVinci projectid from the 0_LinkedComps folder comment.
        // Returns the ID string, or null if no linked folder exists in this AE project.
        var prefix = CONFIG.projectIDPrefix;
        var matches = findFoldersByName(CONFIG.folderNames.linkedComps, null);
        if (matches.length === 1) {
            var comment = matches[0].comment || "";
            if (comment.indexOf(prefix) === 0) {
                return comment.substring(prefix.length);
            }
        }
        return null;
    }

    function saveProjectPath(projectID, folderPath) {
        var dict = loadProjectSettings();
        dict[projectID] = folderPath;
        saveProjectSettings(dict);
    }

    function loadProjectPath(projectID) {
        var dict = loadProjectSettings();
        return dict[projectID] || null;
    }

    // LIVE-LINK VALIDATION
    // daelink.json carries `aeProjectPath` - the fsName of the single AE project
    // currently acting as the live link for this DaVinci project. Called at the end of
    // every successful connection path. On divergence the user must confirm the takeover
    // before proceeding; cancelling aborts the current action without clearing state.
    // Also the one place `aeScriptPath` is written, for the same reason: this is the funnel.
    function ensureAEProjectPathMatches() {
        if (!app.project.file) {
            alert("Please save your After Effects project before connecting to DAELink.\n\nDAELink needs to know which project file is linked to this DaVinci project.");
            return false;
        }

        var currentPath = app.project.file.fsName.replace(/\\/g, "/");
        var data = loadJSONData();
        if (!data) return false;

        // Every successful connection funnels through here, so this is the one place that
        // catches disabled script permissions before the user starts working
        checkScriptFileAccess();

        var storedPath = data.aeProjectPath || "";
        // Recorded alongside the project path so the DaVinci side can load this panel when
        // the remote entry point is missing. Refreshed whenever it moves, since the script
        // can be reinstalled into a different AE version's folder between sessions.
        var scriptPath = SCRIPT_PATH ? SCRIPT_PATH.replace(/\\/g, "/") : "";

        if (storedPath === currentPath) {
            if (scriptPath !== "" && data.aeScriptPath !== scriptPath) {
                data.aeScriptPath = scriptPath;
                saveJSONData(data);
            }
            return true;
        }

        if (storedPath === "") {
            data.aeProjectPath = currentPath;
            if (scriptPath !== "") data.aeScriptPath = scriptPath;
            saveJSONData(data);
            return true;
        }

        var proceed = confirm(
            "This DaVinci project is currently linked to a different AE project file:\n\n" +
            storedPath + "\n\n" +
            "Continuing will make this file the new live link.\n\n" +
            "Any new changes must be made from this project file. Old project files should be saved for archival purposes - keep one live project file at a time.\n\n" +
            "Continue?"
        );

        if (!proceed) return false;

        data.aeProjectPath = currentPath;
        if (scriptPath !== "") data.aeScriptPath = scriptPath;
        saveJSONData(data);
        return true;
    }

    // FILE ACCESS SAFETY

    // AE's Preferences > Scripting & Expressions > "Allow Scripts to Write Files and Access
    // Network" silently disables script file writes, and an AE preferences reset turns it back
    // off. Probe with a throwaway file rather than reading the preference: the probe is version
    // independent and also catches a read-only volume or a folder permissions problem, neither
    // of which the preference can report. open('w') alone is NOT a valid test - it succeeds and
    // truncates the target, and only the subsequent write() fails.
    // When permissions are off the probe file cannot be deleted either (removal is itself a write),
    // so a failed probe leaves daelink_writetest.tmp behind. That is unavoidable, but the next
    // successful probe reuses the same name and cleans it up, which is why checkScriptFileAccess
    // keeps probing while in the failed state instead of caching the failure.
    function canWriteToFolder(folder) {
        var probe = new File(folder.fsName + "/daelink_writetest.tmp");
        var token = "daelink";
        var ok = false;
        try {
            if (probe.open('w')) {
                var written = probe.write(token);
                probe.close();
                if (written && probe.open('r')) {
                    ok = (probe.read() === token);
                    probe.close();
                }
            }
        } catch (e) {
            ok = false;
        }
        // Always attempted, including on every failure path above
        try { probe.remove(); } catch (e2) {}
        return ok;
    }

    // Reports the problem up front instead of letting every save fail with a generic message.
    // Deliberately does not block: reading still works, and the atomic write in saveJSONData
    // means a failed save leaves the original file intact.
    function checkScriptFileAccess() {
        if (!jsonFile) return true;
        var folder = jsonFile.parent;
        if (!folder || !folder.exists) return true;

        // Proven writable already this session, so do not touch the disk again
        if (writeAccessState[folder.fsName] === "ok") return true;

        if (canWriteToFolder(folder)) {
            writeAccessState[folder.fsName] = "ok";
            return true;
        }

        // Still failing, and the user has already been told once this session
        if (writeAccessState[folder.fsName] === "failed") return false;

        writeAccessState[folder.fsName] = "failed";
        alert("DAELink cannot write to the project folder:\n\n" + folder.fsName + "\n\n" +
              "In After Effects, turn on Preferences > Scripting & Expressions > 'Allow Scripts to Write Files and Access Network'. Resetting AE preferences switches this off again.\n\n" +
              "If that setting is already on, check that the folder and its drive are writable.\n\n" +
              "Reading still works. Anything that saves (linking, render paths, markers) will fail until this is fixed.");
        return false;
    }

    // Appended to save failures: disabled script permissions are by far the most common cause
    function writeFailureHint() {
        return "\n\nMost often this means After Effects script permissions are off. Check Preferences > Scripting & Expressions > 'Allow Scripts to Write Files and Access Network'.";
    }

    function backupHint() {
        if (!jsonFile) return "";
        var backup = new File(jsonFile.fsName + ".bak");
        if (!backup.exists) return "";
        return "\n\nA backup taken earlier this session is available at:\n" + backup.fsName;
    }

    // First successful load of a given JSON file in a session leaves a known-parseable copy
    // beside it. Written from the text that just parsed, so the backup can never be the corrupt
    // state we are protecting against.
    function rotateJSONBackup(sourceFile, parsedText) {
        if (!sourceFile || jsonBackupDone[sourceFile.fsName]) return;
        // Flag first: a failing backup must never be retried on every load
        jsonBackupDone[sourceFile.fsName] = true;

        var backup = new File(sourceFile.fsName + ".bak");
        try {
            try { backup.encoding = "UTF-8"; } catch (e) {}
            backup.lineFeed = ($.os && $.os.indexOf("Windows") !== -1) ? "Windows" : "Unix";
            if (backup.open('w')) {
                backup.write(parsedText);
                backup.close();
            }
        } catch (e2) {}
    }

    // UI HELPERS
    function createSquareButton(parent, text, tooltip) {
        var button = parent.add("button", undefined, text);
        button.preferredSize = STYLES.buttonSize;
        if (tooltip) button.helpTip = tooltip;
        return button;
    }

    function createButtonGroup(parent, spacing) {
        var group = parent.add("group");
        group.orientation = "row";
        group.spacing = spacing || STYLES.spacing.horizontalGroup;
        return group;
    }


    function setPanelMargins(panel, amount) {
        panel.margins = [amount, amount, amount, amount];
        panel.alignChildren = ["fill", "fill"];
    }

    function confirmPropertyChange(propertyName, davinciValue, aeValue, unit) {
        unit = unit || ""; // Optional unit like "FPS"
        return confirm(
            "Change active comp " + propertyName + " to match DaVinci " + propertyName + "?\n" +
            "DaVinci " + propertyName + ": " + davinciValue + unit + "\n" +
            "Active comp " + propertyName + ": " + aeValue + unit
        );
    }

    // IMPORT HELPERS
    function importAndAddLayers(comp, compData, fps) {
        if (!compData.layers || compData.layers.length === 0) return;
        
        // Separate audio and video layers
        var audioLayers = [];
        var videoLayers = [];
        
        for (var i = 0; i < compData.layers.length; i++) {
            var layer = compData.layers[i];
            
            // Use mediaType property from JSON
            if (layer.mediaType === "audio") {
                audioLayers.push(layer);
            } else {
                videoLayers.push(layer);
            }
        }
        
        // Sort each group: first by trackIndex, then by recordFrame (descending)
        var sortFunction = function(a, b) {
            if (a.trackIndex === b.trackIndex) {
                return b.recordFrame - a.recordFrame;
            }
            return a.trackIndex - b.trackIndex;
        };
        
        audioLayers.sort(sortFunction);
        videoLayers.sort(sortFunction);
        
        // Combine: video first (will appear at top in AE), then audio (will appear at bottom)
        var sortedLayers = videoLayers.concat(audioLayers);

        for (var i = 0; i < sortedLayers.length; i++) {
            var layerData = sortedLayers[i];
            var filePath = layerData.filePath;
            var file = new File(filePath);

            if (!file.exists) {
                alert("File not found: " + filePath);
                continue;
            }

            // Check if the footage is already imported to prevent re-importing
            var importedItem = null;
            for (var j = 1; j <= app.project.numItems; j++) {
                var item = app.project.item(j);
                if (item instanceof FootageItem && item.file && item.file.fsName === file.fsName) {
                    importedItem = item;
                    break;
                }
            }

            if (!importedItem) {
                var importOpts = new ImportOptions(file);
                if (importOpts.canImportAs(ImportAsType.FOOTAGE)) {
                    importOpts.importAs = ImportAsType.FOOTAGE;
                    importedItem = app.project.importFile(importOpts);
                    importedItem.parentFolder = importedMediaFolder; 
                }
                else {
                    alert("Could not import file " + filePath + " as footage.");
                    continue;
                }
            }

            // Handle non-square pixel aspect ratio (legacy SD/anamorphic footage)
            if (layerData.pixelAspect !== "N/A") {
                if (layerData.pixelAspect !== 1) {
                    if (confirm("Legacy pixel aspect ratio " + layerData.pixelAspect + " detected for layer '" + layerData.layerName + "'.\n\nChange to square?")) {
                        importedItem.pixelAspect = 1;
                    } else {
                        alert("Pixel aspect ratio unchanged - sizing may appear incorrect.");
                        importedItem.pixelAspect = layerData.pixelAspect;
                    }
                }
                else {
                    importedItem.pixelAspect = layerData.pixelAspect;
                }
            }

            var currentLayer = comp.layers.add(importedItem);
            
            // Move audio layers to bottom (highest index)
            if (layerData.mediaType === "audio") {
                currentLayer.moveToEnd();
            }

            // Layer timing and trimming 
            var layerStartTime = layerData.recordFrame / fps;
            var sourceInPoint = layerData.sourceStartFrame / fps;
            var clipDuration = layerData.duration / fps;
            currentLayer.startTime = layerStartTime - sourceInPoint;
            currentLayer.inPoint = layerStartTime;
            currentLayer.outPoint = layerStartTime + clipDuration;

            // Only set visual properties for video layers
            if (layerData.mediaType !== "audio") {
                applyDaVinciLook(currentLayer, layerData, importedItem, comp, compData, fps);
                applyDaVinciBlendMode(currentLayer, layerData.compositeMode);
            }
        }
    }

    // A missing or unreadable value (JSON from before the field existed, "N/A") reads as fallback.
    function numberOr(value, fallback) {
        var n = Number(value);
        return (value === null || value === undefined || value === "" || isNaN(n)) ? fallback : n;
    }

    // Everything below turns DaVinci's Inspector into AE layer properties, masks and effects.
    // davinciState() reads one frame's Inspector values (keyframed or static), aeLook() converts
    // them, and applyDaVinciLook() sets the result once, or at every frame when the clip has
    // keyframes, so animated and static values go through exactly the same conversion.
    // Every conversion was measured on Resolve 21.1.1 and is checked by rendering the same
    // frame in both apps and comparing the pixels.

    var LOOK_FIELDS = {
        zoomX: 1, zoomY: 1, pan: 0, tilt: 0, rotationAngle: 0, anchorPointX: 0, anchorPointY: 0,
        opacity: 100, cropLeft: 0, cropRight: 0, cropTop: 0, cropBottom: 0, cropSoftness: 0,
        pitch: 0, yaw: 0, distortion: 0
    };

    // Inspector values at `frame` (counted from the layer's first frame). Keyframes come from
    // DaVinci's OTIO export, which carries no easing, so they interpolate linearly and hold
    // before the first and after the last.
    function davinciState(layerData, frame) {
        var st = {};
        var keys = layerData.keyframes || {};
        for (var field in LOOK_FIELDS) {
            if (!LOOK_FIELDS.hasOwnProperty(field)) continue;
            var k = keys[field];
            if (k && k.length) {
                if (frame <= k[0][0]) st[field] = k[0][1];
                else if (frame >= k[k.length - 1][0]) st[field] = k[k.length - 1][1];
                else {
                    for (var i = 1; i < k.length; i++) {
                        if (frame <= k[i][0]) {
                            var f = (frame - k[i - 1][0]) / (k[i][0] - k[i - 1][0]);
                            st[field] = k[i - 1][1] + (k[i][1] - k[i - 1][1]) * f;
                            break;
                        }
                    }
                }
            } else {
                st[field] = numberOr(layerData[field], LOOK_FIELDS[field]);
            }
        }
        return st;
    }

    // One frame's AE values. ctx: footage, fit [x, y], flip signs, comp centre.
    //
    // Scale: DaVinci fits footage to the timeline frame before Zoom (Input Scaling); AE places
    // footage at native size, so the fit factor multiplies in. Flip is a negative scale.
    // Rotation: opposite directions. Position: AE's origin is top-left, DaVinci's the centre.
    // Anchor: DaVinci's is the pivot for zoom and rotation, in timeline pixels from the frame
    // centre (Y up), and does not move the image by itself; AE's is in source pixels and lands
    // on the position, so it is converted through the fit and the position moves with it.
    // DaVinci flips about the image's own centre, so the anchor offset mirrors on a flipped axis.
    //
    // Crop: a rectangle mask in source pixels (DaVinci crops in timeline pixels of the fitted
    // image, from the image's own edges, before flip, which a mask under AE's negative-scale
    // flip reproduces). Crop Softness (-100..100) becomes the mask's feather and expansion:
    // DaVinci's edge is 2.675 * |s| - 0.75 wide (10-90%), centred 2.72 * s - 0.8 outside the
    // crop line for s > 0 and 2.08 * |s| - 2.2 inside it for s < 0; AE's feather is centred on
    // the mask edge with a 10-90% width of 0.975 * feather, and expansion moves the edge exactly.
    //
    // Pitch/Yaw (-1.5..1.5): a perspective about the image centre, in coordinates normalised to
    // -1..1 across the image (v down): (u, v) -> (u, v) / (1 - pitch * v + yaw * u), after crop,
    // flip and distortion and before zoom and rotation. Corner Pin reproduces it exactly from
    // the four corners. DaVinci flips first and AE last, so a flipped axis negates its term.
    function aeLook(st, ctx) {
        var w = ctx.footage.width, h = ctx.footage.height;
        var fx = ctx.fit[0] || 1, fy = ctx.fit[1] || 1;
        var ax = st.anchorPointX, ay = -st.anchorPointY;
        var look = {
            scale: [st.zoomX * 100 * fx * ctx.flipX, st.zoomY * 100 * fy * ctx.flipY],
            rotation: -st.rotationAngle,
            anchor: [0.5 * w + ctx.flipX * ax / fx, 0.5 * h + ctx.flipY * ay / fy],
            position: [st.pan + ctx.centre[0] + ax, -st.tilt + ctx.centre[1] + ay],
            opacity: st.opacity
        };

        var l = st.cropLeft / fx, r = st.cropRight / fx, t = st.cropTop / fy, b = st.cropBottom / fy;
        var soft = st.cropSoftness;
        var shape = new Shape();
        shape.vertices = [[l, t], [w - r, t], [w - r, h - b], [l, h - b]];
        shape.closed = true;
        var width = soft ? Math.max(0, 2.675 * Math.abs(soft) - 0.75) : 0;
        // No nested ternary here: ExtendScript read "s > 0 ? x : s < 0 ? y : 0" as
        // "(s > 0 ? x : s) < 0 ? y : 0", which silently zeroed every positive softness.
        var shift = 0;
        if (soft > 0) shift = Math.max(0, 2.72 * soft - 0.8);
        else if (soft < 0) shift = -Math.max(0, 2.08 * -soft - 2.2);
        look.crop = { needed: l > 0 || r > 0 || t > 0 || b > 0 || soft !== 0, shape: shape,
                      feather: [width / 0.975 / fx, width / 0.975 / fy], offset: shift / ((fx + fy) / 2) };

        look.distortion = st.distortion ? distortionParams(st.distortion) : { fov: 0, scale: 1, reverse: false };
        look.distortion.needed = st.distortion !== 0;

        var p = st.pitch * ctx.flipY, y = st.yaw * ctx.flipX;
        function corner(u, v) {
            var k = 1 - p * v + y * u;
            return [w / 2 + (u * w / 2) / k, h / 2 + (v * h / 2) / k];
        }
        look.pin = { needed: p !== 0 || y !== 0, corners: [corner(-1, -1), corner(1, -1), corner(-1, 1), corner(1, 1)] };
        return look;
    }

    // Sets property `prop` from `values` (one per time in `times`), or once when not animated.
    function setLook(prop, times, values) {
        if (times) prop.setValuesAtTimes(times, values); else prop.setValue(values[0]);
    }

    function applyDaVinciLook(layer, layerData, footage, comp, compData, fps) {
        var ctx = {
            footage: footage,
            fit: inputScaleFactors(layerData.inputScaling, footage, comp),
            flipX: layerData.flipX === "true" ? -1 : 1,
            flipY: layerData.flipY === "true" ? -1 : 1,
            centre: [0.5 * compData.resolutionWidth, 0.5 * compData.resolutionHeight]
        };
        var animated = false;
        for (var kf in (layerData.keyframes || {})) { if (layerData.keyframes.hasOwnProperty(kf)) animated = true; }

        var looks = [], times = null;
        if (animated) {
            // Baked at every frame: several conversions (the perspective corners, the
            // distortion table) are not linear, so keys only at DaVinci's keyframes would
            // drift between them.
            times = [];
            var frames = Math.max(1, Math.round(numberOr(layerData.duration, 1)));
            for (var f = 0; f < frames; f++) {
                looks.push(aeLook(davinciState(layerData, f), ctx));
                times.push((numberOr(layerData.recordFrame, 0) + f) / fps);
            }
        } else {
            looks.push(aeLook(davinciState(layerData, 0), ctx));
        }
        function each(get) { var out = []; for (var i = 0; i < looks.length; i++) out.push(get(looks[i])); return out; }
        function anyNeeds(part) { for (var i = 0; i < looks.length; i++) if (looks[i][part].needed) return true; return false; }

        setLook(layer.scale, times, each(function (o) { return o.scale; }));
        setLook(layer.rotation, times, each(function (o) { return o.rotation; }));
        setLook(layer.anchorPoint, times, each(function (o) { return o.anchor; }));
        setLook(layer.position, times, each(function (o) { return o.position; }));
        setLook(layer.opacity, times, each(function (o) { return o.opacity; }));

        if (anyNeeds("crop")) {
            var mask = layer.property("ADBE Mask Parade").addProperty("ADBE Mask Atom");
            mask.name = "DaVinci Crop";
            mask.maskMode = MaskMode.ADD;
            setLook(mask.property("ADBE Mask Shape"), times, each(function (o) { return o.crop.shape; }));
            setLook(mask.property("ADBE Mask Feather"), times, each(function (o) { return o.crop.feather; }));
            setLook(mask.property("ADBE Mask Offset"), times, each(function (o) { return o.crop.offset; }));
        }
        // Effect order mirrors DaVinci's: lens distortion, then pitch/yaw.
        if (anyNeeds("distortion")) {
            var first = looks[0].distortion;
            var anyReverse = false;
            for (var di = 0; di < looks.length; di++) if (looks[di].distortion.reverse) anyReverse = true;
            addDistortionEffects(layer, footage, first.fov, first.scale, anyReverse);
            var fxp = layer.property("ADBE Effect Parade");
            var oc = fxp.property("DaVinci Distortion");
            var tr = fxp.property("DaVinci Distortion Scale");
            setLook(oc.property("ADBE Optics Compensation-0001"), times, each(function (o) { return o.distortion.fov; }));
            setLook(oc.property("ADBE Optics Compensation-0002"), times, each(function (o) { return o.distortion.reverse ? 1 : 0; }));
            setLook(tr.property("ADBE Geometry2-0003"), times, each(function (o) { return o.distortion.scale * 100; }));
        }
        if (anyNeeds("pin")) {
            var pin = layer.property("ADBE Effect Parade").addProperty("ADBE Corner Pin");
            pin.name = "DaVinci Pitch/Yaw";
            for (var c = 0; c < 4; c++) {
                (function (ci) {
                    setLook(pin.property("ADBE Corner Pin-000" + (ci + 1)), times, each(function (o) { return o.pin.corners[ci]; }));
                })(c);
            }
        }
    }

    // DaVinci's lens Distortion (-1..1) as AE's Optics Compensation followed by a uniform scale
    // about the image centre (a Transform effect, so the scale cannot interfere with the layer's
    // own anchor), clipped back to the image's rectangle as DaVinci's is. DaVinci's curve is not AE's, but for each value one FOV and one scale match it
    // closely: positive values are a pincushion (Reverse Lens Distortion on), negative a barrel.
    // DISTORTION_TABLE holds [FOV, scale] at -1.0, -0.95 ... 1.0, calibrated by rendering frames
    // in both apps and maximising their PSNR (tools/debug/calibrate_distortion.py). The steps are
    // 0.05 because DaVinci's curve does not interpolate linearly in FOV and scale: at 0.1 steps
    // a value halfway between two entries was off by up to 8 px where the entries themselves
    // were within 1 to 3.
    var DISTORTION_TABLE = [
        // -1.00 ... -0.05 (FOV Orientation vertical)
        [118.0, 5.148], [106.5, 4.202], [101.0, 3.618], [96.2, 3.161], [93.0, 2.849],
        [85.2, 2.519], [82.5, 2.304], [77.3, 2.108], [72.8, 1.945], [67.8, 1.803],
        [63.5, 1.681], [58.9, 1.575], [54.2, 1.481], [49.6, 1.397], [44.6, 1.321],
        [39.8, 1.254], [34.9, 1.193], [29.9, 1.139], [23.5, 1.087], [16.3, 1.042],
        [0.0, 1.0],   // 0
        // 0.05 ... 1.00 (Reverse Lens Distortion, FOV Orientation horizontal)
        [9.2, 1.0], [25.0, 0.995], [45.9, 0.971], [58.4, 0.95], [67.6, 0.927],
        [74.4, 0.905], [78.9, 0.888], [82.3, 0.871], [84.9, 0.857], [86.5, 0.849],
        [87.7, 0.843], [88.7, 0.836], [89.5, 0.831], [90.2, 0.827], [90.6, 0.824],
        [91.0, 0.821], [91.2, 0.82], [91.6, 0.816], [91.8, 0.815], [91.9, 0.815]
    ];

    function distortionParams(d) {
        var x = (Math.max(-1, Math.min(1, d)) + 1) * 20;
        var i = Math.min(39, Math.floor(x));
        var f = x - i;
        var a = DISTORTION_TABLE[i];
        var b = DISTORTION_TABLE[i + 1];
        // The middle entry is [0, 1], so neither side interpolates across the change of direction
        return { fov: a[0] + (b[0] - a[0]) * f, scale: a[1] + (b[1] - a[1]) * f, reverse: d > 0 };
    }

    function addDistortionEffects(layer, footage, fov, scale, reverse) {
        var fx = layer.property("ADBE Effect Parade");
        var oc = fx.addProperty("ADBE Optics Compensation");
        oc.name = "DaVinci Distortion";
        oc.property("ADBE Optics Compensation-0001").setValue(fov);
        oc.property("ADBE Optics Compensation-0002").setValue(reverse ? 1 : 0);
        // FOV Orientation changes the shape of AE's curve, not just its strength. Measured at
        // +0.3: Horizontal leaves 95% of the frame within 0.74 px of DaVinci's pincushion where
        // Vertical leaves 4.5 px; Vertical already fits the barrel side within 0.3 px.
        oc.property("ADBE Optics Compensation-0003").setValue(reverse ? 1 : 2);
        // Resize lets a pincushion grow past the layer's bounds, as DaVinci's does. Max 4X, not
        // Unlimited: at FOV 53 reversed, Unlimited never finishes rendering a frame (AE 2025).
        if (reverse) oc.property("ADBE Optics Compensation-0006").setValue(3);
        var tr = fx.addProperty("ADBE Geometry2");
        tr.name = "DaVinci Distortion Scale";
        tr.property("ADBE Geometry2-0001").setValue([footage.width / 2, footage.height / 2]);
        tr.property("ADBE Geometry2-0002").setValue([footage.width / 2, footage.height / 2]);
        tr.property("ADBE Geometry2-0003").setValue(scale * 100);
        // DaVinci keeps the distorted image inside its original rectangle (straight edges,
        // filled corners). Set Matte taking this layer's own source as the matte clips the
        // result back to it; it reads the source, so effects do not move the matte, and it
        // multiplies with the alpha already there, so a crop mask survives.
        var clip = fx.addProperty("ADBE Set Matte3");
        clip.name = "DaVinci Distortion Bounds";
        clip.property("ADBE Set Matte3-0001").setValue(layer.index);
    }

    // DaVinci Composite Mode names (written by daelink.lua) to AE blending modes. Checked by
    // rendering every mode in both apps (tools/debug/calibrate_blend_modes.py): on opaque
    // pixels the first group matches within rounding. The approximate group uses different
    // colour maths in DaVinci and only resembles AE's. DaVinci's alpha and luminance modes
    // render as Normal for a clip over plain footage, so they map to Normal.
    var BLEND_MODES = {
        normal: "NORMAL", add: "ADD", subtract: "SUBTRACT", difference: "DIFFERENCE",
        multiply: "MULTIPLY", screen: "SCREEN", overlay: "OVERLAY", hardLight: "HARD_LIGHT",
        softLight: "SOFT_LIGHT", darken: "DARKEN", lighten: "LIGHTEN",
        colorDodge: "CLASSIC_COLOR_DODGE", colorBurn: "CLASSIC_COLOR_BURN", exclusion: "EXCLUSION",
        divide: "DIVIDE", linearDodge: "ADD", linearBurn: "LINEAR_BURN", linearLight: "LINEAR_LIGHT",
        vividLight: "VIVID_LIGHT", pinLight: "PIN_LIGHT",
        // approximate
        hue: "HUE", saturation: "SATURATION", color: "COLOR", lumaMask: "LUMINOSITY",
        // DaVinci's Lighter/Darker Color keep whichever whole pixel has the larger/smaller
        // R+G+B sum (measured: 39 dB with that model); AE's compare luminance. Same operation,
        // different brightness measure, so they agree wherever the two measures do.
        hardMix: "HARD_MIX", lighterColor: "LIGHTER_COLOR", darkerColor: "DARKER_COLOR",
        // render as Normal in DaVinci for a clip over footage
        foreground: "NORMAL", alpha: "NORMAL", invertedAlpha: "NORMAL", luminosity: "NORMAL",
        invertedLuminosity: "NORMAL"
    };

    function applyDaVinciBlendMode(layer, mode) {
        if (!mode || mode === "normal") return;
        var ae = BLEND_MODES[mode];
        if (ae && BlendingMode[ae] !== undefined) layer.blendingMode = BlendingMode[ae];
    }

    // The scale DaVinci's Input Scaling applies to a source before Zoom, as [x, y] factors.
    // mode is written per layer by the Lua side: "fit", "fill", "stretch" or "crop" (centre
    // crop, no resizing). The source's displayed width includes its pixel aspect, the same
    // width DaVinci fits. A missing mode (JSON from before this field existed) keeps the old
    // behaviour, native size, so existing projects import exactly as they always did.
    function inputScaleFactors(mode, footage, comp) {
        if (!mode || mode === "crop" || !footage || !footage.width || !footage.height) return [1, 1];
        var par = footage.pixelAspect || 1;
        var fx = comp.width / (footage.width * par);
        var fy = comp.height / footage.height;
        if (mode === "fit") { var f = Math.min(fx, fy); return [f, f]; }
        if (mode === "fill") { var g = Math.max(fx, fy); return [g, g]; }
        if (mode === "stretch") return [fx, fy];
        return [1, 1];
    }

    function findFoldersByName(name, parent) {
        var matches = [];
        var items = parent ? parent.items : app.project.items;

        for (var i = 1; i <= items.length; i++) {
            var item = items[i];
            if (item instanceof FolderItem) {
                if (item.name.toLowerCase() === name.toLowerCase()) {
                    matches.push(item);
                }
                matches = matches.concat(findFoldersByName(name, item));
            }
        }
        return matches;
    }

    function versionCheck() {
        var data = loadJSONData();
        if (!data) return false;

        // schemaVersion gates cross-script JSON compatibility. Early-beta
        // projects have no schemaVersion field; treat them as schema 1.
        var savedSchema = data.schemaVersion || 1;
        var scriptSchema = CONFIG.schemaVersion;

        if (savedSchema !== scriptSchema) {
            alert("DAELink schema mismatch detected.\n\nProject schema: v" + savedSchema + "\nScript schema: v" + scriptSchema + "\n\nThe project was created by an incompatible version of DAELink. Please align script versions in both AE and Resolve.");
            return false;
        }
        return true;
    }

    function linkWithDavinci() {
        var data = loadJSONData();
        if (!data || !data.compositions) {
            alert("No compositions found - please set up the project in DaVinci Resolve first.");
            return;
        }

        var exists = findCompKeyByAeID(data, activeComp.id);
        if (exists) {
            alert("Active comp '" + activeComp.name + "' is already linked to this DaVinci project.");
            return;
        }

        for (var key in data.compositions) {
            var savedName = data.compositions[key].name;
            if (savedName === activeComp.name) {
                alert("A composition named '" + activeComp.name + "' is already linked in this project. Please rename before linking.");
                return;
            }
        }

        // Never compare frame rates with !==. projectFPS arrives as a string (DaVinci's
        // GetSetting returns strings), and AE stores frameRate as a 32-bit float, so 23.976
        // reads back as 23.9759979248047. Either alone makes strict comparison true for rates
        // that genuinely match. Same tolerance as fpsNameStartFrameCheck.
        if (Math.abs(Number(data.projectFPS) - activeComp.frameRate) > 0.01) {
            if (confirmPropertyChange("frame rate", data.projectFPS, activeComp.frameRate, "FPS")) {
                activeComp.frameRate = Number(data.projectFPS);
            } else {
                alert("Frame rates don't match - operation cancelled.");
                return false;
            }
        }

        // Store the rate DaVinci reports, not the one AE reads back. AE holds frameRate as a
        // 32-bit float, so a 59.94 comp reports 59.939998626709 and a 23.976 one reports
        // 23.975999832153. Both are fine to work with, but written into the JSON as the saved
        // rate they are no longer the "59.94" string DaVinci's GetSetting returns, and the
        // Lua side then had to be told not to read that as a mismatch. Writing the canonical
        // value removes the discrepancy at the source. The check above has already
        // established the two agree within tolerance, so this is the same rate, spelled
        // the way both sides spell it.
        var canonicalFPS = Number(data.projectFPS);
        if (!isFinite(canonicalFPS) || canonicalFPS <= 0) canonicalFPS = activeComp.frameRate;

        if (activeComp.displayStartFrame !== 0) {
            if (confirm("Active comp start frame is " + activeComp.displayStartFrame + ". Reset to 0?")) {
                activeComp.displayStartFrame = 0;
            }
            else {
                alert("Comp start frame must be 0 to link - operation cancelled.");
                return false;
            }
        }

        // 1. Collect all keys matching: prelink#
        var prelinkKeys = [];
        for (var key in data.compositions) {
            if (/^prelink\d+$/.test(key)) {
                prelinkKeys.push(key);
            }
        }

        // 2. Determine next index
        var nextIndex = 1;
        if (prelinkKeys.length > 0) {
            var nums = [];
            for (var i = 0; i < prelinkKeys.length; i++) {
                nums.push(parseInt(prelinkKeys[i].replace("prelink", ""), 10));
            }
            nextIndex = Math.max.apply(null, nums) + 1;
        }

        var newKey = "prelink" + nextIndex;
        // 3. Create new entry
        data.compositions[newKey] = {
            name: activeComp.name,
            aeID: activeComp.id,
            markers: [],
            fps: canonicalFPS,
            resolutionWidth: activeComp.width,
            resolutionHeight: activeComp.height,
            // Round: seconds * fps carries floating point dust (29 frames at 25fps comes out
            // as 28.999999999999996). DaVinci uses this straight as a frame count, so an
            // un-rounded value can truncate a frame off the nest.
            duration: Math.round(activeComp.duration * activeComp.frameRate),
            compStartFrame: activeComp.displayStartFrame
        };

        activeComp.parentFolder = linkedCompsFolder;

        saveJSONData(data);
    }

    // silent suppresses only the "nothing to do" notice at the end. The DaVinci side pushes
    // this automatically after creating a nest, so a second push for the same comp (a double
    // click, or a comp already imported) must not pop a dialog the user did not ask for.
    function importNewComps(silent) {
        defineJSON();
        jsonFile = new File(JSONfilePath);
        if (!jsonFile.exists) {
            alert("DAELink data file not found at " + jsonFile.fsName);
            return;
        }

        var data = loadJSONData();
        if (!data) return;

        // Make sure compositions exist in JSON
        if (!data.compositions) {
            alert("No compositions found in JSON.");
            return;
        }

        // A whole import is one Ctrl+Z. The try/finally is what guarantees it: an unbalanced
        // group stays open and swallows every later unrelated edit into this same undo step.
        app.beginUndoGroup("Make Comps from JSON");
        var btnClickResult = false;
        try {

        for (var davinciCompID in data.compositions) {
            // Only make comp if it doesn't exist in project
            if (data.compositions[davinciCompID].aeID == null) {
                if (findCompByID(data.compositions[davinciCompID].aeID) == null) {
                    var compData = data.compositions[davinciCompID];
                    var fps = compData.fps || 24;
                    var currentComp = app.project.items.addComp(compData.name, compData.resolutionWidth, compData.resolutionHeight, 1, compData.duration / fps, fps);
                    currentComp.parentFolder = linkedCompsFolder;
                    data.compositions[davinciCompID].aeID = currentComp.id;
                    saveJSONData(data);
                    currentComp.openInViewer();
                    
                    // Import and add layers 
                    importAndAddLayers(currentComp, compData, fps);

                    // Cleanup - remove layers from json once transferred 
                    compData.layers = null; 
                    saveJSONData(data);

                    // Create markers from JSON data on the comp itself.
                    // Default to [] - an entry written by the Lua side with no markers arrives
                    // as an empty object or with the key absent entirely, and reading .length
                    // off undefined would throw and take the undo group down with it.
                    var markers = compData.markers || [];
                    for (var i = 0; i < markers.length; i++) {
                        var m = markers[i];
                        var startTime = m.recordFrame / compData.fps;
                        // \n separates name and note in AE marker comments - \r is one-way only.
                        var myMarker = new MarkerValue(m.name + "\n" + m.note);
                        // DaVinci has no 0-frame markers; its 1-frame markers map to AE's 0-duration ones.
                        myMarker.duration = m.duration <= 1 ? 0 : m.duration / compData.fps;

                        // Set label by colour index - AE and DaVinci colour names don't align.
                        myMarker.label = m.color;
                        currentComp.markerProperty.setValueAtTime(startTime, myMarker);
                    }
                    btnClickResult = true; 
                } 
            }
            else {
            // Comp has been created therefore has had an aeID already (so not null)
            // Therefore if we don't find a matching ID in project, it must have been deleted
                if (findCompByID(data.compositions[davinciCompID].aeID) == null) {
                    var obsoleteCompName = data.compositions[davinciCompID].name; 
                    delete data.compositions[davinciCompID];
                    saveJSONData(data);
                    btnClickResult = true;
                }
            }
        }

        } finally {
            // Runs on the normal path and on any throw, so the group is always balanced
            app.endUndoGroup();
        }
        if (!btnClickResult && !silent) { alert("No new comps to link."); }
        return btnClickResult;
    }

    // RENDER HELPERS
    function refreshComp() {
        var data = loadJSONData();
        if (!data) return;

        activeComp = app.project.activeItem;

        if (activeComp && activeComp instanceof CompItem) {
            var davinciID = findCompKeyByAeID(data, activeComp.id);
            if (davinciID) {
                if (fpsNameStartFrameCheck(data.compositions[davinciID]) == false) return;
                return true;
            }
            else {
                alert("Active comp '" + activeComp.name + "' is not linked to this project.\n\nTo link a comp:\n1. In AE: click " + ICONS.upArrow + " Link Active Comp.\n2. In DaVinci: click " + ICONS.downArrow + " Import Linked Comps.");
            }
        } else {
            alert("No active comp.");
            return false;
        }
    }

    function addToQ(templateDropdown) { 
        var data = loadJSONData();
        if (!data) return;

        // No selection at all is treated the same as the "Select Render Template..." row.
        // loadTemplates() starts with removeAll(), which nulls selection, so if it ever throws
        // partway the dropdown is left empty - applyTemplate(null) would then throw here.
        if (!templateDropdown.selection ||
            templateDropdown.selection.index === 0) {
            alert("Please select a valid render template from the dropdown.");
            return;
        }

        // Comps created through DAELink have no illegal characters, but dots are legal in a comp
        // name and still can't survive into a render file name - see sanitizeFileName.
        var safeName = sanitizeFileName(activeComp.name);
        if (safeName === "") {
            alert("The comp name '" + activeComp.name + "' contains no characters usable in a file name.\n\nRename the nest in DaVinci, then refresh.");
            return;
        }
        // Once per comp name per session - this fires on every render otherwise
        if (safeName !== activeComp.name && !renderNameNotices[activeComp.name]) {
            renderNameNotices[activeComp.name] = true;
            alert("The comp name '" + activeComp.name + "' can't be used as a render file name.\n\nRendering to '" + safeName + "' instead. The comp and the DaVinci nest keep their name - only the file on disk differs.");
        }

        var renderQueueItem = app.project.renderQueue.items.add(activeComp);
        var outputModule = renderQueueItem.outputModules[1];
        outputModule.applyTemplate(templateDropdown.selection);

        var renderPath = projectMediaPath + "/" + CONFIG.directoryNames.root + "/" + CONFIG.directoryNames.renders + "/" + safeName;
        data.compositions[findCompKeyByAeID(data, activeComp.id)].renderPath = renderPath;
        // Rounded for the same reason as in linkWithDavinci - this is a frame count
        data.compositions[findCompKeyByAeID(data, activeComp.id)].duration = Math.round(activeComp.duration * activeComp.frameRate); // Update in case of changes
        saveJSONData(data);
        
        outputModule.file = new File(renderPath);

        // AE decides the extension itself, and rewrites the path it was handed to do so. Read it
        // back and confirm our basename survived - if it did not, the render lands somewhere
        // DaVinci will never find and would look like an orphan to Delete Unused Renders.
        var writtenName = decodeURI(outputModule.file.name);
        var writtenBase = writtenName.replace(/\.[^\.]+$/, "");
        if (writtenBase !== safeName) {
            alert("After Effects changed the render file name from '" + safeName + "' to '" + writtenName + "'.\n\nDaVinci looks for the render by name, so Refresh Render will not find this file. This usually means the selected template writes an image sequence rather than a single movie file.");
        }

        return outputModule;
    }

    function loadTemplates() {
        templateDropdown.removeAll();
        templateDropdown.add("item", "Select Render Template...");
        var originalComp = activeComp;

        if (app.project.renderQueue.numItems > 0) {
            // Accessing existing templates from the first item in the render queue
            var outputModule = app.project.renderQueue.item(1).outputModules[1];
            if (outputModule) {
                var templates = outputModule.templates;
                if (templates && templates.length > 0) {
                    for (var i = 0; i < templates.length; i++) {
                        templateDropdown.add("item", templates[i]);
                    }
                } else {
                    templateDropdown.add("item", "No templates found");
                }
            } else {
                templateDropdown.add("item", "No output modules found");
            }
        } else {
            // Create a temporary composition to get templates
            var tempComp = app.project.items.addComp("TempComp", 100, 100, 1, 1, 25);
            var renderQueueItem = app.project.renderQueue.items.add(tempComp);
            var outputModule = renderQueueItem.outputModules[1];

            if (outputModule) {
                var templates = outputModule.templates;
                if (templates && templates.length > 0) {
                    for (var i = 0; i < templates.length; i++) {
                        templateDropdown.add("item", templates[i]);
                    }
                } else {
                    templateDropdown.add("item", "No templates found");
                }
            }
            // Clean up by removing the temporary items
            renderQueueItem.remove();
            tempComp.remove();
        }

        // Restore the original composition to active if available
        if (originalComp) {
            originalComp.openInViewer();
        }
    }

    // MARKER HELPERS
    function findOrCreateDAELinkFolders() {
        var data = loadJSONData();
        var targetRootName = CONFIG.folderNames.linkedComps;
        var targetSubName  = CONFIG.folderNames.importedMedia;

        // Find the root "0_LinkedComps" folder
        var linkedMatches = findFoldersByName(targetRootName, null);

        if (linkedMatches.length > 1) {
            alert("Multiple folders named '" + targetRootName + "' found. Please resolve before continuing.");
            return null;
        }

        if (linkedMatches.length === 1) {
            linkedCompsFolder = linkedMatches[0];
            var expectedID = CONFIG.projectIDPrefix + data.projectid;
            if (linkedCompsFolder.comment !== expectedID) {
                alert("This AE project is linked to a different DAELink project ID");
                linkedCompsFolder = null;
                return null;
            }
        } else {
            linkedCompsFolder = app.project.items.addFolder(targetRootName);
            linkedCompsFolder.comment = CONFIG.projectIDPrefix + data.projectid;
        }

        // Now look for "0_DAELinkImports" inside it
        var importedMediaMatches = findFoldersByName(targetSubName, linkedCompsFolder);

        if (importedMediaMatches.length > 1) {
            alert("Multiple folders named '" + targetSubName + "' found within '" + targetRootName + "'. Please resolve before continuing.");
            return null;
        }

        // Create or use the one found
        importedMediaFolder = (importedMediaMatches.length === 1) ?
            importedMediaMatches[0] : linkedCompsFolder.items.addFolder(targetSubName);

        return {
            linkedCompsFolder: linkedCompsFolder,
            importedMediaFolder: importedMediaFolder
        };
    }

    function fpsNameStartFrameCheck(compData) {
        var davinciFPS = compData.fps;
        var activeCompFPS = activeComp.frameRate; 

        if (Math.abs(davinciFPS - activeCompFPS) > 0.01) {
            if (confirmPropertyChange("frame rate", davinciFPS, activeCompFPS, "FPS")) {
                activeComp.frameRate = davinciFPS;
            } else {
                alert("Frame rates don't match - operation cancelled.");
                return false;
            }
        }

        if (compData.aeID == activeComp.id) {
            if (compData.name !== activeComp.name) {
                if (confirmPropertyChange("name", compData.name, activeComp.name)) {
                    activeComp.name = compData.name;
                } else {
                    alert("Names don't match - operation cancelled.");
                    return false;
                }
            }
            if (compData.compStartFrame !== activeComp.displayStartFrame) {
                if (confirmPropertyChange("start frame", compData.compStartFrame, activeComp.displayStartFrame)) {
                    activeComp.displayStartFrame = compData.compStartFrame;
                } else {
                    alert("Start frames don't match - operation cancelled.");
                    return false;
                }
            }
        }

        return true; 
    }

    function getMarkersDataFromComp(comp, fps) {
        var markers = [];
        var markerProp = comp.markerProperty;

        if (!markerProp || !markerProp.numKeys) return markers;

        for (var i = 1; i <= markerProp.numKeys; i++) {
            var keyTime = markerProp.keyTime(i);
            var markerValue = markerProp.keyValue(i);
            var comment = markerValue.comment || "";

            // Properly handle AE's special line break character
            var lineBreakIndex = comment.search(/\r\n|\r|\n/);
            var name, note;

            if (lineBreakIndex !== -1) {
                name = comment.substring(0, lineBreakIndex);
                note = comment.substring(lineBreakIndex + 1);
            } else {
                name = comment;
                note = "";
            }

            // Clamp markers that start before frame 0 (DaVinci has no negative timeline).
            var recordFrame = Math.round(keyTime * fps);
            var duration = Math.round(markerValue.duration * fps);
            if (recordFrame < 0) {
                duration = duration + recordFrame; // recordFrame is negative, so this trims duration
                recordFrame = 0;
            }

            markers.push({
                name: name,
                note: note,
                recordFrame: recordFrame,
                duration: duration,
                color: markerValue.label || 0
            });
        }
        return markers;
    }

    function importMarkers() {
        var data = loadJSONData();
        if (!data) return;

        var compData = data.compositions[findCompKeyByAeID(data, activeComp.id)];
        var markerProp = activeComp.markerProperty;

        while (markerProp.numKeys > 0) {
            markerProp.removeKey(1);
        }

        var markers = compData.markers;
        for (var i = 0; i < markers.length; i++) {
            var m = markers[i];
            var startTime = m.recordFrame / compData.fps;
            // DaVinci has no 0-frame markers; its 1-frame markers map to AE's 0-duration ones.
            var duration = m.duration <= 1 ? 0 : m.duration / compData.fps;

            // \n separates name and note in AE marker comments - \r is one-way only.
            var myMarker = new MarkerValue(m.name + "\n" + m.note);
            myMarker.duration = duration;
            myMarker.label = m.color;

            markerProp.setValueAtTime(startTime, myMarker);
        }
    }

    function exportMarkers() {
        var data = loadJSONData();
        if (!data) return;

        var markers = getMarkersDataFromComp(activeComp, activeComp.frameRate);

        // Flatten line breaks only. Do NOT escape backslashes or quotes here:
        // safeJSONStringify already does that at write time, and escaping twice makes
        // every export add another layer of backslashes to the same note.
        // DaVinci keeps markers on one line, so a note's own newlines collapse to spaces.
        for (var i = 0; i < markers.length; i++) {
            var mm = markers[i];
            if (mm.name) mm.name = mm.name.replace(/[\r\n]+/g, " ");
            if (mm.note) mm.note = mm.note.replace(/[\r\n]+/g, " ");
        }

        data.compositions[findCompKeyByAeID(data, activeComp.id)].markers = markers;

        saveJSONData(data);
    }

    function findCompByID(aeCompID) {
        var foundComp = null;
        for (var i = 1; i <= app.project.numItems; i++) {
            if (app.project.item(i).id == aeCompID) {
                foundComp = app.project.item(i);
                break;
                
            }
        }
        return foundComp;
    }

    function findCompKeyByAeID(data, aeID) {
        var comps = data.compositions;

        for (var key in comps) {
            if (!comps.hasOwnProperty(key)) continue;

            var entry = comps[key];

            if (entry && entry.aeID && entry.aeID === aeID) {
                return key;
            }
        }
        return null;
    }

    // NAME SANITISING //

    // A comp name becomes the render file name (see addToQ), so any character that is illegal
    // in a file name breaks the render round trip. "/" is the worst case: AE reads it as a
    // directory separator and renders into a folder that does not exist.
    // The illegal-character class is shared with CONSTANTS.ILLEGAL_NAME_PATTERN in daelink.lua.
    //
    // Dots are handled HERE ONLY, and deliberately do not exist in the Lua-side sanitiser:
    // a dot is perfectly legal in a comp/timeline name, but AE's output module reads the last
    // ".<something>" as the file extension and replaces it with the format's own. A comp named
    // "TestV1.2" therefore renders to "TestV1.mp4", which DaVinci can never match, and which two
    // comps ("TestV1.2" and "TestV1.9") would silently collide on. So the comp keeps its dots and
    // only the file name loses them.
    // Windows refuses these as file names whatever the extension, so "CON" would render to
    // CON.mp4 and fail. Matched case-insensitively against the name before the extension.
    // Keep in sync with RESERVED_DEVICE_NAMES in daelink.lua.
    var RESERVED_DEVICE_NAMES = "|CON|PRN|AUX|NUL|COM1|COM2|COM3|COM4|COM5|COM6|COM7|COM8|COM9|LPT1|LPT2|LPT3|LPT4|LPT5|LPT6|LPT7|LPT8|LPT9|";

    function isReservedDeviceName(name) {
        return RESERVED_DEVICE_NAMES.indexOf("|" + String(name).toUpperCase() + "|") !== -1;
    }

    function sanitizeFileName(name) {
        var cleaned = String(name).replace(/[\/\\:\*\?"<>|]/g, "-");
        cleaned = cleaned.replace(/[\x00-\x1F\x7F]/g, "");
        cleaned = cleaned.replace(/\./g, "-");
        // Leading and trailing spaces are both illegal on Windows even though the char itself is fine
        cleaned = cleaned.replace(/^\s+/, "").replace(/\s+$/, "");
        // Suffix rather than replace, so two comps can't collapse onto the same file name
        if (isReservedDeviceName(cleaned)) cleaned = cleaned + "-1";
        return cleaned;
    }

    // JSON HELPERS //

    // Use this instead of JSON.stringify for all file writes.
    // ExtendScript's native JSON.stringify does not escape U+2028 / U+2029
    // (Unicode line separators) or, on some AE versions, bare \n / \r inside
    // string values. JSON.parse then sees a literal line break inside a quoted
    // string and throws "Unterminated string constant".
    function safeJSONStringify(v) {
        var escStr = function (s) {
            return s
                .replace(/\\/g, "\\\\")
                .replace(/"/g, '\\"')
                .replace(/\x08/g, "\\b")
                .replace(/\x0C/g, "\\f")
                .replace(/\n/g, "\\n")
                .replace(/\r/g, "\\r")
                .replace(/\t/g, "\\t")
                .replace(/\u2028/g, "\\u2028")
                .replace(/\u2029/g, "\\u2029")
                .replace(/[\x00-\x07\x0B\x0E-\x1F\x7F]/g, function (c) {
                    return "\\u" + ("000" + c.charCodeAt(0).toString(16)).slice(-4);
                });
        };
        if (v === null || v === undefined) return "null";
        var t = typeof v;
        if (t === "boolean") return v ? "true" : "false";
        if (t === "number") return isFinite(v) ? String(v) : "null";
        if (t === "string") return '"' + escStr(v) + '"';
        if (t === "object") {
            if (v instanceof Array) {
                var aParts = [];
                for (var ai = 0; ai < v.length; ai++) {
                    aParts.push(v[ai] === undefined ? "null" : safeJSONStringify(v[ai]));
                }
                return "[" + aParts.join(",") + "]";
            }
            var oParts = [];
            for (var ok in v) {
                if (v[ok] !== undefined) {
                    oParts.push('"' + escStr(ok) + '":' + safeJSONStringify(v[ok]));
                }
            }
            return "{" + oParts.join(",") + "}";
        }
        return "null";
    }

    function defineJSON() {
        if (typeof JSON === 'undefined') {
            JSON = {
                parse: function (sJSON) { return eval('(' + sJSON + ')'); },
                stringify: safeJSONStringify
            };
        }
    }

    function saveJSONData(data) {
        if (!data) {
            alert("No data provided to saveJSONData()");
            return false;
        }

        // Encode FIRST so a stringify error never reaches the file.
        var jsonString;
        try {
            jsonString = safeJSONStringify(data);
        } catch (e) {
            alert("Error encoding JSON (file left untouched): " + e.toString());
            return false;
        }
        if (typeof jsonString !== "string" || jsonString.length === 0) {
            alert("Encoded JSON was empty (file left untouched).");
            return false;
        }

        // Write to a sibling .tmp, verify by re-parse, then swap over the original.
        // This survives mid-write failures (eg. AE script permissions disabled, which
        // previously caused open('w') to truncate the original then fail silently).
        var tmpFile = new File(jsonFile.fsName + ".tmp");
        try { tmpFile.encoding = "UTF-8"; } catch (e) {}
        tmpFile.lineFeed = ($.os && $.os.indexOf("Windows") !== -1) ? "Windows" : "Unix";

        if (!tmpFile.open('w')) {
            alert("Unable to open JSON temp file for writing (original preserved)." + writeFailureHint());
            return false;
        }
        var writeOk;
        try {
            writeOk = tmpFile.write(jsonString + "\n");
        } catch (e) {
            tmpFile.close();
            try { tmpFile.remove(); } catch (e2) {}
            alert("Error writing JSON (original preserved): " + e.toString() + writeFailureHint());
            return false;
        }
        tmpFile.close();
        if (!writeOk) {
            try { tmpFile.remove(); } catch (e) {}
            alert("Failed to write JSON temp file (original preserved)." + writeFailureHint());
            return false;
        }

        // Verify by re-reading + parsing the temp file before swapping.
        try { tmpFile.encoding = "UTF-8"; } catch (e) {}
        if (!tmpFile.open('r')) {
            try { tmpFile.remove(); } catch (e) {}
            alert("Failed to verify JSON temp file (original preserved).");
            return false;
        }
        var roundtrip = tmpFile.read();
        tmpFile.close();
        try {
            JSON.parse(roundtrip);
        } catch (e) {
            try { tmpFile.remove(); } catch (e2) {}
            alert("JSON temp file is corrupt (original preserved): " + e.toString() +
                  "\nWritten: " + (jsonString.length + 1) + " chars | Read back: " + roundtrip.length + " chars");
            return false;
        }

        // Swap: remove original, rename tmp to original's name.
        // File.rename takes only a leaf name and renames within the same folder.
        var leafName = decodeURI(jsonFile.name);
        if (jsonFile.exists) {
            if (!jsonFile.remove()) {
                alert("Could not remove original JSON to swap in update (a stale .tmp may remain).");
                return false;
            }
        }
        if (!tmpFile.rename(leafName)) {
            alert("Could not rename JSON temp file into place. The latest data is in: " + tmpFile.fsName);
            return false;
        }

        return true;
    }

    function loadJSONData() {
        if (!jsonFile.exists) {
            alert("JSON file not found!" + backupHint());
            return false;
        }

        // Explicit, to match every write. The Lua side writes raw UTF-8, and an unset encoding
        // falls back to the system default, which on Windows may be a code page that garbles
        // non-ASCII comp names a little further on every save. Measured on Mac AE 2025: an
        // unset read already decodes UTF-8 correctly, so this changes nothing there.
        try { jsonFile.encoding = "UTF-8"; } catch (e) {}
        jsonFile.open('r');
        var jsonData = jsonFile.read();
        jsonFile.close();

        var data;
        try {
            data = JSON.parse(jsonData);
        } catch (e) {
            alert("Error parsing JSON: " + e.message + backupHint());
            return false;
        }

        rotateJSONBackup(jsonFile, jsonData);
        return data;
    }
}
DAELink(this);