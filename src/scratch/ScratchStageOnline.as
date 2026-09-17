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

// ScratchStageOnline.as
// Who knows?
//
// Wrapper around ScratchStage that adds backpack drag and drop support.

package scratch {
import ui.media.MediaInfoOnline;

import util.JSON;
import util.ProjectIOOnline;
import util.ServerOnline;

public class ScratchStageOnline extends ScratchStage {

	override public function handleDrop(obj:*):Boolean {
		if (super.handleDrop(obj)) return true;

		var app:Scratch = ScratchOnline.app as Scratch;
		var mio:MediaInfoOnline = obj as MediaInfoOnline;
		if (Boolean(mio) && mio.fromBackpack) {
			function addSpriteForCostume(costume:ScratchCostume):void {
				var s:ScratchSprite = new ScratchSprite(costume.costumeName);
				s.setInitialCostume(costume.duplicate());
				app.addNewSprite(s, false, true);
			}

			var handled:Boolean = false;
			if (obj.mysprite) {
				app.addNewSprite(obj.mysprite.duplicate(), false, true);
				handled = true;
			}


			if (obj.objType == "sprite") {
				function addDroppedSprite(s:ScratchSprite):void {
					s.objName = obj.objName;
					app.addNewSprite(s, false, true);
				}
				new ProjectIOOnline(ScratchOnline.app).fetchSprite(obj.md5, addDroppedSprite);
				handled = true;
			}

			if (obj.mycostume) {
				addSpriteForCostume(obj.mycostume);
				handled = true;
			}

			if (obj.objType == "image") {
				new ProjectIOOnline(ScratchOnline.app).fetchImage(obj.md5, obj.objName, obj.objWidth, addSpriteForCostume);
				handled = true;
			}

			if (handled) {
				ServerOnline.getInstance().logUseItemFromBackpack(util.JSON.stringify({
					"target": ScratchOnline.app.projectID,
					"item": obj.backpackRecord(),
					"uipart": "scratchstage"
				}));
				return true;
			}
		}
		return false;
	}

	override public function updateInfo():void {
		super.updateInfo();
		info.hasCloudData = ScratchOnline.app.usesPersistentData;
	}
}
}
