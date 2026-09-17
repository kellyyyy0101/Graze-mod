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

// ProjectIOOnline.as
// Who knows?
//
// Support for project saving/loading to a server.
// Two types of projects are supported: old Scratch projects (.sb) and new
// Scratch projects stored on a server as a collection of separate elements.

package util {
import by.blooddy.crypto.MD5;

import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.external.ExternalInterface;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.utils.ByteArray;
import flash.utils.setTimeout;

import logging.LogLevel;

import scratch.ScratchCostume;
import scratch.ScratchSprite;
import scratch.ScratchStage;
import scratch.ScratchStageOnline;

import translation.Translator;

public class ProjectIOOnline extends ProjectIO {

	private static var serverAssets:Object = {};

	public function ProjectIOOnline(app:ScratchOnline) {
		super(app);
	}

	public static function strings():Array {
		return [
			'Loading project...',
			'of',
			'assets loaded',
			'bytes loaded',
			'Installing...',
			'Uploading sprite...',
			'Saving changes...',
			'Saving...',
			'Saved',
			'Error!',
			'Project did not load.'
		];
	}

	private static function addCallServerErrorInfo(obj:Object):Object {
		var errorInfo:Object = ServerOnline.getInstance().callServerErrorInfo;

		if (errorInfo) {
			for (var error:String in errorInfo) {
				if (errorInfo.hasOwnProperty(error)) {
					obj[error] = errorInfo[error].toString();
				}
			}
		} else {
			obj["errorEvent"] = "[no event]";
		}
		return obj;
	}

	override protected function getScratchStage():ScratchStage {
		return new ScratchStageOnline();
	}

	public function fetchOldProjectURL(url:String):void {
		function progressHandler(progress:ProgressEvent):void {
			if (!app.lp) app.addLoadProgressBox("Loading project...");
			app.lp.setProgress(progress.bytesLoaded / progress.bytesTotal);
			app.lp.setInfo(progress.bytesLoaded + " " + Translator.map("of") + " " + progress.bytesTotal + " " + Translator.map("bytes loaded"));
		}

		function completeHandler(evt:Event):void {
			app.lp.setTitle("Installing...");
			app.oldWebsiteURL = url;
			app.runtime.installProjectFromData(loader.data);
		}

		app.runtime.stopAll();
		app.runtime.installEmptyProject();

		var loader:URLLoader = new URLLoader();
		loader.dataFormat = URLLoaderDataFormat.BINARY;
		loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
		loader.addEventListener(Event.COMPLETE, completeHandler);
		loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, app.runtime.projectLoadFailed);
		loader.addEventListener(IOErrorEvent.IO_ERROR, app.runtime.projectLoadFailed);

		app.addLoadProgressBox("Loading project...");
		app.loadInProgress = true;

		try {
			loader.load(new URLRequest(url));
		}
		catch (error:*) {
			app.runtime.projectLoadFailed();
			loader = null;
		}
	}

	public function uploadProject(proj:ScratchStage, projectID:String, createNew:Boolean, onSuccess:Function):void {
		var projectJSON:String;
		var projectDataSaved:Boolean;
		var info:String;

		function allAssetsUploaded():void {
			if (createNew) {
				ServerOnline.getInstance().createProject(projectSaved, app.projectName(), projectJSON, projectID);
			} else {
				ServerOnline.getInstance().setProject(projectID, projectJSON, projectSaved);
			}
		}

		function projectSaved(response:String):void {
			if (didUploadSucceed(response)) {
				projectDataSaved = true;
				app.removeLoadProgressBox();
				proj.clearPenLayer();
				(app as ScratchOnline).setSaveStatus("Saved");
				onSuccess(response);
			} else {
				app.logMessage("Project save failed.", addCallServerErrorInfo({
					"response": response,
					"data": projectJSON
				}));
				app.removeLoadProgressBox();
				ScratchOnline.app.saveFailed();
			}
		}

		function timerTask():void {
			if (projectDataSaved) return;

			if (app.lp) {
				info += "*";
				if (info.length > 10) info = "*";

				app.lp.setInfo(info);
				setTimeout(timerTask, 500);
			}
		}

		delete proj.info.penTrails;
		proj.savePenLayer();
		proj.updateInfo();
		recordImagesAndSounds(proj.allObjects(), true);

		var hadProjectID:Boolean = Boolean(projectID) && projectID.length > 0;
		createNew ||= !hadProjectID;
		projectJSON = util.JSON.stringify(proj);
		projectDataSaved = false;

		info = "*";
		ScratchOnline.app.setSaveStatus("Saving...");
		if (images.length + sounds.length > 0) {
			app.addLoadProgressBox("Saving changes...");
		}

		uploadImagesAndSounds(allAssetsUploaded);
		timerTask();
	}

	public function uploadSprite(spr:ScratchSprite, onSuccess:Function):void {
		var assetsSaved:Boolean = false;
		var jsonSaved:Boolean = false;
		var md5:String;

		function spriteJSONSaved():void {
			jsonSaved = true;
			checkDone();
		}

		function allAssetsUploaded():void {
			assetsSaved = true;
			checkDone();
		}

		function checkDone():void {
			if (jsonSaved && assetsSaved) {
				app.removeLoadProgressBox();
				onSuccess(md5 + ".json");
			}
		}

		app.addLoadProgressBox("Uploading sprite...");
		recordImagesAndSounds([spr], true);
		this.uploadImagesAndSounds(allAssetsUploaded);
		var jsonData:ByteArray = new ByteArray();
		jsonData.writeUTFBytes(util.JSON.stringify(spr));
		md5 = MD5.hashBytes(jsonData);
		this.uploadAsset(md5, ".json", jsonData, spriteJSONSaved);
	}

	private function uploadImagesAndSounds(whenDone:Function):void {
		var totalAssets:int;
		var uploaded:int;

		function assetUploadDone():void {
			++uploaded;
			if (app.lp) {
				app.lp.setProgress(uploaded / totalAssets);
				app.lp.setInfo(uploaded + " of " + totalAssets + " assets uploaded");
			}
			if (uploaded == totalAssets) whenDone();
		}

		totalAssets = images.length + sounds.length;
		if (totalAssets == 0) {
			whenDone();
		}

		uploaded = 0;
		for (var i:int = 0; i < images.length; i++) {
			var md5:String = images[i][0];
			var data:ByteArray = images[i][1];
			var ext:String = ScratchCostume.fileExtension(data);
			this.uploadAsset(md5, ext, data, assetUploadDone);
		}

		for (var i:int = 0; i < sounds.length; i++) {
			var md5:String  = sounds[i][0];
			var data:ByteArray = sounds[i][1];
			this.uploadAsset(md5, ".wav", data, assetUploadDone);
		}
	}

	public function uploadAsset(md5:String, dotExt:String, data:ByteArray, whenDone:Function):void {
		function uploadDone(response:String):void {
			if (didUploadSucceed(response, md5)) {
				recordServerAsset(md5);
				whenDone();
			} else {
				app.removeLoadProgressBox();
				ScratchOnline.app.saveFailed();
			}
		}

		if (data.length == 0) {
			app.log(LogLevel.WARNING, "Skipping upload of empty asset", {
				"md5": md5,
				"dotExt": dotExt
			});

			whenDone();
			return;
		}

		if (md5.indexOf(".") < 0) md5 += dotExt;
		ServerOnline.getInstance().setAsset(md5, data, uploadDone);
	}

	private function didUploadSucceed(response:String, md5:String = ""):Boolean {
		if (response) {
			if (response == md5) return true;
			if (response == "true") return true;

			var isHTML:Boolean = response.indexOf("<html>") > -1;
			var jsonData:* = {};

			try {
				jsonData = util.JSON.parse(response);
			}
			catch (e:*) {
			}

			if (jsonData.status == "ok") return true;

			if (jsonData.status == "unauthorized" || isHTML) {
				(app as ScratchOnline).setUserFromJS("");
				return false;
			}
		}

		return false;
	}

	public function fetchProject(projectOwner:String, projectID:String, cacheBuster:String = null):void {
		var retried:Boolean = false;

		function whenDone(projectData:ByteArray):void {
			if (Boolean(projectData) && projectData.length > 50) {
				if (ObjReader.isOldProject(projectData)) {
					app.oldWebsiteURL = ServerOnline.getInstance().projectURL(projectID);
					app.lp.setTitle("Installing...");
					app.runtime.installProjectFromData(projectData);
				} else if (isNewProject(projectData)) {
					app.lp.setTitle("Installing...");
					app.runtime.installProjectFromData(projectData);
				} else {
					app.saveForRevert(projectData, false, true);
					try {
						downloadProjectAssets(projectData);
					}
					catch (e:*) {
						Scratch.app.removeLoadProgressBox();
						if (e is Error) {
							Scratch.app.logException(e);
						} else {
							Scratch.app.logMessage(e);
						}

						Scratch.app.loadProjectFailed();
					}
				}
			} else if (projectID.length < 8) {
				// If the project is, uh, short and uhhh it's id is less than 8 characters long, try fetching from somewhere else?
				// ...what?

				var host:String = Scratch.app.jsEnabled ? ExternalInterface.call("window.document.location.host.toString") : "scratch.mit.edu";
				var i:int = host.indexOf(":");
				if (i > -1) {
					host = host.slice(0, i);
				}
				app.oldWebsiteURL = ScratchOnline.app.hostProtocol + "://" + host + "/static/projects/" + projectOwner + "/" + projectID + ".sb";
				fetchOldProjectURL(app.oldWebsiteURL);
			} else {
				var info:Object = ServerOnline.getInstance().callServerErrorInfo;
				if (Boolean(info) && Boolean(info.errorEvent is SecurityErrorEvent) && !retried) {
					retried = true;
					app.addLoadProgressBox("Retrying...");
					setTimeout(function():void {
						app.addLoadProgressBox("Loading project...");
						ServerOnline.getInstance().getProject(projectID, whenDone, cacheBuster);
					}, 2000);
				} else {
					app.logMessage("Project load failed. retried=" + retried, addCallServerErrorInfo({}));
					app.runtime.projectLoadFailed();
				}
			}
		}

		retried = false;
		app.oldWebsiteURL = "";
		app.addLoadProgressBox("Loading project...");
		app.loadInProgress = true;
		ServerOnline.getInstance().getProject(projectID, whenDone, cacheBuster);
	}

	private function isNewProject(data:ByteArray):Boolean {
		if (data.length < 2) return false;

		data.position = 0;
		var contents:String = data.readUTFBytes(2);
		data.position = 0;

		return "PK" == contents;
	}

	override public function fetchAsset(md5:String, whenDone:Function):URLLoader {
		function gotData(data:ByteArray):void {
			recordServerAsset(md5);
			whenDone(md5, data);
		}

		return ServerOnline.getInstance().getAsset(md5, gotData);
	}

	override protected function recordedAssetID(md5:String, recordedAssets:Object, uploading:Boolean):int {
		var id:int = super.recordedAssetID(md5, recordedAssets, uploading);

		if (id == -2 && uploading && this.serverHasAsset(md5)) {
			return -1;
		}

		return id;
	}

	override public function decodeProjectFromZipFile(zipData:ByteArray):ScratchStage {
		// The original function outputs a regular ScratchStage instead of a ScratchStageOnline
		return super.decodeFromZipFile(zipData) as ScratchStageOnline;
	}

	private function recordServerAsset(md5:String):void {
		serverAssets[md5] = null;
	}

	private function serverHasAsset(md5:String):Boolean {
		return md5 in serverAssets;
	}
}
}
