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

// ScratchRuntime.as
// Who knows?

package scratch {

import flash.utils.*;

import interpreter.*;

import translation.Translator;

import ui.media.MediaInfo;

import util.ProjectIO;
import util.ServerOnline;

import watchers.ListWatcher;

public class ScratchRuntimeOnline extends ScratchRuntime {

	[Embed(source='../assets/Cat1.svg', mimeType='application/octet-stream')] protected static var Cat1svg:Class;
	[Embed(source='../assets/Cat2.svg', mimeType='application/octet-stream')] protected static var Cat2svg:Class;
	[Embed(source='../assets/meow.wav', mimeType='application/octet-stream')] protected static var Meow:Class;

	public function ScratchRuntimeOnline(app:Scratch, interp:Interpreter) {
		super(app, interp);
	}

	override public function stepRuntime():void {
		if (projectToInstall != null && ScratchOnline.app.serverSettingsReady) {
			installProject(projectToInstall);
			if (saveAfterInstall) app.setSaveNeeded(true);
			projectToInstall = null;
			saveAfterInstall = false;
		} else {
			super.stepRuntime();
		}
	}

	override public function installProjectFromFile(fileName:String, data:ByteArray):void {
		super.installProjectFromFile(fileName, data);
		ScratchOnline.app.jsEditTitle();
		saveAfterInstall = true;
	}

	override public function deleteVariable(varName:String):void {
		var v:Variable = app.viewedObj().lookupVar(varName);

		if (v.isPersistent) {
			ScratchOnline.app.persistenceManager.deleteVariable(varName);
			--ScratchOnline.app.persistentDataCount;
		}
		super.deleteVariable(varName);
	}

	override public function renameVariable(oldName:String, newName:String):void {
		var v:Variable = app.viewedObj().lookupVar(oldName);
		if (v.isPersistent) {
			ScratchOnline.app.persistenceManager.renameVariable(oldName, newName);
		}
		super.renameVariable(oldName, newName);
	}

	override protected function doUndelete(obj:*, x:int, y:int, prevOwner:*):void {
		if (obj is MediaInfo && prevOwner == "backpack") {
			ScratchOnline.app.backpackPart.insertAndSave(obj);
		} else {
			super.doUndelete(obj, x, y, prevOwner);
		}
	}

	override public function updateVariable(v:Variable):void {
		if (v.isPersistent) {
			ScratchOnline.app.persistenceManager.updateVariable(v.name, v.value);
		}
	}

	override public function makeVariable(varObj:Object):Variable {
		var v:Variable = super.makeVariable(varObj);
		if (varObj.isPersistent) {
			v.isPersistent = true;
			ScratchOnline.app.usesPersistentData = true;
			++ScratchOnline.app.persistentDataCount;
		}
		return v;
	}

	override public function makeListWatcher():ListWatcher {
		var lw:ListWatcher = super.makeListWatcher();

		if (lw.isPersistent) {
			ScratchOnline.app.usesPersistentData = true;
			++ScratchOnline.app.persistentDataCount;
		}

		return lw;
	}

	override public function installNewProject():void {
		var stage:ScratchStage = new ScratchStageOnline();
		var sprite:ScratchSprite = new ScratchSprite();
		sprite.costumes = [new ScratchCostume(Translator.map("costume1"), new Cat1svg()), new ScratchCostume(Translator.map("costume2"), new Cat2svg())];
		sprite.showCostume(0);
		sprite.sounds = [new ScratchSound(Translator.map("meow"), new Meow())];
		stage.addChild(sprite);
		app.saveForRevert(new ProjectIO(app).encodeProjectAsZipFile(stage), true);
		app.oldWebsiteURL = "";
		installProject(stage);
	}

	override public function startGreenFlags(firstTime:Boolean = false):void {
		// Record 1st view
		if (firstTime) (app.server as ServerOnline).recordPlay();
		super.startGreenFlags(firstTime);
	}
}
}
