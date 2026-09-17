/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// ScratchOnline.as
// Who knows?
//
// Online wrapper around the top-level application.

package {
import blocks.Block;
import blocks.BlockIO;

import by.blooddy.crypto.MD5;

import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.Loader;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.MouseEvent;
import flash.events.SecurityErrorEvent;
import flash.external.ExternalInterface;
import flash.geom.Point;
import flash.net.URLRequest;
import flash.net.navigateToURL;
import flash.system.Security;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.setTimeout;

import interpreter.InterpreterOnline;
import interpreter.PersistenceManager;

import logging.LogEntry;
import logging.LogLevel;

import mx.utils.URLUtil;

import scratch.PaletteBuilder;
import scratch.PaletteBuilderOnline;
import scratch.ScratchComment;
import scratch.ScratchCostume;
import scratch.ScratchObj;
import scratch.ScratchRuntimeOnline;
import scratch.ScratchSound;
import scratch.ScratchSprite;
import scratch.ScratchStage;
import scratch.ScratchStageOnline;

import translation.TranslatableStrings;
import translation.Translator;

import ui.media.MediaInfo;
import ui.media.MediaInfoOnline;
import ui.media.MediaLibrary;
import ui.media.MediaLibraryOnline;
import ui.media.MediaPane;
import ui.media.MediaPaneOnline;
import ui.parts.BackpackPart;
import ui.parts.ImagesPartOnline;
import ui.parts.LibraryPart;
import ui.parts.LibraryPartOnline;
import ui.parts.ScriptsPartOnline;
import ui.parts.StagePart;
import ui.parts.StagePartOnline;
import ui.parts.TopBarPartOnline;

import uiwidgets.DialogBox;
import uiwidgets.IconButton;
import uiwidgets.Menu;
import uiwidgets.VariableSettingsOnline;

import util.Base64Encoder;
import util.CachedTimer;
import util.JSON;
import util.MediaLibBuilder;
import util.ProjectIOOnline;
import util.ServerOnline;

import watchers.ListWatcher;

public class ScratchOnline extends Scratch {
	public static var app:ScratchOnline; // static reference to the app, used for debugging

	// Persistence manager
	public var persistenceManager:PersistenceManager;
	public var usesPersistentData:Boolean;
	public var userName:String = "";
	public var persistentDataCount:int = 0;

	// Server
	public var serverSettingsReady:Boolean = true;
	public var serverSettings:Object;
	public var session:Object;
	public var isEmbedded:Boolean;

	// UI Parts
	private var topBarOnline:TopBarPartOnline;
	private var scriptsPartOnline:ScriptsPartOnline;
	public var stagePaneOnline:ScratchStageOnline;
	private var imagesPartOnline:ImagesPartOnline;
	public var backpackPart:BackpackPart;

	private var tipsWereOpen:Boolean = false;
	private var wasLoggedOut:Boolean = false;

	// Online stuff
	public var serverOnline:ServerOnline;
	private var editAfterLoad:Boolean;
	private const SENTRY_SEVERITY:int = LogLevel.LEVEL.indexOf(LogLevel.ERROR);
	private var remixRequested:Boolean = false;
	private var copyRequested:Boolean = false;

	// Autosave
	private var saveFailDialog:DialogBox;
	private var saveTimerContext:Dictionary = new Dictionary();
	private const MIN_AUTO_SAVE_INTERVAL:int = 120000;
	private const SAVE_CHECK_INTERVAL:int = 5000;
	private var autosaveInterval:int = 120000;
	private var lastCheckTime:int;
	private var nextSaveTime:int;
	private var lastSaveFailed:Boolean;
	private var saveRetryDelay:int;
	private var saveFailureTolerance:int = 3;
	private var saveInProgress:Boolean;
	private var saveStatus:String = "";
	private var saveStatusAlert:Boolean = false;
	private var originalProjOnServer:Boolean;

	override protected function initialize():void {
		Scratch.app = ScratchOnline.app = this;
		isArmCPU = jsEnabled && ExternalInterface.call("window.navigator.userAgent.toString").indexOf("CrOS arm") > -1;
		server = this.serverOnline = new ServerOnline();
		this.persistenceManager = new PersistenceManager(this);
		this.isEmbedded = this.checkEmbedded();
		super.initialize();
		this.log(LogLevel.INFO, "SWF Initialized", {"version":versionString});
	}

	override protected function initTopBarPart():void {
		topBarPart = this.topBarOnline = new TopBarPartOnline(this, this.isEmbedded);
	}

	override protected function initScriptsPart():void {
		scriptsPart = this.scriptsPartOnline = new ScriptsPartOnline(this);
	}

	override protected function initImagesPart():void {
		imagesPart = this.imagesPartOnline = new ImagesPartOnline(this);
	}

	override protected function initInterpreter():void {
		interp = new InterpreterOnline(this);
	}

	override protected function initRuntime():void {
		runtime = new ScratchRuntimeOnline(this, interp);
	}

	override protected function initServer():void {
		// The Server object is already initialized in initialize()
	}

	override protected function getStagePart():StagePart {
		return new StagePartOnline(this);
	}

	override protected function getLibraryPart():LibraryPart {
		return new LibraryPartOnline(this);
	}

	override public function getMediaPane(app:Scratch, type:String):MediaPane {
		return new MediaPaneOnline(app, type);
	}

	override public function getMediaLibrary(type:String, whenDone:Function):MediaLibrary {
		return new MediaLibraryOnline(this, type, whenDone);
	}

	override public function getScratchStage():ScratchStage {
		return new ScratchStageOnline();
	}

	override public function strings():Array {
		var strings:Array = [
			'Account settings',
			'Because you have a new Scratch account, any changes to cloud data won\'t be saved yet. Keep participating on the site you\'ll be able to use cloud data soon!',
			'Can’t find network connection or reach server.',
			'Click "Save now" to try again or "Download" to save',
			'Copying...',
			'Creating...',
			'Download',
			'Go to My Stuff',
			'My Class',
			'My Classes',
			'My Stuff',
			'Not saved; network or server problem.',
			'Profile',
			'Remixing...',
			'Save as a copy',
			'Saving...',
			'Sign in to save',
			'Sign out',
			'This project uses Cloud data ‒ a feature that is available only to signed in users.',
			'Want to save? Click remix'
		];

		// TODO: Find a way to make this cleaner
		return super.strings().concat(strings).concat(ProjectIOOnline.strings()).concat(PersistenceManager.strings()).concat(TopBarPartOnline.strings()).concat(VariableSettingsOnline.strings());
	}

	override protected function addParts():void {
		super.addParts();
		this.backpackPart = new BackpackPart(this);
		addChild(this.backpackPart);
	}

	override protected function startInEditMode():Boolean {
		return Boolean(super.startInEditMode()) || this.isEmbedded || loaderInfo.parameters["project_isNew"] == "true";
	}

	override public function presentationModeWasChanged(enterPresentation:Boolean):void {
		super.presentationModeWasChanged(enterPresentation);
		this.jsSetPresentationMode(enterPresentation);
		this.closeTips();
	}

	override protected function shouldShowGreenFlag():Boolean {
		return Boolean(super.shouldShowGreenFlag()) || this.isEmbedded;
	}

	override public function setEditMode(newMode:Boolean):void {
		if (newMode && loadInProgress) {
			this.editAfterLoad = true;
			return;
		}
		super.setEditMode(newMode);
		if (editMode && !isMicroworld) {
			show(this.backpackPart);
		} else {
			hide(this.backpackPart);
		}
		this.jsSetFlashDragDrop(editMode);
		this.jsCaptureRightClick();
		this.refreshCloudLists();
	}

	override protected function updateContentArea(contentX:int, contentY:int, contentW:int, contentH:int, fullH:int):void {
		this.backpackPart.openAmount = this.isLoggedIn() && this.backpackPart.visible ? int(Math.max(this.backpackPart.closedHeight, this.backpackPart.openAmount)) : 0;
		contentH -= this.backpackPart.openAmount;
		super.updateContentArea(contentX, contentY, contentW, contentH, fullH);
		this.backpackPart.x = contentX;
		this.backpackPart.y = fullH - this.backpackPart.openAmount - 1;
		this.backpackPart.setWidthHeight(contentW, this.backpackPart.fullHeight);
	}

	override public function createMediaInfo(obj:*, owningObj:ScratchObj = null):MediaInfo {
		return new MediaInfoOnline(obj, owningObj);
	}

	override public function translationChanged():void {
		super.translationChanged();
		this.backpackPart.updateTranslation();
	}

	override protected function canExportInternals():Boolean {
		return !this.isEmbedded;
	}

	override protected function addEditMenuItems(b:*, m:Menu):void {
		if ((b as IconButton).lastEvent.shiftKey && this.canExportInternals()) {
			m.addLine();
			m.addItem("Export translation strings: commands", TranslatableStrings.exportCommands);
			m.addItem("Export translation strings: UI", TranslatableStrings.exportUIStrings);
			m.addItem("Export help screen names", TranslatableStrings.exportHelpScreenNames);
			m.addLine();
			m.addItem("Edit block colors", editBlockColors);
			m.addLine();
			m.addItem("MediaLib - media", MediaLibBuilder.exportMedia);
			m.addItem("MediaLib - sprites", MediaLibBuilder.exportSprites);
			m.addItem("MediaLib - check JSON file", MediaLibBuilder.checkJSONFile);
		}
	}

	public function isScratcher():Boolean {
		return this.isLoggedIn() && Boolean(this.serverSettings) && Boolean(this.serverSettings.user_groups) && this.serverSettings.user_groups.indexOf("Scratchers") > -1;
	}

	override public function loadProjectFailed():void {
		super.loadProjectFailed();

		// Add grey background
		var bg:Shape = new Shape();
		bg.graphics.beginFill(13421772);
		bg.graphics.drawRect(-1000, -1000, 10000, 10000);
		stage.addChild(bg);

		if (editMode) {
			DialogBox.notify("Error!", "The project failed to load\nand the Scratch Team has been notified.\nPress OK to leave this page.", stage, false, this.leavePage);
		} else {
			DialogBox.notify("Error!", "The project failed to load\nand the Scratch Team has been notified.", stage, false, this.leavePage);
		}
	}

	private function leavePage(ignore:*):void {
		ExternalInterface.call("window.eval", "document.location.hash = \"player\";");
		setTimeout(function():void {
			DialogBox.notify("Error!", "The project failed to load\nand the Scratch Team has been notified.", stage, false, leavePage);
		}, 100);
	}

	/*
	override public function logException(e:Error):void {
		logger.log(LogLevel.ERROR, e.toString());
	}

	override public function log(severity:String, messageKey:String, extraData:Object = null):LogEntry {
		var entry:LogEntry = super.log(severity, messageKey, extraData);
		return entry;
	}
	*/

	public function logImageImported(filename:String, param2:Boolean):void { // TODO: Param
		var index:int = filename.indexOf(".");
		if (index > 0) filename = filename.slice(index).toLowerCase();

		externalCall("JSlogImageAdded", null, Scratch.app.projectID, filename, !param2);
	}

	override protected function addFileMenuItems(b:*, m:Menu):void {
		function saveNow():void {
			if (shouldSave()) {
				saveProject(true);
			}
		}

		function saveAsACopy():void {
			copyRequested = true;
			saveProject(true);
		}

		function goToMyStuff():void {
			saveAndRedirectTo("mystuff");
		}

		if (this.isLoggedIn()) {
			if (this.canSave()) {
				m.addItem("Save now", saveNow);
			}
			if (this.userName == projectOwner) {
				m.addItem("Save as a copy", saveAsACopy);
			}
			m.addItem("Go to My Stuff", goToMyStuff);
			m.addLine();
		}

		if (this.isLoggedIn() && projectOwner == this.userName) {
			if (runtime.recording || runtime.ready >= 0) {
				m.addItem("Download to your computer", exportProjectToFile);
				m.addLine();
				m.addItem("Stop Video", runtime.stopVideo);
			} else {
				m.addItem("Upload from your computer", runtime.selectProjectFile);
				m.addItem("Download to your computer", exportProjectToFile);
				m.addLine();
				m.addItem("Record & Export Video", runtime.exportToVideo);
			}
		} else {
			m.addItem("Upload from your computer", runtime.selectProjectFile);
			m.addItem("Download to your computer", exportProjectToFile);
			m.addLine();
		}

		if (canUndoRevert()) {
			m.addItem("Undo Revert", undoRevert);
		} else if (canRevert()) {
			m.addItem("Revert", revertToOriginalProject);
		}

		if (b.lastEvent.shiftKey) {
			m.addLine();
			m.addItem("Save Project Summary", saveSummary);
			m.addItem("Show version details", showVersionDetails);
		}
	}

	override protected function makeVersionDetailsDialog():DialogBox {
		var d:DialogBox = super.makeVersionDetailsDialog();
		d.addField("scratch-flash-online", kGitHashFieldWidth, SCRATCH::revisionOnline);
		return d;
	}

	override protected function handleStartupParameters():void {
		var project:String = loaderInfo.parameters["project"];
		var project_id:String = loaderInfo.parameters["project_id"];
		var autostart_str:String = loaderInfo.parameters["autostart"];
		var projIO:ProjectIOOnline = new ProjectIOOnline(this);

		if (project) {
			autostart = true;
			if (autostart_str != null) {
				autostart = autostart_str.toLowerCase() == "true";
			}
			this.serverSettingsReady = true;
			this.setupExternalInterface(true);
			projIO.fetchOldProjectURL(project);
		} else if (project_id) {
			autostart = false;
			if (loaderInfo.parameters["project_isNew"] == "true") {
				this.createProjectFromJS(loaderInfo.parameters["project_creator"], project_id, loaderInfo.parameters["project_title"]);
			} else {
				autostart = Boolean(autostart_str) && autostart_str.toLowerCase() == "true";
				this.projectID = project_id;
				projectOwner = loaderInfo.parameters["project_creator"];
				projectIsPrivate = loaderInfo.parameters["project_isPublished"] != "true";

				setProjectName(loaderInfo.parameters["project_title"]);

				var modifiedDate:String = loaderInfo.parameters["project_modifiedDate"] ? MD5.hash(loaderInfo.parameters["project_modifiedDate"]) : null;
				projIO.fetchProject(projectOwner, project_id, modifiedDate);
			}
			this.backpackPart.loadBackpack();
			this.setupExternalInterface(false);
			this.jsCaptureRightClick();
			isSmallPlayer = stage.width < 400;
			jsEditorReady();
		} else {
			this.setupExternalInterface(false);
			this.jsCaptureRightClick();
			isSmallPlayer = stage.width < 400;
			jsEditorReady();
		}

		if (loaderInfo.parameters["debugOps"] != null && loaderInfo.parameters["debugOpCmd"] != null) {
			debugOps = loaderInfo.parameters["debugOps"] == "true";
			debugOpCmd = loaderInfo.parameters["debugOpCmd"];
		}
	}

	override protected function step(e:Event):void {
		super.step(e);
		if (editMode) {
			this.checkForAutoSave();
		}
	}

	override public function projectLoaded():void {
		super.projectLoaded();
		this.updateSaveStatus();
		if (this.usesPersistentData) {
			if (this.isLoggedIn()) {
				if (Boolean(this.serverSettings) && Boolean(this.serverSettings.user_groups)) {
					if (this.serverSettings.user_groups.indexOf("Scratchers") > -1) {
						this.persistenceManager.connect(this.serverSettings.cloud_data_host);
					} else {
						this.jsSetProjectBanner("Because you have a new Scratch account, any changes to cloud data won't be saved yet. Keep participating on the site you'll be able to use cloud data soon!");
					}
				}
			} else {
				this.jsSetProjectBanner("This project uses Cloud data ‒ a feature that is available only to signed in users.");
			}
		}
		this.jsReportStats();
		if (!editMode && this.editAfterLoad) {
			this.editAfterLoad = false;
			this.setEditMode(true);
		}
	}

	public function shareButtonPressed(ignore:*):void {
		function saveDone():void {
			jsShareProject();
			projectIsPrivate = false;
			stagePart.refresh();
			topBarPart.refresh();
		}

		if (runtime.hasUnofficialExtensions()) {
			// ScratchX projects can't be shared on the main website
			DialogBox.notify("Not Allowed to Share", "This project uses experimental extensions and cannot be shared on the website.", Scratch.app.stage);
			return;
		}
		if (this.canSave()) {
			// saveDone is defined above
			this.saveProject(true, saveDone);
		}
	}

	public function returnToProjectPage(ignore:*):void {
		function showProjectPage():void {
			jsSetEditMode(false);
		}

		if (this.shouldSave()) {
			// showProjectPage is defined above
			this.saveProject(true, showProjectPage);
		} else {
			showProjectPage();
		}
	}

	public function myStuffPressed(ignore:*):void {
		this.saveAndRedirectTo("mystuff");
	}

	override public function logoButtonPressed(menuButton:IconButton):void {
		if (this.isEmbedded || isOffline) {
			navigateToURL(new URLRequest(hostProtocol + "://scratch.mit.edu"));
		} else {
			this.saveAndRedirectTo("home");
		}
	}

	public function saveAndRedirectTo(where:String):void {
		function saveDone():void {
			jsRedirectTo(where);
		}

		if (this.shouldSave()) {
			// saveDone is defined above
			this.saveProject(true, saveDone);
		} else {
			this.jsRedirectTo(where);
		}
	}

	public function isLoggedIn():Boolean {
		return this.userName != null && this.userName != "" && !this.wasLoggedOut;
	}

	public function signInPressed(menuButton:IconButton):void {
		if (this.isLoggedIn()) {
			this.showSignInMenu(menuButton);
		} else {
			this.jsSignIn("save", this.userName);
		}
	}

	public function joinPressed(menuButton:IconButton):void {
		this.jsJoinScratch("save");
	}

	protected function showSignInMenu(menuButton:IconButton):void {
		function goToProfile():void {
			saveAndRedirectTo("profile");
		}
		function goToMyStuff():void {
			saveAndRedirectTo("mystuff");
		}
		function goToMyClasses():void {
			saveAndRedirectTo("myclasses");
		}
		function goToMyClass():void {
			saveAndRedirectTo("myclass");
		}
		function goToAccountSettings():void {
			saveAndRedirectTo("settings");
		}
		function goToLogout():void {
			if (shouldSave()) {
				saveProject(true, jsSignOut);
			} else {
				jsSignOut();
			}
		}

		this.closeTips();

		var m:Menu = new Menu(null, "Sign in", CSS.topBarColor(), 28);
		m.addItem("Profile", goToProfile);
		m.addItem("My Stuff", goToMyStuff);

		if (this.session.permissions["educator"]) {
			m.addItem("My Classes", goToMyClasses);
		}
		if (this.session.permissions["student"]) {
			m.addItem("My Class", goToMyClass);
		}

		m.addItem("Account settings", goToAccountSettings);
		m.addLine();
		m.addItem("Sign out", goToLogout);
		m.showOnStage(stage, Math.min(menuButton.x, topBarPart.w - m.width - 5), topBarPart.bottom() - 1);
	}

	private function getServerSettings():void {
		function gotSettings(response:String):void {
			serverSettings = response ? util.JSON.parse(response) : {};
			var interval:int = 1000 * int(serverSettings["autosave_interval"]);
			autosaveInterval = Math.max(interval, MIN_AUTO_SAVE_INTERVAL);
			serverOnline.getSession(gotSession);
		}

		function gotSession(response:String):void {
			session = response ? util.JSON.parse(response) : {};
			session.flags = session.flags || {};
			session.permissions = session.permissions || {};
			session.user = session.user || {};
			topBarOnline.refresh();
			serverSettingsReady = true;
		}

		this.serverSettingsReady = false;
		this.serverOnline.getSettings(gotSettings);
	}

	override public function getPaletteBuilder():PaletteBuilder {
		return new PaletteBuilderOnline(this);
	}

	public function isCloudDataEnabled():Boolean {
		if (!this.serverSettings) {
			return false;
		}

		return this.serverSettings.cloud_data_enabled;
	}

	public function isUserStaff():Boolean {
		if (!this.serverSettings) {
			return false;
		}

		return this.serverSettings.user_admin;
	}

	private function jsReportStats():void {
		if (jsEnabled) {
			ExternalInterface.call("JSsetProjectStats", stagePane.scriptCount(), stagePane.spriteCount(), this.usesPersistentData, oldWebsiteURL);
		}
	}

	public function getProjectURL():String {
		// Passthrough to ServerOnline
		return this.serverOnline.getProjectURL();
	}

	private function checkEmbedded():Boolean {
		if (jsEnabled) {
			return ExternalInterface.call("JSeditorIsEmbedded");
		}

		return false;
	}


	// -----------------------------
	// Javascript calls
	//------------------------------

	private function jsCaptureRightClick():void {
		if (jsEnabled) {
			ExternalInterface.call("JScaptureRightClick", true);
		}
	}

	public function jsEditTitle():void {
		if (jsEnabled) {
			ExternalInterface.call("JSeditTitle", projectName());
		}
	}

	private function jsSetEditMode(inEditor:Boolean):void {
		if (jsEnabled) {
			var response:Boolean = ExternalInterface.call("JSsetEditMode", inEditor);

			if (!response) {
				jsThrowError("Calling JSsetEditMode() failed.");
			}
		}
	}

	private function jsIsUniqueTitle(title:String):void {
		// Unused, not defined in scratch_app.js
		if (jsEnabled) {
			ExternalInterface.call("JSisUniqueTitle", title);
		}
	}

	public function jsOpenMediaLibrary(unused:String):void {
		// Unused, not defined in scratch_app.js
		if (jsEnabled) {
			ExternalInterface.call("JSopenMediaLibrary", unused);
		}
	}

	private function jsSignIn(operation:String = "", username:String = ""):void {
		if (jsEnabled) {
			ExternalInterface.call("JSlogin", operation, username);
		}
	}

	private function jsJoinScratch(operation:String = ""):void {
		if (jsEnabled) {
			ExternalInterface.call("JSjoinScratch", operation);
		}
	}

	private function jsSignOut():void {
		if (jsEnabled) {
			ExternalInterface.call("JSlogout");
		}
	}

	private function jsShareProject():void {
		if (jsEnabled) {
			ExternalInterface.call("JSshareProject");
		}
	}

	private function jsRedirectTo(where:String, editor:Boolean = false):void {
		if (jsEnabled) {
			var project:Object = {
				"creator": this.userName,
				"id": this.projectID,
				"isPrivate": this.projectIsPrivate,
				"title": this.projectName()
			};

			ExternalInterface.call("JSredirectTo", where, editor, project);
		}
	}

	private function jsSetFlashDragDrop(enabled:Boolean):void {
		if (jsEnabled) {
			ExternalInterface.call("JSsetFlashDragDrop", enabled);
		}
	}

	public function jsSetPresentationMode(enabled:Boolean):void {
		if (jsEnabled) {
			var response:Boolean = ExternalInterface.call("JSsetPresentationMode", enabled);

			if (!response) {
				jsThrowError("Calling JSsetPresentationMode() failed.");
			}
		}
	}


	// -----------------------------
	// Remixing / Saving
	//------------------------------

	public function openInScratch(menuButton:IconButton):void {
		if (!ScratchOnline.app.isLoggedIn()) {
			this.jsSignIn("openInScratch", this.userName);
		} else {
			ScratchOnline.app.remixProjectFromJS();
		}
	}

	public function remixButtonPressed(ignore:* = null):void {
		if (!this.isLoggedIn()) {
			this.jsSignIn("remix", this.userName);
			return;
		}
		ExternalInterface.call("JSremixProject");
	}

	public function remixProjectFromJS():void {
		function saveDone():void {
			projectIsPrivate = true;
			stagePart.refresh();
			topBarPart.refresh();
		}

		if (!loadInProgress) {
			this.remixRequested = true;
			this.saveProject(true, saveDone);
		}
	}

	public function saveStatusClicked(ignore:*):void {
		if (!saveNeeded) {
			return;
		}

		if (projectOwner.length > 0 && projectOwner != this.userName) {
			this.remixButtonPressed(null);
		} else if (!this.isLoggedIn()) {
			this.jsSignIn("save", this.userName);
		} else if (this.shouldSave()) {
			this.saveProject(true);
		}
	}

	public function showSaveFailDialog(show:Boolean):void {
		function tryAgain():void {
			if (shouldSave()) {
				saveProject(true);
			}
		}

		if (show == (this.saveFailDialog != null)) return;
		if (show) {
			this.saveFailDialog = new DialogBox();
			this.saveFailDialog.leftJustify = true;
			this.saveFailDialog.addTitle("Project not saved!");
			this.saveFailDialog.addText("Changes not saved yet; network not connecting.\n" + "Trying again in {sec}...\n\n" + "Click \"Save now\" to try again or \"Download\" to save\n" + "a copy of the project file on your computer.");
			this.saveFailDialog.addButton("Save now", tryAgain);
			this.saveFailDialog.addButton("Download", exportProjectToFile);
			this.saveFailDialog.showOnStage(stage);
		} else {
			this.saveFailDialog.cancel();
			this.saveFailDialog = null;
		}
	}

	public function handleExternalLogout():void {
		if (!this.isLoggedIn() || !editMode) return;

		this.wasLoggedOut = true;
		this.setSaveNeeded(true);
		this.jsSetProjectBanner("You need to <a href=\"javascript:JSlogin(\'save\', \'" + this.userName + "\')\">sign in</a> as " + this.userName + ". Or you can <a href=\"javascript:JSdownloadProject()\">download your project</a> and save it on your computer.", true);
		this.refreshUserAndProject();
		this.clearSaveInProgress(false);
		this.updateSaveStatus();
	}

	public function dropMediaInfo(item:MediaInfo):Boolean {
		function addSpriteCostumes(item:ScratchSprite):void {
			var costume:ScratchCostume;

			for each (costume in item.costumes) {
				addCostume(costume.duplicate());
			}
		}

		if (!(item is MediaInfoOnline) || !(item as MediaInfoOnline).fromBackpack) {
			return false;
		}

		if (item.objType == "image") {
			this.fetchAndAddCostume(item.md5, item.objName, item.objWidth);
		} else if (item.objType == "sound") {
			this.fetchAndAddSound(item.md5, item.objName);
		} else if (item.mycostume) {
			addCostume(item.mycostume.duplicate());
		} else if (item.mysound) {
			addSound(item.mysound.duplicate());
		} else if (item.scripts) {
			if (!isShowing(scriptsPart as DisplayObject) || !scriptsPane.hitTestPoint(item.x, item.y)) {
				return false;
			}
			this.addScriptsFromBackpack(item);
		} else if (item.mysprite) {
			addSpriteCostumes(item.mysprite);
		} else if (item.objType == "sprite") {
			new ProjectIOOnline(this).fetchSprite(item.md5, addSpriteCostumes);
		}

		return true;
	}

	private function addScriptsFromBackpack(item:MediaInfo):void {
		if (isShowing(scriptsPart as DisplayObject)) {
			var p:Point = scriptsPane.globalToLocal(new Point(item.x, item.y));
		} else {
			var p:Point = new Point(50, 50);
		}
		var objects:Array = [];
		for each (var script:* in item.scripts) {
			var obj:DisplayObject;

			if (script is Block) obj = BlockIO.arrayToStack(BlockIO.stackToArray(script));
			if (script is ScratchComment) obj = ScratchComment.fromArray(script.toArray());

			if (obj) {
				obj.x = p.x;
				obj.y = p.y;
				p.y += obj.height;
				objects.push(obj);
				scriptsPane.addChild(obj);
			}
		}
		scriptsPane.updateSize();
		scriptsPane.saveScripts();
		setTab("scripts");
	}

	public function fetchAndAddCostume(id:String, costumeName:String, width:int = 0):void {
		new ProjectIOOnline(this).fetchImage(id, costumeName, width, addCostume);
	}

	public function fetchAndAddSound(id:String, sndName:String):void {
		new ProjectIOOnline(this).fetchSound(id, sndName, addSound);
	}

	private function checkForAutoSave():void {
		if (isOffline) return;

		var nextSaveIn:int = this.nextSaveTime - CachedTimer.getCachedTimer();
		var seconds:int = int(Math.max((nextSaveIn + 999) / 1000, 0));

		if (this.saveTimerContext["sec"] != seconds) {
			this.saveTimerContext["sec"] = seconds;
			this.topBarOnline.setSaveStatus(this.saveStatus, this.saveStatusAlert, this.saveTimerContext);
			if (this.saveFailDialog) {
				this.saveFailDialog.updateContext(this.saveTimerContext);
			}
		}
		if (CachedTimer.getCachedTimer() - this.lastCheckTime < 5000) return;

		this.lastCheckTime = CachedTimer.getCachedTimer();
		if (saveNeeded && !this.saveInProgress && nextSaveIn <= 0 && interp.threadCount() == 0 && this.shouldSave()) {
			this.saveProject(false);
		} else if (!this.lastSaveFailed) {
			this.updateSaveStatus();
		}
	}

	override public function handleTool(tool:String, evt:MouseEvent):void {
		super.handleTool(tool, evt);
		if (tool == "help") {
			this.showTip("scratchUI");
		}
	}

	// -----------------------------
	// Tips
	//------------------------------

	override public function showTip(tipName:String):void {
		if (this.isEmbedded) navigateToURL(new URLRequest(hostProtocol + "://scratch.mit.edu/help/"));
		if (jsEnabled) ExternalInterface.call("tip_bar_api.open", tipName);
	}

	override public function closeTips():void {
		if (jsEnabled) {
			this.tipsWereOpen = ExternalInterface.call("tip_bar_api.close");
		}
	}

	override public function reopenTips():void {
		if (jsEnabled && this.tipsWereOpen) {
			ExternalInterface.call("tip_bar_api.open");
			this.tipsWereOpen = false;
		}
	}

	override public function tipsWidth():int {
		return this.isEmbedded ? 0 : tipsBarClosedWidth;
	}

	public function getLoadTimeCloudToken():String {
		return loaderInfo.parameters["cloudToken"];
	}

	public function getCdnToken():String {
		return loaderInfo.parameters["cdnToken"];
	}

	public function jsSetProjectBanner(content:String, unused:Boolean = false):void {
		// The second parameter is unused in project_base.js

		if (jsEnabled) {
			ExternalInterface.call("JSsetProjectBanner", Translator.map(content), unused);
		}
	}

	override protected function setupExternalInterface(oldWebsitePlayer:Boolean):void {
		// Oh, nice, r2.scr.chipmunk.land isn't on here!
		if (!isOffline) {
			Security.allowDomain("scratch.mit.edu");
			Security.allowDomain("cdn.scratch.mit.edu");
			Security.allowDomain("staging.scratch.mit.edu");
			Security.allowDomain("scratch.ly");
			Security.allowDomain("*.scratch.ly");
			Security.allowDomain("github.io");
			Security.allowDomain("localhost");
		}
		super.setupExternalInterface(oldWebsitePlayer);
		if (!jsEnabled) return;

		if (oldWebsitePlayer) {
			try {
				ExternalInterface.addCallback("ASloadProject", this.loadProjectFromJS);
				ExternalInterface.addCallback("ASversion", function():String { return versionString; });
			}
			catch (error:Error) {}
		} else {
			try {
				ExternalInterface.addCallback("AScreateProject", this.createProjectFromJS);
				ExternalInterface.addCallback("ASdownload", this.downloadFromJS);
				ExternalInterface.addCallback("ASdropFile", this.addFileFromJS);
				ExternalInterface.addCallback("ASdropURL", this.addURLFromJS);
				ExternalInterface.addCallback("ASisEditMode", function():Boolean { return editMode; });
				ExternalInterface.addCallback("ASisEmpty", function():Boolean { return stagePane.isEmpty(); });
				ExternalInterface.addCallback("ASisUnchanged", function():Boolean{ return !saveNeeded && !saveInProgress; });
				ExternalInterface.addCallback("ASloadProject", this.loadProjectFromJS);
				ExternalInterface.addCallback("ASdumpRecordThumbnail", this.dumpRecordThumbnailFromJS);
				ExternalInterface.addCallback("ASremixProject", this.remixProjectFromJS);
				ExternalInterface.addCallback("ASrightMouseDown", gh.rightMouseDown);
				ExternalInterface.addCallback("ASshouldSave", this.shouldSave);
				ExternalInterface.addCallback("ASsetEditMode", this.setEditMode);
				ExternalInterface.addCallback("ASsetEmbedMode", this.setSmallPlayerMode);
				ExternalInterface.addCallback("ASsetPresentationMode", setPresentationMode);
				ExternalInterface.addCallback("ASsetLoginUser", this.setUserFromJS);
				ExternalInterface.addCallback("ASsetNewProject", this.setNewProjectFromJS);
				ExternalInterface.addCallback("ASsetShared", this.setSharedFromJS);
				ExternalInterface.addCallback("ASsetTitle", stagePart.setProjectName);
				ExternalInterface.addCallback("ASstartRunning", this.startFromJS);
				ExternalInterface.addCallback("ASstopRunning", this.stopFromJS);
				ExternalInterface.addCallback("ASgetProjectJSON", this.getProjectJSONJS);
				ExternalInterface.addCallback("ASsetBackpack", this.setBackpack);
				ExternalInterface.addCallback("ASversion", function():String { return versionString; });
				ExternalInterface.addCallback("ASwasEdited", function():Boolean { return wasEdited; });
				ExternalInterface.addCallback("AScanShare", function():Boolean { return !runtime.hasUnofficialExtensions(); });
				ExternalInterface.addCallback("ASexportProject", function():void { openInScratch(null); });
			}
			catch (error:Error) {}
		}
	}

	private function refreshCloudLists():void {
		var uiLayer:Sprite = app.stagePane.getUILayer();

		for (var i:int = 0; i < uiLayer.numChildren; i++) {
			var lw:ListWatcher = uiLayer.getChildAt(i) as ListWatcher;
			if (Boolean(lw) && lw.isPersistent) {
				lw.updateContents();
			}
		}
	}

	private function setSmallPlayerMode(isSmallPlayer:Boolean):void {
		if (isSmallPlayer) {
			editMode = false;
		}
		this.setEditMode(editMode);
	}

	private function downloadFromJS():void {
		function download(ignore:*):void {
			exportProjectToFile(true);
		}

		DialogBox.confirm("Download project to local computer?", stage, download);
	}

	private function dumpRecordThumbnailFromJS():String {
		return Base64Encoder.encode(stagePane.projectThumbnailPNG());
	}

	private function addFileFromJS(fileName:String, contents:String, x:int, y:int):void {
		function errorHandler(evt:ErrorEvent):void {};

		function loadDone(evt:Event):void {
			var data:BitmapData = ScratchCostume.scaleForScratch(evt.target.content.bitmapData);
			addCostume(new ScratchCostume(assetName, data));
		}

		function addCostume(costume:ScratchCostume):void {
			addCostume(costume);
		}

		var data:ByteArray = Base64Encoder.decode(contents.slice(contents.indexOf(",") + 1));
		if (data.length == 0) return;
		var assetName:String = fileName;

		var i:int = 0;
		if ((i = assetName.lastIndexOf(".")) == assetName.length - 4) {
			assetName = assetName.slice(0, -4);
		}

		if (ScratchSound.isWAV(data)) {
			addSound(new ScratchSound(assetName, data));
		} else if (ScratchCostume.isSVGData(data)) {
			addCostume(new ScratchCostume(assetName, data));
		} else {
			var decoder:Loader = new Loader();
			decoder.contentLoaderInfo.addEventListener(Event.COMPLETE, loadDone);
			decoder.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
			decoder.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			decoder.loadBytes(data);
		}

		this.setSaveNeeded(true);
	}

	private function addURLFromJS(url:String, x:int, y:int):void {
		function addAsset(id:String):void {
			if (!id) return;

			var name:String = url;
			var ext:String = "";
			var idx:int = url.lastIndexOf(".");

			if (idx >= 0) {
				ext = url.slice(idx).toLowerCase();
				name = url.slice(0, idx);
			}

			idx = name.lastIndexOf("/");

			if (idx >= 0) {
				name = name.slice(idx + 1);
			}

			if (ext == ".wav" || ext == ".mp3") {
				fetchAndAddSound(id, name);
			} else {
				fetchAndAddCostume(id, name);
			}
		}

		if (!URLUtil.isHttpURL(url)) return;
		this.serverOnline.saveImageAssetFromURL(url, addAsset);
	}

	private function createProjectFromJS(owner:String, id:String = null, param3:String = null):void {
		if (Boolean(id) && id == this.projectID) return;
		this.log(LogLevel.INFO, "SWF AScreateProject", {"owner": owner});

		if (!owner) owner = "";

		runtime.stopAll();
		this.userName = owner;
		this.forceCreateNewAndUpload();
	}

	protected function loadProjectFromJS(owner:String, id:String, title:String, isPrivate:Boolean, autostart:Boolean = true):void {
		if (Boolean(id) && id == this.projectID) return;

		this.log(LogLevel.INFO, "SWF ASloadProject", {
			"id": id,
			"owner": owner,
			"title": title,
			"isPrivate": isPrivate,
			"autostart": autostart
		});

		if (!owner) owner = "";
		if (!id) id = "";
		if (!title) title = "";

		runtime.stopAll();
		saveNeeded = false;
		this.projectID = id;
		this.projectOwner = owner;
		this.projectIsPrivate = isPrivate;
		this.autostart = autostart;
		setProjectName(title);

		if (id == "") {
			startNewProject(owner, id);
			this.userName = owner;
			if (this.isLoggedIn()) {
				this.saveProject(false);
			}
		} else {
			var projIO:ProjectIOOnline = new ProjectIOOnline(this);
			projIO.fetchProject(projectOwner, id);
		}
	}

	override protected function doRevert():void {
		if (this.originalProjOnServer) {
			addLoadProgressBox("Reverting...");
			new ProjectIOOnline(this).downloadProjectAssets(originalProj);
		} else {
			super.doRevert();
		}
	}

	override public function saveForRevert(projData:ByteArray, isNew:Boolean, onServer:Boolean = false):void {
		super.saveForRevert(projData, isNew, onServer);
		this.originalProjOnServer = onServer;
	}

	public function setUserFromJS(username:String, action:String = ""):void {
		if (!username) username = "";

		this.wasLoggedOut = Boolean(this.userName) && !username;
		this.userName = username;
		this.getServerSettings();
		this.backpackPart.loadBackpack();
		this.refreshUserAndProject();
		fixLayout();
		if (!loadInProgress) {
			if (this.isLoggedIn()) {
				var isOwner:Boolean = this.userName == projectOwner || !projectOwner;
				switch (action) {
					case "save":
						if (!this.saveInProgress && isOwner) {
							this.saveProject(true);
						}
						break;
					case "remix":
						if (!this.saveInProgress && !isOwner) {
							this.remixButtonPressed();
						}
				}
			}
			this.updateSaveStatus();
		}
	}

	private function setNewProjectFromJS(newProjectID:String, newTitle:String):void {
		function projectSaved():void {
			setTimeout(function():void { jsRedirectTo(newProjectID, true); }, 1000);
		}

		projectID = newProjectID;
		projectOwner = this.userName;
		projectIsPrivate = true;
		setProjectName(newTitle);
		saveNeeded = true;
		if (this.canSave()) {
			this.saveProject(false, projectSaved);
		}
	}

	private function handleSaveResponse(response:String):void {
		if (response) {
			var jsonObj:Object = util.JSON.parse(response);
			if (jsonObj) {
				var autosaveInterval:int = 1000 * int(jsonObj["autosave-interval"]);
				if (autosaveInterval >= this.MIN_AUTO_SAVE_INTERVAL) {
					this.autosaveInterval = autosaveInterval;
				}

				var title:* = jsonObj["content-title"];
				if (title != null) {
					setProjectName(Base64Encoder.decode(title.toString()).toString());
				}

				var id:* = jsonObj["content-name"];
				if (id != null) {
					var origId:String = projectID;
					projectID = id.toString();
					if (origId != projectID)
					{
						this.persistenceManager.prepareForCopyOrRemix();
					}
				}
			}
		}
	}

	protected function saveProject(explicitSave:Boolean, whenDone:Function = null):void {
		var saveStartTime:int = 0;
		var oldProjectID:String;
		var projectThumbnail:ByteArray;

		function thumbnailSaved(ignore:*):void {
			if (oldProjectID != projectID) {
				jsRedirectTo(projectID, true);
			}
		}

		function uploadSucceeded(response:String):void {
			clearSaveInProgress(false);
			log(LogLevel.INFO, "Project saved!", {"msecs":CachedTimer.getCachedTimer() - saveStartTime});
			handleSaveResponse(response);

			serverOnline.setProjectThumbnail(projectID, projectThumbnail, thumbnailSaved);
			if (projectOwner != userName) {
				projectOwner = userName;
				refreshUserAndProject();
			}

			remixRequested = copyRequested = false;
			topBarOnline.hideTransitionNotice();

			if (whenDone != null) {
				whenDone();
			}
		}

		if (this.saveInProgress) return;
		if (!this.lastSaveFailed) this.saveFailureTolerance = explicitSave ? 1 : 3;

		this.log(LogLevel.INFO, "SWF saving project", {
			"id": projectID,
			"owner": this.userName,
			"title": projectName()
		});

		if (this.remixRequested) {
			this.topBarOnline.showTransitionNotice("Remixing...");
		} else if (this.copyRequested) {
			this.topBarOnline.showTransitionNotice("Copying...");
		}

		saveStartTime = CachedTimer.getCachedTimer();
		oldProjectID = projectID;
		projectThumbnail = stagePane.projectThumbnailPNG();
		new ProjectIOOnline(this).uploadProject(stagePane, projectID, this.remixRequested || this.copyRequested, uploadSucceeded);
		this.saveInProgress = true;
		this.clearSaveNeeded();
		this.updateSaveStatus();
	}

	public function saveFailed():void {
		if (this.saveInProgress) {
			this.setSaveNeeded();
		}
		this.reportSaveFailure();
	}

	private function setSharedFromJS(isPublic:Boolean):void {
		projectIsPrivate = !isPublic;
		this.refreshUserAndProject();
	}

	private function refreshUserAndProject():void {
		topBarPart.refresh();
		stagePart.refresh();

		this.log(LogLevel.INFO, "Refresh", {
			"user": this.userName,
			"owner": projectOwner,
			"id": projectID,
			"isPrivate": projectIsPrivate
		});
	}

	private function startFromJS():void {
		if (stagePart) {
			stagePart.playButtonPressed(null);
		}
	}

	private function stopFromJS():void {
		runtime.stopAll();
	}

	private function getProjectJSONJS():String {
		return escape(util.JSON.stringify(app.stagePane));
	}

	private function setBackpack(json:String):void {
		function done():void {};
		this.serverOnline.setBackpack(json, this.userName, done);
	}

	public function cloudConnectionReady():Boolean {
		if (!this.usesPersistentData) return true;
		return this.persistenceManager.ready;
	}

	private function clearProject():void {
		startNewProject("", "");
		if (!isOffline) setProjectName("Untitled");
		this.refreshUserAndProject();
	}

	private function forceCreateNewAndUpload():void {
		function projectCreated(response:String):void {
			clearSaveInProgress(false);
			topBarOnline.hideTransitionNotice();
			handleSaveResponse(response);
			refreshUserAndProject();
			jsRedirectTo(projectID, true);
		}

		this.clearProject();
		startNewProject(this.userName, "");

		if (Boolean(this.userName) && this.userName.length > 0) {
			this.saveInProgress = true;
			this.topBarOnline.showTransitionNotice("Creating...");
			new ProjectIOOnline(this).uploadProject(stagePane, null, true, projectCreated);
		}
	}

	override protected function createNewProject(ignore:* = null):void {
		function clearAndRedirect():void {
			clearProject();
			jsRedirectTo("editor", true);
		}

		function createNew():void {
			if (isOffline || isEmbedded || !isLoggedIn()) {
				if (stagePane.isEmpty()) {
					clearAndRedirect();
				} else {
					DialogBox.confirm("Discard contents of the current project?", app.stage, function(d:DialogBox):void { clearAndRedirect(); });
				}
			} else {
				forceCreateNewAndUpload();
			}
		}

		if (this.shouldSave()) {
			this.saveProject(true, createNew);
		} else {
			createNew();
		}
	}

	override public function setSaveNeeded(saveNow:Boolean = false):void {
		super.setSaveNeeded(saveNow);
		this.lastCheckTime = -1000000;

		if (saveNow) this.nextSaveTime = -1000000;
		this.updateSaveStatus();
	}

	override protected function clearSaveNeeded():void {
		super.clearSaveNeeded();

		this.nextSaveTime = CachedTimer.getCachedTimer() + this.autosaveInterval;
		this.showSaveFailDialog(false);
		this.setSaveStatus("Saved");
	}

	public function setSaveStatus(saveStatus:String, saveStatusAlert:Boolean = false):void {
		this.saveStatus = saveStatus;
		this.saveStatusAlert = saveStatusAlert;
		this.topBarOnline.setSaveStatus(this.saveStatus, this.saveStatusAlert, this.saveTimerContext);
	}

	public function clearSaveInProgress(lastSaveFailed:Boolean):void {
		this.saveInProgress = false;
		this.lastSaveFailed = lastSaveFailed;
	}

	public function reportSaveFailure():void {
		removeLoadProgressBox();
		stagePane.clearPenLayer();
		var loggedOut:Boolean = !this.isLoggedIn() || this.wasLoggedOut;

		if (!loggedOut) {
			--this.saveFailureTolerance;
			if (this.saveFailureTolerance <= 0) {
				this.showSaveFailDialog(true);
			}
			this.saveRetryDelay = this.lastSaveFailed ? int(Math.min(2 * this.saveRetryDelay, this.autosaveInterval)) : this.SAVE_CHECK_INTERVAL;
			this.nextSaveTime = CachedTimer.getCachedTimer() + this.saveRetryDelay;
		}

		this.clearSaveInProgress(true);
		this.setSaveStatus("Changes not saved; " + (loggedOut ? "please sign in to save." : "network not connecting. Trying again in {sec}..."), true);
	}

	public function updateSaveStatus():void {
		if (this.saveInProgress) {
			this.setSaveStatus("Saving...");
		} else if (saveNeeded) {
			if (!this.canSave()) {
				if (!this.isLoggedIn()) {
					this.setSaveStatus("Sign in to save", true);
				} else if (projectOwner != this.userName) {
					this.setSaveStatus("Want to save? Click remix", true);
				} else if (loadInProgress) {
					this.setSaveStatus("Project loading...");
				} else if (projectID == "") {
					this.setSaveStatus("Not saved: no project ID", true);
				}
			} else {
				this.setSaveStatus("Save now", true);
			}
		} else if (wasEdited) {
			this.setSaveStatus("Saved");
		} else {
			this.setSaveStatus("");
		}
	}

	private function shouldSave():Boolean {
		return saveNeeded && editMode && this.canSave();
	}

	private function canSave():Boolean {
		return this.isLoggedIn() && projectOwner == this.userName && projectID != "" && !loadInProgress;
	}

	public function saveNow(explicitSave:Boolean, whenDone:Function):void {
		if (!this.canSave()) return;

		if (saveNeeded) {
			this.saveProject(explicitSave, whenDone);
		} else {
			whenDone();
		}
	}
}
}
