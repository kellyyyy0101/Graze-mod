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

// MediaLibraryOnline.as
// Who knows?
//
// Wrapper around MediaLibrary.

package ui.media {
import scratch.*;
import uiwidgets.Button;
import util.*;

public class MediaLibraryOnline extends MediaLibrary {

	private var viewDocsBtn:Button;
	private var showMyExtensionsBtn:Button;
	private var createExtensionsBtn:Button;

	private var myExtensions:Array = [];

	private var w:int;
	private var h:int;

	public function MediaLibraryOnline(app:Scratch, type:String, whenDone:Function) {
		super(app, type, whenDone);
	}

	override public function setWidthHeight(w:int, h:int):void {
		super.setWidthHeight(w, h);

		this.w = w;
		this.h = h;

		if (this.showMyExtensionsBtn) {
			this.showMyExtensionsBtn.x = 50;
			this.showMyExtensionsBtn.y = 200;
			this.viewDocsBtn.x = 50;
			this.viewDocsBtn.y = 240;
			this.createExtensionsBtn.x = 50;
			this.createExtensionsBtn.y = 280;
		}
	}

	public function showMyExtensions():void {
		this.viewDocsBtn.visible = true;
		this.createExtensionsBtn.visible = false;

		while (resultsPane.numChildren > 0) {
			resultsPane.removeChildAt(0);
		}

		appendItems(this.myExtensions);
	}

	override protected function uploadCostume(costume:ScratchCostume, whenDone:Function):void {
		try {
			ScratchOnline.app.logImageImported(costume.baseLayerMD5, false);
		}
		catch (error:Error) {
			try {
				if (ScratchCostume.isSVGData(costume.baseLayerData)) {
					ScratchOnline.app.logImageImported(".svg", false);
				}
			}
			catch (error:Error) {
			}
		}

		if (ScratchOnline.app.isLoggedIn()) {
			app.addLoadProgressBox("Uploading image...");
			costume.prepareToSave();
			new ProjectIOOnline(ScratchOnline.app).uploadAsset(costume.baseLayerMD5, "", costume.baseLayerData, whenDone);
		} else {
			// If the user isn't logged in, act as if we were offline.
			super.uploadCostume(costume, whenDone);
		}
	}

	override protected function uploadSprite(sprite:ScratchSprite, whenDone:Function):void {
		if (ScratchOnline.app.isLoggedIn()) {
			app.addLoadProgressBox("Uploading sprite...");
			new ProjectIOOnline(ScratchOnline.app).uploadSprite(sprite, whenDone);
		} else {
			// If the user isn't logged in, act as if we were offline.
			super.uploadSprite(sprite, whenDone);
		}
	}

	override protected function gifImported(newCostumes:Array):void {
		var uploadCount:int;
		var c:ScratchCostume;

		function uploadComplete():void {
			++uploadCount;
			if (uploadCount >= newCostumes.length) {
				// There are no more frames to import
				app.removeLoadProgressBox();
				whenDone(newCostumes);
			}
		}

		if (!ScratchOnline.app.isLoggedIn()) {
			// If the user isn't logged in, act as if we were offline.
			super.gifImported(newCostumes);
			return;
		}

		uploadCount = 0;
		app.addLoadProgressBox("Uploading image...");

		for (var i:int = 0; i < newCostumes.length; i++) {
			c = newCostumes[i];
			c.prepareToSave();

			// Upload the costumes
			new ProjectIOOnline(ScratchOnline.app).uploadAsset(c.baseLayerMD5, "", c.baseLayerData, uploadComplete);
		}
	}

	override protected function startSoundUpload(sndToUpload:ScratchSound, origName:String, whenDone:Function):void {
		if (Boolean(sndToUpload) && ScratchOnline.app.isLoggedIn()) {
			sndToUpload.prepareToSave();
			app.addLoadProgressBox("Uploading sound...");
			new ProjectIOOnline(ScratchOnline.app).uploadAsset(sndToUpload.md5, "", sndToUpload.soundData, whenDone);
		} else {
			super.startSoundUpload(sndToUpload, origName, whenDone);
		}
	}
}
}
