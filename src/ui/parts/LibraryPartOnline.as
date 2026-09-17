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

// LibraryPartOnline.as
// Who knows?
//
// Wrapper around LibraryPart.


package ui.parts {
import flash.display.BitmapData;
import flash.geom.Point;

import scratch.ScratchCostume;
import scratch.ScratchSprite;

import translation.Translator;

import ui.media.MediaInfoOnline;
import uiwidgets.IconButton;

import util.JSON;
import util.ProjectIO;
import util.ServerOnline;

public class LibraryPartOnline extends LibraryPart {

	public function LibraryPartOnline(app:ScratchOnline) {
		super(app);
	}

	override public function handleDrop(obj:*):Boolean {
		if (realHandleDrop(obj)) {
			var mio:MediaInfoOnline = obj as MediaInfoOnline;

			if (Boolean(mio) && mio.fromBackpack) {
				ServerOnline.getInstance().logUseItemFromBackpack(util.JSON.stringify({
					"target": ScratchOnline.app.projectID,
					"item": mio.backpackRecord(),
					"uipart": "librarypart"
				}));
			}

			return true;
		}

		return false;
	}

	private function realHandleDrop(obj:*):Boolean {
		var item:MediaInfoOnline = obj as MediaInfoOnline;
		if (!item) return false;

		var dropP:Point = spritesPane.globalToLocal(new Point(item.x, item.y));

		if (!item.fromBackpack && Boolean(item.mysprite)) {
			changeThumbnailOrder(item.mysprite, dropP.x, dropP.y);
			return true;
		}

		if (item.fromBackpack) {
			function addSpriteForCostume(c:ScratchCostume):void {
				var _loc2_:ScratchSprite = new ScratchSprite(c.costumeName);
				_loc2_.setInitialCostume(c.duplicate());
				app.addNewSprite(_loc2_, false, true);
			}

			if (item.mysprite) {
				app.addNewSprite(item.mysprite.duplicate());
				return true;
			}

			if ("sprite" == item.objType) {
				new ProjectIO(app).fetchSprite(item.md5, app.addNewSprite);
				return true;
			}

			if (item.mycostume) {
				addSpriteForCostume(item.mycostume);
				return true;
			}

			if ("image" == item.objType) {
				new ProjectIO(app).fetchImage(item.md5, item.objName, item.objWidth, addSpriteForCostume);
				return true;
			}
		}

		return false;
	}

	override protected function spriteFromCamera(b:IconButton):void {
		function savePhoto(photo:BitmapData):void {
			try {
				ScratchOnline.app.logImageImported("photo.png", true);
			}
			catch (error:Error) {
			}

			// LibraryPart.spriteFromCamera.savePhoto
			var s:ScratchSprite = new ScratchSprite();
			s.setInitialCostume(new ScratchCostume(Translator.map("photo1"), photo));
			app.addNewSprite(s);
			app.closeCameraDialog();
		}
		app.openCameraDialog(savePhoto);
	}

	override protected function backdropFromCamera(b:IconButton):void {
		function savePhoto(photo:BitmapData):void {
			try {
				ScratchOnline.app.logImageImported("photo.png", true);
			}
			catch (error:Error) {
			}

			// LibraryPart.backdropFromCamera.savePhoto
			addBackdrop(new ScratchCostume(Translator.map("photo1"), photo));
			app.closeCameraDialog();
		}
		app.openCameraDialog(savePhoto);
	}
}
}
