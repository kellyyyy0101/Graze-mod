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

// ServerOfflineOnline.as
// Who knows?
//
// Interface to the Scratch website API's for Online Editor.
//
// Note: All operations call the whenDone function with the result
// if the operation succeeded or null if it failed.

package util {
import by.blooddy.crypto.MD5;

import flash.events.HTTPStatusEvent;
import flash.external.ExternalInterface;
import flash.utils.ByteArray;

import logging.LogLevel;

public class ServerOnline extends Server {

	private static var instance:ServerOnline;

	private var lastThumbMD5:String;

	public function ServerOnline() {
		ServerOnline.instance = this;
	}

	public static function getInstance():ServerOnline {
		return instance;
	}

	override protected function setDefaultURLs():void {
		// These values are used in embedded projects.
		URLs.sitePrefix = "https://scratch.mit.edu/";
		URLs.siteCdnPrefix = "https://cdn.scratch.mit.edu/";
		URLs.assetPrefix = "https://assets.scratch.mit.edu/";
		URLs.assetCdnPrefix = "https://cdn.assets.scratch.mit.edu/";
		URLs.projectPrefix = "https://projects.scratch.mit.edu/";
		URLs.projectCdnPrefix = "https://cdn.projects.scratch.mit.edu/";
		URLs.internalAPI = "internalapi/";
		URLs.siteAPI = "site-api/";
		URLs.staticFiles = "scratchr2/static/";
	}

	public function getProjectURL():String {
		return Scratch.app.projectID ? URLs.sitePrefix + "projects/" + Scratch.app.projectID + "/" : "";
	}

	public function recordPlay():void {
		if (Scratch.app.projectID) {
			serverGet(URLs.sitePrefix + "projects/" + Scratch.app.projectID + "/run/", function(ignore:*):void {
				ScratchOnline.app.log(LogLevel.INFO, "Play recorded");
			});
		}
	}

	public function setAsset(filename:String, data:ByteArray, whenDone:Function):void {
		var url:String = URLs.assetPrefix + URLs.internalAPI + "asset/" + filename + "/set/";
		var i:int = filename.indexOf(".");
		var ext:String = i > 0 ? filename.substr(i + 1) : null;
		var mimetype:String = "application/octet-stream";

		if (ext == "json") {
			mimetype = "application/json";
		} else if (ext == "svg") {
			mimetype = "image/svg+xml";
		} else if (ext == "png") {
			mimetype = "image/png";
		} else if (ext == "jpg" || ext == "jpeg") {
			mimetype = "image/jpeg";
		} else if (ext == "wav") {
			mimetype = "audio/wav";
		} else if (ext == "mp3") {
			mimetype = "audio/x-mpeg-3";
		}
		callServer(url, data, mimetype, whenDone);
	}

	override protected function getCdnStaticSiteURL():String {
		var token:String = ScratchOnline.app.getCdnToken();

		if (token) {
			token = "__" + token + "__/";
		} else {
			token = "";
		}

		return super.getCdnStaticSiteURL() + token;
	}

	public function saveImageAssetFromURL(url:String, whenDone:Function):void {
		var asset:String = url.slice(7);
		var fullUrl:String = URLs.sitePrefix + URLs.internalAPI + "asset/" + asset + "/setfromurl/";
		serverGet(fullUrl, whenDone);
	}

	public function getBackpack(username:String, whenDone:Function):void {
		var url:String = URLs.sitePrefix + URLs.internalAPI + "backpack/" + username + "/get/";
		serverGet(url, whenDone);
	}

	public function setBackpack(content:String, username:String, whenDone:Function):void {
		var url:String = URLs.sitePrefix + URLs.internalAPI + "backpack/" + username + "/set/";
		callServer(url, content, "application/json", whenDone);
	}

	public function getSettings(whenDone:Function):void {
		var url:String = URLs.sitePrefix + URLs.internalAPI + "swf-settings/";
		serverGet(url, whenDone);
	}

	public function getSession(whenDone:Function):void {
		var url:String = URLs.sitePrefix + "session/";
		serverGet(url, whenDone);
	}

	public function getCloudToken(projectID:String, whenDone:Function):void {
		// Unused
		var url:String = URLs.sitePrefix + "projects/" + projectID + "/cloud_token/";
		serverGet(url, whenDone);
	}

	public function createProject(whenDone:Function, title:String, projectJSON:String, projectID:String = null):void {
		var url:String = URLs.projectPrefix + URLs.internalAPI + "project/new/set/";
		var params:Object = {"title": title};

		if (Boolean(projectID) && projectID != "") {
			params["original_id"] = projectID;
			if (ScratchOnline.app.userName != ScratchOnline.app.projectOwner) {
				params["is_remix"] = 1;
			} else {
				params["is_copy"] = 1;
			}
		}

		callServer(url, projectJSON, "application/json", whenDone, params);
	}

	public function getProject(projectID:String, whenDone:Function, cacheBuster:String = null):void {
		if (!cacheBuster) cacheBuster = new Date().getTime().toString(16);

		// Disables cache buster on scratch.mit.edu I think
		if (URLs.sitePrefix.indexOf("edu:") > -1) cacheBuster = "";

		var url:String = URLs.projectCdnPrefix + URLs.internalAPI + "project/" + projectID + "/get/" + cacheBuster;
		serverGet(url, whenDone);
	}

	public function getProjectSaveURL(projectID:String):String {
		return URLs.projectPrefix + URLs.internalAPI + "project/" + projectID + "/set/";
	}

	public function setProject(projectID:String, projectJSON:String, whenDone:Function):void {
		callServer(this.getProjectSaveURL(projectID), projectJSON, "application/json", whenDone);
	}

	public function projectURL(param1:String):String {
		return "http://scratch.mit.edu/services/download/" + param1 + "/";
	}

	public function setProjectThumbnail(projectID:String, thumbnail:ByteArray, whenDone:Function):void {
		var md5:String = projectID + "_" + MD5.hashBytes(thumbnail);
		if (!this.lastThumbMD5 || this.lastThumbMD5 != md5) {
			this.lastThumbMD5 = md5;
			var url:String = URLs.sitePrefix + URLs.internalAPI + "project/thumbnail/" + projectID + "/set/";
			callServer(url, thumbnail, "image/png", whenDone);
		} else {
			whenDone(null);
		}
	}

	override public function getLanguageList(whenDone:Function):void {
		var url:String = this.getCdnStaticSiteURL() + "locale/" + "lang_list.txt";
		serverGet(url, whenDone);
	}

	override public function getPOFile(lang:String, whenDone:Function):void {
		var url:String = this.getCdnStaticSiteURL() + "locale/" + lang + ".po";
		serverGet(url, whenDone);
	}

	override public function getSelectedLang(whenDone:Function):void {
		function gotLanguage(response:String):void {
			if (response) {
				try {
					var obj:Object = util.JSON.parse(response);
				}
				catch (e:*) {
				}

				if (Boolean(obj) && obj.lang is String) {
					whenDone(obj.lang);
				}
			}
		}
		var url:String = URLs.sitePrefix + URLs.siteAPI + "i18n/get-preferred-language/";
		serverGet(url, gotLanguage);
	}

	override public function setSelectedLang(lang:String):void {
		function doNothing(response:String):void {}

		var url:String = URLs.sitePrefix + URLs.siteAPI + "i18n/set-preferred-language/";
		if (lang == "") lang = "en";

		// The tip bar is a part of ScratchR2
		Scratch.app.externalCall("window.tip_bar_api.updateLanguage", null, lang);

		url += "?lang=" + encodeURIComponent(lang);
		callServer(url, null, null, doNothing);
	}

	public function logAddItemToBackpack(jsonData:String):void {
		function doNothing(response:String):void {}

		var url:String = URLs.sitePrefix + "log/add-item-to-backpack/";
		callServer(url, jsonData, "application/json", doNothing);
	}

	public function logUseItemFromBackpack(jsonData:String):void {
		function doNothing(response:String):void {}

		var url:String = URLs.sitePrefix + "log/use-item-from-backpack/";
		callServer(url, jsonData, "application/json", doNothing);
	}

	public function logDeleteItemFromBackpack(jsonData:String):void {
		function doNothing(response:String):void {}

		var url:String = URLs.sitePrefix + "log/delete-item-from-backpack/";
		callServer(url, jsonData, "application/json", doNothing);
	}

	override protected function onCallServerHttpStatus(url:String, data:*, event:HTTPStatusEvent):void {
		if (event.status == 403 && Boolean(data)) {
			ScratchOnline.app.handleExternalLogout();
		}
	}

	override public function getCSRF():String {
		return ScratchOnline.app.jsEnabled ? ExternalInterface.call("getCookie", "scratchcsrftoken") : null;
	}
}
}
