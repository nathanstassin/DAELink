function MotionBridge(thisObj) {
    /*
    MotionBridge  | v0.9 Beta | © 2025-2026 Nathan Stassin

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

    Description:  Links compositions to nests in Davinci with a dockable UI panel. 
                  1-click renders and shared markers across programs. 

    Author:       Nathan Stassin  |  https://www.nathanstassin.com

    Requirements: Adobe After Effects 2025 or later 

    Intallation:  Drag this file into the SciptUI Panels folder on your computer
                  Mac: /Applications/After Effects #version#/Scripts/ScriptUI Panels/
                  Windows: \Program Files\Adobe/Adobe After Effects #version#\Support Files\Scripts\ScriptUI Panels\

    Privacy:      All data stored locally. No data is transmitted to external servers.

    Version History:
    - 0.9 Beta - 17/01/2026 
    */ 
    // GLOBAL VARIABLES 
    var CONFIG = {
        scriptName: "MotionBridge",
        version: 0.9,
        websiteurl: "https://nathanstassin.com/motionbridge",
        projectIDPrefix: "MotionBridgeProjectID:",
        folderNames: {
            linkedComps: "0_LinkedComps",
            importedMedia: "0_MotionBridgeImports"
        },
        directoryNames: {
            root: "motionbridge",
            renders: "Renders",
            support: "Support"
        },
        fileNames: {
            json: "motionbridge.json"
        },
        layerNames: {
            markers: "MotionBridgeMarkers"
        }
    };

    var ICONS = {
        logoData: String.fromCharCode(137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,24,0,0,0,24,8,4,0,0,0,74,126,245,115,0,0,0,32,99,72,82,77,0,0,122,38,0,0,128,132,0,0,250,0,0,0,128,232,0,0,117,48,0,0,234,96,0,0,58,152,0,0,23,112,156,186,81,60,0,0,0,2,98,75,71,68,0,255,135,143,204,191,0,0,0,9,112,72,89,115,0,0,11,19,0,0,11,19,1,0,154,156,24,0,0,0,7,116,73,77,69,7,233,12,22,10,17,28,7,82,255,33,0,0,1,62,73,68,65,84,56,203,141,148,77,78,194,64,0,70,191,10,129,233,78,126,148,107,32,110,185,128,241,10,198,181,137,87,192,22,22,38,46,16,15,128,18,41,120,3,14,66,196,83,232,158,89,62,23,148,58,253,129,58,179,105,210,247,58,111,166,105,165,204,64,8,195,152,103,12,66,37,3,33,234,12,176,88,2,234,37,74,140,63,176,229,131,37,91,194,163,138,131,47,105,209,36,194,30,81,82,120,27,33,90,71,20,7,95,112,134,226,217,102,94,168,164,158,254,135,239,148,252,42,5,49,53,170,84,169,21,134,21,196,116,233,227,227,211,231,162,32,44,23,211,99,68,3,33,78,9,185,204,134,9,195,192,137,169,240,202,125,178,131,59,102,84,156,176,0,35,198,241,185,239,144,115,62,121,74,132,71,54,116,226,235,38,17,91,38,39,242,228,201,61,53,116,163,107,25,213,117,165,91,73,158,115,199,147,39,12,1,150,40,94,163,194,20,248,97,197,138,111,96,70,53,78,122,199,50,196,223,109,58,196,18,197,187,232,178,97,63,190,232,57,248,8,67,114,172,33,150,121,162,76,89,179,230,45,143,187,111,34,76,133,117,232,164,98,70,169,175,131,124,216,126,22,225,25,101,238,40,135,240,3,97,199,240,156,210,164,81,130,103,148,5,81,41,238,40,1,22,203,240,255,255,13,195,132,23,252,34,252,23,246,181,14,208,87,176,67,142,0,0,0,37,116,69,88,116,100,97,116,101,58,99,114,101,97,116,101,0,50,48,50,53,45,49,50,45,50,49,84,49,51,58,50,48,58,48,52,43,48,48,58,48,48,160,116,189,185,0,0,0,37,116,69,88,116,100,97,116,101,58,109,111,100,105,102,121,0,50,48,50,53,45,49,50,45,50,49,84,49,51,58,49,57,58,53,48,43,48,48,58,48,48,8,113,98,185,0,0,0,40,116,69,88,116,100,97,116,101,58,116,105,109,101,115,116,97,109,112,0,50,48,50,53,45,49,50,45,50,50,84,49,48,58,49,55,58,50,56,43,48,48,58,48,48,236,133,236,151,0,0,0,0,73,69,78,68,174,66,96,130),
        copyright: "\u00A9",
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
        help: "\u003F",
        gear: "\u2699\uFE0E"
    };

    var HELPTEXT = {
        title: "How " + CONFIG.scriptName + " works",
        panelA : "Basics",
        panelAbullets : [
            "• Initialise project in Davinci Resolve.",
            "• Each project has its own motionbridge folder, with subfolders:",
            "       " + ICONS.downRightArrow + " Renders: all renders from AE",
            "       " + ICONS.downRightArrow + " Support: JSON file which contains link data",
            "• " + ICONS.openFolder + " Browse button: navigate and connect to current motionbridge project folder (or media folder enclosing it)",
        ],
        panelB : "Linking Compositions with Davinci Project " + ICONS.upArrow + " | " + ICONS.downArrow, 
        panelBbullets : [
            "• " + ICONS.upArrow + " Link Active Comp button establishes a link to a Davinci nest for currently active comp",
            "       " + ICONS.downRightArrow + " Click 'Import Linked Comps' button on Davinci side to finalise the link",
            "• " + ICONS.downArrow + " Import Linked Comps button finalises links established from Davinci",
            "       " + ICONS.downRightArrow + " Click 'Replace Linked Layers With Nested AE Comp' button on Davinci side to establish the link"    
        ],
        panelC : "Markers " + ICONS.upTriangle + " | " + ICONS.downTriangle,
        panelCbullets : [
            "• " + ICONS.upTriangle + " Export Markers button sends markers from MotionBridgeMarkers layer to Davinci nest",
            "       " + ICONS.downRightArrow + " Click Import Markers button on Davinci side to update",
            "• " + ICONS.downTriangle + " Import Markers button receives markers from Davinci, updating MotionBridgeMarkers layer",
            "       " + ICONS.downRightArrow + " Imports markers set with Export Markers button on Davinci side"
        ],
        panelD : "Renders " + ICONS.plus + " | " + ICONS.play, 
        panelDbullets : [    
            "• Select Render Template... dropdown determines render template for currently active comp",
            "       " + ICONS.downRightArrow + " Hint: Make your own templates in the render Queue window",
            "• " + ICONS.plus + " Queue button adds currently active comp to the render queue with selected template.",
            "• " + ICONS.play + " Render button adds active comp to queue with selected template and directly renders queue",
            "       " + ICONS.downRightArrow + " Renders go to 'Renders' folder in MotionBridge project folder",
            "       " + ICONS.downRightArrow + " Click Refresh Render button on Davinci side to update to latest render"
        ]
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

    var markersLayerName = CONFIG.layerNames.markers;
    var JSONfilePath;  
    var jsonFile;
    var linkedCompsFolder;
    var importedMediaFolder;
    var outputDir, templateDropdown;
    var activeComp = app.project.activeItem;

    (function(passedObj) {
        var myScriptPal = buildUI(passedObj);
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

        // PANEL 1 — Project Folder
        var connectToProjectFolderPanel = myPanel.add("panel", undefined, "Connect to Project Folder");
        setPanelMargins(connectToProjectFolderPanel, STYLES.margins.panel);
        var hGroup0 = createButtonGroup(connectToProjectFolderPanel);
        hGroup0.alignChildren = ["fill", "center"];
        hGroup0.spacing = STYLES.spacing.horizontalGroup;
        outputDir = hGroup0.add("statictext", undefined, "Browse to Project MotionBridge folder...");
        outputDir.characters = STYLES.sizes.pathTextCharacters;
        var browseBtn = hGroup0.add("button", undefined, ICONS.openFolder + " Browse");

        // PANEL 2 — Linked Comps
        var linkCompositionsPanel = myPanel.add("panel", undefined, "Link Compositions");
        setPanelMargins(linkCompositionsPanel, STYLES.margins.panel);
        var hGroup1 = createButtonGroup(linkCompositionsPanel);
        var importNewCompsBtn = hGroup1.add("button", undefined, ICONS.downArrow + " Import Linked Comps");
        var linkActiveCompBtn = hGroup1.add("button", undefined, ICONS.upArrow + " Link Active Comp");

        // PANEL 3 — Active Comp
        var activeCompPanel = myPanel.add("panel", undefined, "Active Comp");
        setPanelMargins(activeCompPanel, STYLES.margins.panel);

        // Marker buttons
        var hGroup2 = createButtonGroup(activeCompPanel);
        var importMarkersBtn = hGroup2.add("button", undefined, ICONS.downTriangle + " Import Markers");
        var exportMarkersBtn = hGroup2.add("button", undefined, ICONS.upTriangle + " Export Markers");

        // Template + Add to Queue
        var hGroup3 = createButtonGroup(activeCompPanel);
        templateDropdown = hGroup3.add("dropdownlist", undefined, []);

        // Render buttons
        var hGroup4 = createButtonGroup(activeCompPanel);
        var addToQBtn = hGroup4.add("button", undefined, ICONS.plus + " Queue");
        var renderBtn = hGroup4.add("button", undefined, ICONS.play + " Render");

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
        var brandingColumn = footerGroup.add("group");
        brandingColumn.orientation = "column";
        brandingColumn.alignChildren = ["left", "center"];
        brandingColumn.spacing = STYLES.spacing.brandingColumn;
        brandingColumn.margins = [0, 0, 0, 0]; // No margins on text group
        brandingColumn.add("statictext", undefined, CONFIG.scriptName + " - v" + CONFIG.version + " beta");
        var currentYear = new Date().getFullYear();
        var copyrightYear = currentYear > 2025 ? "2025-" + currentYear : "2025";
        brandingColumn.add("statictext", undefined, ICONS.copyright + copyrightYear + " Nathan Stassin");
        footerGroup.add("statictext", undefined, "").alignment = ["fill", "fill"];
        var buttonGroup = footerGroup.add("group");
        buttonGroup.alignment = ["right", "bottom"];
        buttonGroup.spacing = STYLES.spacing.buttonGroup;
        buttonGroup.margins = STYLES.margins.buttonGroup;
        var helpButton = createSquareButton(buttonGroup, ICONS.help, "Help");
        helpButton.onClick = showHelpDialog;

        // Resize handler
        var uiElements = [browseBtn, importNewCompsBtn, linkActiveCompBtn, renderBtn, addToQBtn, importMarkersBtn, exportMarkersBtn, templateDropdown]; 
        alignAndDisableUIElements(uiElements);
        browseBtn.enabled = true; 
        myPanel.onResizing = myPanel.onResize = function() { this.layout.resize(); }

        // BUTTON LOGIC
        function refreshProjectDisableUI() { 
            if (!refreshProject()) {
                alignAndDisableUIElements([importNewCompsBtn, linkActiveCompBtn, renderBtn, addToQBtn, importMarkersBtn, exportMarkersBtn, templateDropdown]);
                return false;
            }
            return true; 
        }

        browseBtn.onClick = function () {
            var folder = Folder.selectDialog("Open this project's motionbridge folder");
            if (!folder) return;

            // Detect if user selected the motionbridge folder directly
            var normalizedPath = folder.fsName.replace(/\\/g, "/");
            var lowerPath = normalizedPath.toLowerCase();
            
            if (lowerPath.match(new RegExp("/" + CONFIG.directoryNames.root + "/?$", "i"))) {
                // User selected motionbridge folder, strip it off to get parent
                var lastSlashIndex = normalizedPath.lastIndexOf("/motionbridge");
                if (lastSlashIndex === -1) {
                    lastSlashIndex = normalizedPath.lastIndexOf("/MotionBridge");
                }
                if (lastSlashIndex !== -1) {
                    normalizedPath = normalizedPath.substring(0, lastSlashIndex);
                    folder = new Folder(normalizedPath);
                }
            }

            // Check if motionbridge folder exists in the selected parent folder
            var motionbridgeFolder = new Folder(folder.fsName + "/motionbridge");
            if (!motionbridgeFolder.exists) {
                alert("No motionbridge folder found!");
                alignAndDisableUIElements([importNewCompsBtn, linkActiveCompBtn, renderBtn, addToQBtn, importMarkersBtn, exportMarkersBtn, templateDropdown]);
                return;
            }

            JSONfilePath = folder.fsName + "/" + CONFIG.directoryNames.root + "/" + CONFIG.directoryNames.support + "/" + CONFIG.fileNames.json;
            jsonFile = new File(JSONfilePath);

            if (!versionCheck()) {
                alignAndDisableUIElements([importNewCompsBtn, linkActiveCompBtn, renderBtn, addToQBtn, importMarkersBtn, exportMarkersBtn, templateDropdown]);
                return;
            }

            if (findOrCreateMLFolders()) {
                outputDir.text = folder.fsName;
                importNewCompsBtn.enabled = true;
                linkActiveCompBtn.enabled = true;
                renderBtn.enabled = true;
                addToQBtn.enabled = true;
                importMarkersBtn.enabled = true;
                exportMarkersBtn.enabled = true;
                templateDropdown.enabled = true;
                loadTemplates();
                templateDropdown.selection = 0;
            }
        };

        importNewCompsBtn.onClick = function () { 
            if (!refreshProjectDisableUI()) return;
            importNewComps();
        };

        linkActiveCompBtn.onClick = function () {
            if (!refreshProjectDisableUI()) return;
            activeComp = app.project.activeItem;
            if (activeComp && activeComp instanceof CompItem) {
                linkWithDavinci();
            }
        };

        renderBtn.onClick = function () {
            if (!refreshProjectDisableUI()) return;
            if (refreshComp() && addToQ(templateDropdown)) app.project.renderQueue.render();
        };

        addToQBtn.onClick = function () {
            if (!refreshProjectDisableUI()) return;
            if (refreshComp()) addToQ(templateDropdown);
        };

        importMarkersBtn.onClick = function () {
            if (!refreshProjectDisableUI()) return;
            if (refreshComp()) importMarkers();
        };

        exportMarkersBtn.onClick = function () {
            if (!refreshProjectDisableUI()) return;
            if (refreshComp()) exportMarkers();
        };

        templateDropdown.onActivate = function () {
            if (!refreshProjectDisableUI()) return;
            if (templateDropdown.items.length <= 1) loadTemplates();
        };

        return myPanel;
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

    function showHelpDialog() {
        var helpDialog = new Window("dialog", "Help");
        helpDialog.orientation = "column";
        helpDialog.alignChildren = "fill";
        helpDialog.spacing = 16;
        helpDialog.margins = 28;

        var titleText = helpDialog.add("statictext", undefined, HELPTEXT.title);
        titleText.alignment = "center";
        titleText.margins = 12;

        var panels = ["A", "B", "C", "D"];
        for (var p = 0; p < panels.length; p++) {
            var panelKey = "panel" + panels[p];
            var bulletsKey = panelKey + "bullets";
            
            var panel = helpDialog.add("panel", undefined, HELPTEXT[panelKey]);
            var bullets = HELPTEXT[bulletsKey];
            
            for (var i = 0; i < bullets.length; i++) {
                var instructionText = panel.add("statictext", undefined, bullets[i]);
                instructionText.alignment = ["fill", "top"];
                instructionText.margins = 2;
            }
        }

        var buttonGroup = helpDialog.add("group");
        buttonGroup.orientation = "row";
        buttonGroup.alignment = "center";
        buttonGroup.spacing = 12;
        buttonGroup.margins = 16;

        var learnMoreBtn = buttonGroup.add("button", undefined, "Learn More");
        var okBtn = buttonGroup.add("button", undefined, "OK");

        learnMoreBtn.preferredSize.width = 100;
        okBtn.preferredSize.width = 80;

        learnMoreBtn.onClick = function() {
            try {
                if ($.os.indexOf("Windows") !== -1) {
                    system.callSystem("cmd /c start " + CONFIG.websiteurl);
                } else {
                    system.callSystem("open " + CONFIG.websiteurl);
                }
            } catch (error) {
                alert("Cannot Open URL\nPlease visit: " + CONFIG.websiteurl);
            }
        };

        okBtn.onClick = function() {
            helpDialog.close(1);
        };

        helpDialog.show();
    }

    function setPanelMargins(panel, amount) {
        panel.margins = [amount, amount, amount, amount];
        panel.alignChildren = ["fill", "fill"];

    }

    function alignAndDisableUIElements(elements) {
        for (var i = 0; i < elements.length; i++) {
            elements[i].alignment = ["fill", "center"];
            elements[i].enabled = false;
        }
    }

    function confirmPropertyChange(propertyName, davinciValue, aeValue, unit) {
        unit = unit || ""; // Optional unit like "FPS"
        return confirm(
            "Change active comp " + propertyName + " to match Davinci " + propertyName + "?\n" +
            "Davinci " + propertyName + ": " + davinciValue + unit + "\n" +
            "Active Comp " + propertyName + ": " + aeValue + unit
        );
    }

    function addDivider(parent, color, height, margin) {
        var divider = parent.add("panel");
        divider.alignment = ["fill", "top"];
        divider.minimumSize.height = height || 1;
        divider.maximumSize.height = height || 1;
        divider.margins = margin || 0;
        if (color) {
            try {
                divider.graphics.backgroundColor = divider.graphics.newBrush(divider.graphics.BrushType.SOLID_COLOR, color);
            } catch (e) { } // Some versions of ExtendScript don't fully support custom brushes — safely ignore.
        }
        return divider;
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

            // Handle pixel aspect ratio (likely irrelevant in most workflows)
            if (layerData.pixelAspect !== undefined) {
                if (layerData.pixelAspect !== 1) {
                    if (confirm("Legacy Pixel Aspect Ratio: " + layerData.pixelAspect + " deteceted for layer: " + layerData.layerName + ".\n Change to square?")) {
                        importedItem.pixelAspect = 1;
                    } else {
                        alert("Pixel Aspect Ratio unchanged - sizing may appear incorrect.");
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
                var xScaleMultiplier = 1;
                var yScaleMultiplier = 1;
                if (layerData.flipX === "true") { xScaleMultiplier = -1; }
                if (layerData.flipY === "true") { yScaleMultiplier = -1; }
                currentLayer.scale.setValue([layerData.zoomX * 100 * xScaleMultiplier, layerData.zoomY * 100 * yScaleMultiplier]);
                currentLayer.opacity.setValue(layerData.opacity);
                // AE and Davinci rotate in opposing directions
                currentLayer.rotation.setValue(-1 * layerData.rotationAngle);
                // AE 0 position top right, Davinci 0 position in center
                var xResOffset = 0.5 * compData.resolutionWidth;
                var yResOffset = 0.5 * compData.resolutionHeight;
                currentLayer.position.setValue([layerData.pan + xResOffset, -1 * layerData.tilt + yResOffset]);
                // currentLayer.anchorPoint.setValue([layerData.anchorPointX + xResOffset, layerData.anchorPointY + yResOffset]) // - doesn't work - Resolve anchor only affects rotation
            }
        }
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

    function refreshProject() {
        var data = getJSONFileData();
        var targetRootName = CONFIG.folderNames.linkedComps;
        var linkedMatches = findFoldersByName(targetRootName, null);

        if (linkedMatches.length > 1) {
            alert("Multiple folders named '" + targetRootName + "' found. Please resolve before continuing.");
            return false;
        }

        if (linkedMatches.length === 1) {
            var foundFolder = linkedMatches[0];
            if (foundFolder.comment !== CONFIG.projectIDPrefix + data.projectid) { 
                alert("This AE project is linked to a different Motion Link Project ID.\nPlease navigate to the current project motionbridge folder by clicking Browse.");
                return false;
            }
            else {
                return true; 
            }
        }
        return false; 
    }

    function versionCheck() {
        var data = getJSONFileData();
        if (!data) return false;
        
        var scriptVersion = CONFIG.version;
        var savedVersion = data.motionBridgeVersion;
        
        if (savedVersion !== scriptVersion) {
            alert("Version mismatch detected.\n\nProject: v" + savedVersion + "\nCurrent: v" + scriptVersion + "\n\nPlease use MotionBridge v" + savedVersion + " in both AE and Resolve for this project.");
            return false;
        }
        return true;
    }

    function linkWithDavinci() {
        var data = getJSONFileData();
        if (!data || !data.compositions) {
            alert("No compositions found – please set up project in Davinci");
            return;
        }

        var exists = findCompKeyByAeID(data, activeComp.id);
        if (exists) {
            alert("Active comp '" + activeComp.name + "' already linked with Davinci Project");
            return;
        }

        for (var key in data.compositions) {
            var savedName = data.compositions[key].name;
            if (savedName === activeComp.name) {
                alert("A composition named '" + activeComp.name + "' is already linked in this project. Please rename before linking.");
                return;
            }
        }

        if (data.projectFPS !== activeComp.frameRate) { 
            if (confirmPropertyChange("frame rate", data.projectFPS, activeComp.frameRate, "FPS")) {
                activeComp.frameRate = data.projectFPS; 
                alert("Frame rate changed to: " + data.projectFPS + "FPS");
            } else {
                alert("Frame rates don't match - operation canceled");
                return false;
            }
        }

        if (activeComp.displayStartFrame !== 0) {
            if (confirm("Change comp start frame (currently: " + activeComp.displayStartFrame + ") to 0?")){
                activeComp.displayStartFrame = 0;
            }
            else {
                alert("Comp start frame must be 0 to link - operation cancelled");
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
            fps: activeComp.frameRate,
            resolutionWidth: activeComp.width,
            resolutionHeight: activeComp.height,
            duration: activeComp.duration * activeComp.frameRate, 
            compStartFrame: activeComp.displayStartFrame
        };

        getOrCreateMarkersLayer(activeComp);
        activeComp.parentFolder = linkedCompsFolder;

        writeToJSON(data, "Linked active comp as " + newKey);
    }

    function importNewComps() {
        defineJSON();
        jsonFile = new File(JSONfilePath);
        if (!jsonFile.exists) {
            alert("MotionBridge data file not found at " + jsonFile.fsName);
            return;
        }

        var data = getJSONFileData();

        // Make sure compositions exist in JSON
        if (!data.compositions) {
            alert("No compositions found in JSON.");
            return;
        }

        app.beginUndoGroup("Make Comps from JSON");
        var btnClickResult = false;
        
        for (var davinciCompID in data.compositions) {
            // Only make comp if it doesn't exist in project
            if (data.compositions[davinciCompID].aeID == null) {
                if (findCompByID(data.compositions[davinciCompID].aeID) == null) {
                    var compData = data.compositions[davinciCompID];
                    var fps = compData.fps || 24;
                    var currentComp = app.project.items.addComp(compData.name, compData.resolutionWidth, compData.resolutionHeight, 1, compData.duration / fps, fps);
                    currentComp.parentFolder = linkedCompsFolder;
                    data.compositions[davinciCompID].aeID = currentComp.id;
                    writeToJSON(data);
                    currentComp.openInViewer();
                    
                    // Import and add layers 
                    importAndAddLayers(currentComp, compData, fps);

                    // Cleanup - remove layers from json once transferred 
                    compData.layers = null; 
                    writeToJSON(data);

                    // Create markers from JSON data
                    var markersLayer = getOrCreateMarkersLayer(currentComp);
                    var markers = compData.markers;
                    for (var i = 0; i < markers.length; i++) {
                        var m = markers[i];
                        var startTime = m.recordFrame / compData.fps;
                        var myMarker = new MarkerValue(m.name + "\n" + m.note);  // \n here for some reason \r only works one way
                        myMarker.duration = m.duration / compData.fps;

                        // Color label by index, not name (mismatch between AE and Davinci)
                        myMarker.label = m.color;
                        markersLayer.property("Marker").setValueAtTime(startTime, myMarker);
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
                    writeToJSON(data, "Removed deleted composition from JSON: " + obsoleteCompName);
                    btnClickResult = true; 
                }
            }   
        }
        
        app.endUndoGroup();
        if (!btnClickResult) {alert("No new comps to link!");}
    }

    // RENDER HELPERS
    function refreshComp() {
        var data = getJSONFileData();
        if (!data) return;

        activeComp = app.project.activeItem;

        if (activeComp && activeComp instanceof CompItem) {
            var davinciID = findCompKeyByAeID(data, activeComp.id);
            if (davinciID) {
                if (fpsNameStartFrameCheck(data.compositions[davinciID]) == false) return;
                return true;
            }
            else {
                alert("Active comp " + "'" + activeComp.name + "'" + " not linked in project.\n1. Pre-link with 'Link Active Comp' button in AE \n2. Finalise link with 'Import Linked Comps' button in Davinci");
            }
        } else {
            alert("No active comp!");
            return false; 
        }
    }

    function addToQ(templateDropdown) { 
        var data = getJSONFileData();
        if (!data) return;

        if (templateDropdown.selection && 
            templateDropdown.selection.index === 0) {
            alert("Please select a valid render template from the dropdown.");
            return;
        }

        var renderQueueItem = app.project.renderQueue.items.add(activeComp);
        var outputModule = renderQueueItem.outputModules[1];
        outputModule.applyTemplate(templateDropdown.selection);

        var renderPath = outputDir.text + "/" + CONFIG.directoryNames.root + "/" + CONFIG.directoryNames.renders + "/" + activeComp.name;
        data.compositions[findCompKeyByAeID(data, activeComp.id)].renderPath = renderPath;
        data.compositions[findCompKeyByAeID(data, activeComp.id)].duration = activeComp.duration * activeComp.frameRate; // Update in case of changes
        writeToJSON(data);
        
        outputModule.file = new File(renderPath);
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
    function findOrCreateMLFolders() {
        var data = getJSONFileData();
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
            if (linkedCompsFolder.comment !== CONFIG.projectIDPrefix + data.projectid) { 
                alert("This AE project is linked to a different Motion Link Project ID");
                linkedCompsFolder = null;
                return null;
            }
        } else {
            linkedCompsFolder = app.project.items.addFolder(targetRootName);
            linkedCompsFolder.comment = CONFIG.projectIDPrefix + data.projectid;
        }

        // Now look for "0_MotionBridgeImports" inside it
        var motionBridgeMatches = findFoldersByName(targetSubName, linkedCompsFolder);

        if (motionBridgeMatches.length > 1) {
            alert("Multiple folders named '" + targetSubName + "' found within '" + targetRootName + "'. Please resolve before continuing.");
            return null;
        }

        // Create or use the one found
        importedMediaFolder = (motionBridgeMatches.length === 1) ?
            motionBridgeMatches[0] : linkedCompsFolder.items.addFolder(targetSubName);

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
                alert("Frame rate changed to: " + davinciFPS + "FPS");
            } else {
                alert("Frame rates don't match - operation canceled");
                return false;
            }
        }

        if (compData.aeID == activeComp.id) {
            if (compData.name !== activeComp.name) {
                if (confirmPropertyChange("name", compData.name, activeComp.name)) {
                    activeComp.name = compData.name; 
                    alert("Active comp renamed to: " + compData.name);
                } else {
                    alert("Names don't match - operation canceled");
                    return false;
                }
            }
            if (compData.compStartFrame !== activeComp.displayStartFrame) {
                if (confirmPropertyChange("Start Frame", compData.compStartFrame, activeComp.displayStartFrame)) {
                    activeComp.displayStartFrame = compData.compStartFrame; 
                    alert("Active comp start frame changed to: " + compData.compStartFrame);
                } else {
                    alert("Start Frames don't match - operation canceled");
                    return false;
                }
            }
        }

        return true; 
    }

    function getOrCreateMarkersLayer(comp) {
        for (var i = 1; i <= comp.numLayers; i++) {
            if (comp.layer(i).name === markersLayerName) { 
                return comp.layer(i);
            }
        }
        var layer = comp.layers.addNull();
        layer.name = markersLayerName;
        return layer;
    }

    function getMarkersDataFromLayer(layer, fps) {
        var markers = [];
        var markerProp = layer.property("Marker");
        
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
            
            // Handle markers starting before 0 (Doesn't exist in Davinci)
            var recordFrame = Math.round(keyTime * fps);
            var duration = Math.round(markerValue.duration * fps);
            if (recordFrame < 0) {
                duration = duration + recordFrame; // subtraction because it's negative
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
        var data = getJSONFileData();
        if (!data) return;

        var compData = data.compositions[findCompKeyByAeID(data, activeComp.id)];
        var markersLayer = getOrCreateMarkersLayer(activeComp);

        while (markersLayer.property("Marker").numKeys > 0) {
            markersLayer.property("Marker").removeKey(1);
        }

        var markers = compData.markers;
        for (var i = 0; i < markers.length; i++) {
            var m = markers[i];
            var startTime = m.recordFrame / compData.fps;
            var duration = m.duration / compData.fps;
            
            var myMarker = new MarkerValue(m.name + "\n" + m.note);  // \n here for some reason \r only works one way
            myMarker.duration = duration;
            myMarker.label = m.color;
            
            markersLayer.property("Marker").setValueAtTime(startTime, myMarker);
        }
        alert((markers.length || 0) + " markers imported to " + activeComp.name);
    }

    function exportMarkers() {
        var data = getJSONFileData();
        if (!data) return;

        var markersLayer = getOrCreateMarkersLayer(activeComp);
        if (!markersLayer) {
            alert("No markers layer found!");
            return;
        }

        var markers = getMarkersDataFromLayer(markersLayer, activeComp.frameRate);

        // Sanitise marker text
        for (var i = 0; i < markers.length; i++) {
            var mm = markers[i];
            if (mm.name) mm.name = mm.name.replace(/\r?\n/g, "\\n");
            if (mm.note) mm.note = mm.note.replace(/[\r\n]+/g, " ").replace(/\\/g, "\\\\").replace(/"/g, '\\"');
        }

        data.compositions[findCompKeyByAeID(data, activeComp.id)].markers = markers;

        writeToJSON(data, markers.length + " markers exported from " + activeComp.name);
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

    // JSON HELPERS //
    function defineJSON() {
        if (typeof JSON === 'undefined') {
            JSON = {
                parse: function (sJSON) { return eval('(' + sJSON + ')'); },
                stringify: function (vContent) {
                    if (vContent instanceof Object) {
                        var sOutput = "";
                        if (vContent.constructor === Array) {
                            for (var nId = 0; nId < vContent.length; sOutput += this.stringify(vContent[nId]) + ",", nId++);
                            return "[" + sOutput.substr(0, sOutput.length - 1) + "]";
                        }
                        if (vContent.toString !== Object.prototype.toString) { return "\"" + vContent.toString().replace(/"/g, "\\$&") + "\""; }
                        for (var sProp in vContent) {
                            sOutput += "\"" + sProp.replace(/"/g, "\\$&") + "\":" + this.stringify(vContent[sProp]) + ",";
                        }
                        return "{" + sOutput.substr(0, sOutput.length - 1) + "}";
                    }
                    return typeof vContent === "string" ? "\"" + vContent.replace(/"/g, "\\$&") + "\"" : String(vContent);
                }
            };
        }
    }

    function writeToJSON(data, successMessage) {
        if (!data) {
            alert("No data provided to writeToJSON()");
            return false;
        }

        try { jsonFile.encoding = "UTF-8"; } catch (e) {}
        jsonFile.lineFeed = ($.os && $.os.indexOf("Windows") !== -1) ? "Windows" : "Unix";

        if (!jsonFile.open('w')) {
            alert("Unable to open JSON file for writing");
            return false;
        }

        try {
            var jsonString = JSON.stringify(data, null, 4);
            jsonFile.write(jsonString + "\n");
        } catch (e) {
            alert("Error writing JSON: " + e.toString());
            jsonFile.close();
            return false;
        }

        jsonFile.close();

        if (successMessage) alert(successMessage);
        return true;
    }

    function getJSONFileData() {
        if (!jsonFile.exists) {
            alert("JSON file not found!");
            return false;
        }
        
        jsonFile.open('r');
        var jsonData = jsonFile.read();
        jsonFile.close();
        
        var data;
        try {
            data = JSON.parse(jsonData);
            return data;
        } catch (e) {
            alert("Error parsing JSON: " + e.message);
            return false;
        }
    }
}
MotionBridge(this);