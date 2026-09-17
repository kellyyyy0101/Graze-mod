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

// PersistenceManager.as
// Who knows?
//
// Manages cloud data.
//

package interpreter {
import flash.events.*;
import flash.external.ExternalInterface;
import flash.utils.setTimeout;
import logging.LogLevel;
import scratch.ScratchObj;
import translation.Translator;
import util.JSON;
import watchers.ListWatcher;

public class PersistenceManager extends EventDispatcher {

	public static var READY:String = "ready";

	private static const NULL_CLOUD_TOKEN:String = "00000000-0000-0000-0000-000000000000";

	private static const cloudInfo:String = "<b>Information about Cloud variables</b>" + "<br>&nbsp;<br>" + "Currently, only numbers are supported<br>" + "Chat rooms are not allowed, and will be removed<br>" + "For more info, <a href=\"/info/faq/#clouddata\" target=\"_blank\">see the cloud data FAQ!</a>";

	private static const notProjectOwnerWarning:String = "You cannot edit cloud data in someone else\'s project.<br>" + "Any change that you make in the editor will be temporary and not persistent.";
	private static const numberWarning:String = "Currently, only numbers can be stored in Cloud variables.";

	public var ready:Boolean = false;

	private var app:ScratchOnline;

	private var server:String = "clouddata.scratch.mit.edu";

	private var decayTimeout:Number = 1000;
	private var buffer:String = "";

	private var cloudDataDisabled:Boolean = false;

	private var cloudVariableDisabled:Boolean = false;
	private var cloudListDisabled:Boolean = true;
	private var cloudVariablesNumeralsOnly:Boolean = true;

	private var seenVariables:Array = [];
	private var seenLists:Array = [];

	private var cloudLastConnectEpochMillis:Number = 0;
	private var cloudConnectAttempts:int = 1;

	public function PersistenceManager(app:ScratchOnline) {
		super();
		this.app = app;
		if (ExternalInterface.available) {
			ExternalInterface.addCallback("ASonCloudDataClose", this.onCloudDataClose);
			ExternalInterface.addCallback("ASonCloudDataConnect", this.onCloudDataConnect);
			ExternalInterface.addCallback("ASonCloudDataError", this.onCloudDataError);
			ExternalInterface.addCallback("ASonCloudDataData", this.onCloudDataData);
		}
	}

	public static function strings():Array {
		return [
			"Cloud data",
			"Connecting to Cloud data server...",
			cloudInfo,
			notProjectOwnerWarning,
			numberWarning
		];
	}

	public function prepareForCopyOrRemix():void {
		for each(var v:Variable in this.app.stagePane.variables) {
			if (v.isPersistent) {
				this.writeToServer("set_remix", v.name, v.value);
			}
		}

		for each(var lw:ListWatcher in this.app.stagePane.lists) {
			if (lw.isPersistent) {
				this.writeToServer("lset_remix", lw.listName, lw.contents);
			}
		}
	}

	public function createVariable(varName:String):void {
		if (!this.verifyOwner(true)) return;
		this.writeToServer("create", varName);
	}

	public function updateVariable(varName:String, newValue:*):void {
		if (this.cloudVariablesNumeralsOnly && isNaN(newValue)) {
			this.app.jsSetProjectBanner(numberWarning);
			var v:Variable = this.app.stagePane.lookupVar(varName);
			v.value = 0;
			newValue = 0;
		}

		if (!this.seenVariable(varName)) return;
		this.writeToServer("set", varName, newValue);
	}

	public function renameVariable(oldName:String, newName:String):void {
		if (!this.verifyOwner(true)) return;
		this.writeToServer("rename", oldName, undefined, undefined, newName);
	}

	public function deleteVariable(varName:String):void {
		if (!this.verifyOwner(true)) return;
		this.writeToServer("delete", varName);
	}

	public function setList(listName:String, newValue:*):void {
		this.writeToServer("lset", listName, newValue);
	}

	public function appendList(listName:String, item:*):void {
		this.writeToServer("lappend", listName, item);
	}

	public function deleteList(listName:String, i:Number):void {
		this.writeToServer("ldelete", listName, undefined, i);
	}

	public function insertList(listName:String, item:*, i:Number):void {
		this.writeToServer("linsert", listName, item, i);
	}

	public function replaceList(listName:String, item:*, i:Number):void {
		this.writeToServer("lreplace", listName, item, i);
	}

	public function connect(server:String):void {
		this.server = server;
		this.cloudDataDisabled = !this.app.isCloudDataEnabled();
		if (this.cloudDataDisabled) return;
		if (!this.app.lp) this.app.addLoadProgressBox("Cloud data");
		this.app.lp.setInfo("Connecting to Cloud data server...");
		this.app.log(LogLevel.INFO, "Connecting to cloud data server", {"server": server});
		if (this.app.editMode) this.app.jsSetProjectBanner(cloudInfo, true);

		if (ExternalInterface.available) {
			this.cloudLastConnectEpochMillis = new Date().time;
			this.cloudConnectAttempts += 1;
			ExternalInterface.call("JScloudDataConnect", server);
		}
	}

	private function writeToServer(operation:*, name:* = undefined, value:* = undefined, index:* = NaN, newName:* = undefined):void {
		if (this.cloudDataDisabled) return;
		if (operation != "handshake" && !this.verifyOwner()) return;

		var request:Object = {};
		request.method = operation;
		request.user = this.app.userName;
		request.project_id = this.app.projectID;

		if (name != undefined) request.name = name;
		if (value != undefined) request.value = value;
		if (!isNaN(index)) request.index = index;
		if (newName != undefined) request.new_name = newName;

		var requestStr:String = util.JSON.stringify(request, false);
		if (ExternalInterface.available) ExternalInterface.call("JScloudDataSend", requestStr);
	}

	private function reconnectCloudDataAfterClose():void {
		if (this.cloudDataDisabled) return;
		this.app.log(LogLevel.INFO, "Attempt reconnect to cloud server.");
		if (ExternalInterface.available) ExternalInterface.call("JScloudDataConnect", this.server);
	}

	private function onCloudDataClose():void {
		this.decayTimeout = 1000 * (Math.random() * (Math.pow(this.cloudConnectAttempts, 2) - 1) + 1);
		setTimeout(this.reconnectCloudDataAfterClose, this.decayTimeout);
	}

	private function onCloudDataConnect():void {
		if (!this.ready) {
			this.buffer = "";
			this.writeToServer("handshake");
			this.ready = true;
			dispatchEvent(new Event(PersistenceManager.READY));

			if (Boolean(this.app.lp) && this.app.lp.getTitle() == Translator.map("Cloud data")) {
				this.app.removeLoadProgressBox();
			}
		}
		if (this.cloudConnectAttempts < 6) {
			this.cloudConnectAttempts += 1;
		} else {
			this.cloudConnectAttempts = 1;
		}

		this.app.log(LogLevel.INFO, "Successfully connected to cloud data server");
	}

	private function onCloudDataError():void {
		this.app.log(LogLevel.WARNING, "Connection Error for Cloud Data Server");
		this.ready = false;

		if (Boolean(this.app.lp) && this.app.lp.getTitle() == Translator.map("Cloud data")) {
			this.app.removeLoadProgressBox();
		}

		this.onCloudDataClose();
	}

	private function onCloudDataData(data:String):void {
		this.buffer += data;
		this.parseBuffer();
	}

	private function verifyOwner(param1:Boolean = false):Boolean {
		// TODO: Params

		if (this.app.isUserStaff()) return true;
		if (this.cloudDataDisabled) return false;
		if (!this.app.isLoggedIn())  return false;
		if (this.app.projectOwner == this.app.userName) return true;

		if (param1) return false;

		if (this.app.projectOwner != this.app.userName && this.app.saveNeeded) {
			if (this.app.editMode)  {
				this.app.jsSetProjectBanner(notProjectOwnerWarning);
			}
			return false;
		}

		if (this.app.projectOwner != this.app.userName && this.app.editMode) {
			this.app.jsSetProjectBanner(notProjectOwnerWarning);
			return false;
		}
		return true;
	}

	private function seenVariable(param1:String):Boolean {
		if (this.seenVariables.indexOf(param1) > -1) {
			return true;
		}
		return false;
	}

	private function parseBuffer():void {
		while(true) {
			var i:int = this.buffer.indexOf("\n");
			if (i < 0) break;

			var data:String = this.buffer.slice(0, i);
			this.buffer = this.buffer.slice(i + 1);
			if (data.length > 0) {
				var obj:Object = util.JSON.parse(data);
				var method:String = obj.method;
				if (method == "ack") {
					var stage:ScratchObj = this.app.stageObj();
					var v:Variable = stage.lookupOrCreateVar(obj.name);
					v.isPersistent = true;
					this.app.runtime.showVarOrListFor(obj.name, false, stage);
					this.app.setSaveNeeded();
					if (this.seenVariables.indexOf(obj.name) < 0) {
						this.seenVariables.push(obj.name);
					}
				}

				if (method == "set") {
					if (this.cloudVariableDisabled) return;

					v = this.app.stagePane.lookupVar(obj.name);
					if (Boolean(v) && v.isPersistent) {
						v.value = obj.value;
					}
					if (this.seenVariables.indexOf(obj.name) < 0) {
						this.seenVariables.push(obj.name);
					}
				}

				if (method == "lset") {
					if (this.cloudListDisabled) return;

					var lw:ListWatcher = this.app.stagePane.lookupOrCreateList(obj.name);
					if (lw.isPersistent) {
						lw.contents = obj.value;
						if (lw.visible) {
							lw.updateWatcher(lw.contents.length, false, this.app.interp);
						}
					}
					if (this.seenLists.indexOf(obj.name) < 0) {
						this.seenLists.push(obj.name);
					}
				}

				if (method == "lappend") {
					if (this.cloudListDisabled) return;

					var lw:ListWatcher = this.app.stagePane.lookupOrCreateList(obj.name);
					if (lw.isPersistent) {
						lw.contents.push(obj.value);
						if (lw.visible) {
							lw.updateWatcher(lw.contents.length, false, this.app.interp);
						}
					}
				}

				if (method == "ldelete") {
					if (this.cloudListDisabled) return;
					if (isNaN(obj.index)) return;

					var lw:ListWatcher = this.app.stagePane.lookupOrCreateList(obj.name);
					if (lw.isPersistent) {
						lw.contents.splice(obj.index - 1, 1);
						if (lw.visible) {
							lw.updateWatcher(obj.index, false, this.app.interp);
						}
					}
				}

				if (method == "lreplace") {
					if (this.cloudListDisabled) return;
					if (isNaN(obj.index)) return;

					var lw:ListWatcher = this.app.stagePane.lookupOrCreateList(obj.name);
					if (lw.isPersistent) {
						lw.contents.splice(obj.index - 1, 1, obj.value);
						if (lw.visible) {
							lw.updateWatcher(obj.index, false, this.app.interp);
						}
					}
				}

				if (method == "linsert") {
					if (this.cloudListDisabled) return;
					if (isNaN(obj.index)) return;

					var lw:ListWatcher = this.app.stagePane.lookupOrCreateList(obj.name);
					if (lw.isPersistent) {
						lw.contents.splice(obj.index - 1, 0, obj.value);
						if (lw.visible) {
							lw.updateWatcher(obj.index, false, this.app.interp);
						}
					}
				}
			}
		}
	}
}
}
