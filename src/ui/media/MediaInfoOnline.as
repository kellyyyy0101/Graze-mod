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

// MediaInfoOnline.as
// Who knows?
//
// Wrapper around MediaInfo.

package ui.media {
   import flash.display.*;
   import flash.events.*;
   import flash.net.URLLoader;
   import flash.utils.*;
   import logging.LogLevel;
   import scratch.*;
   import svgutils.SVGImporter;
   import ui.parts.*;
   import util.*;
   
public class MediaInfoOnline extends MediaInfo {

	public var fromBackpack:Boolean;
	private var loaders:Array = [];

	public function MediaInfoOnline(obj:*, owningObj:ScratchObj = null) {
		super(obj, owningObj);
	}

	override public function computeThumbnail():Boolean {
		if (super.computeThumbnail()) return true;

		var ext:String = fileType(md5);
		if (["gif", "png", "jpg", "jpeg", "svg"].indexOf(ext) > -1) {
			this.setImageThumbnail(md5);
		} else {
			if (ext != "json") return false;
			this.setSpriteThumbnail();
		}
		return true;
	}

	override public function objToGrab(evt:MouseEvent):* {
		var mio:MediaInfoOnline = super.objToGrab(evt);

		if (this.getBackpack()) mio.fromBackpack = true;
		return mio;
	}

	private function stopLoading():void {
		for each(var loader:URLLoader in this.loaders) {
			if (loader) loader.close();
		}
		this.loaders = [];
	}

	private function setImageThumbnail(md5:String):void {
		var importer:SVGImporter;

		// Same as in MediaLibraryItem.setImageThumbnail
		function gotSVGData(data:ByteArray):void {
			if (data) {
				importer = new SVGImporter(XML(data));
				importer.loadAllImages(svgImagesLoaded);
			} else {
				imageError(null);
			}
		}

		// Very similar to the one in MediaLibraryItem.setImageThumbnail
		function svgImagesLoaded():void {
			var c:ScratchCostume = new ScratchCostume("", null);
			c.setSVGRoot(importer.root, false);
			setThumbnailFromCostume(c);
		}

		function gotImageData(data:ByteArray):void {
			var loader:Loader;
			if (data) {
				loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, imageDecoded);
				loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, imageError);
				loader.loadBytes(data);
			} else {
				imageError(null);
			}
		}

		function imageError(e:IOErrorEvent):void {
			Scratch.app.log(LogLevel.WARNING, "MediaInfoOnline failed to set thumbnail", {"md5": md5});
		}

		function imageDecoded(e:Event):void {
			var costume:ScratchCostume = new ScratchCostume("", e.target.content.bitmapData, ScratchCostume.kCalculateCenter, ScratchCostume.kCalculateCenter, bitmapResolution);
			setThumbnailFromCostume(costume);
		}

		this.loaders.push(ServerOnline.getInstance().getAsset(md5, fileType(md5) == "svg" ? gotSVGData : gotImageData));
	}

	private function setThumbnailFromCostume(c:ScratchCostume):void {
		var width:int = c.width();

		isBackdrop = width == 480 || width == 960;
		setThumbnailBM(c.thumbnail(thumbnailWidth, thumbnailHeight, isBackdrop));
		if (forBackpack) {
			updateLabelAndInfo(forBackpack);
		}
	}

	// Similar to MediaLibraryItem.setSpriteThumbnail
	private function setSpriteThumbnail():void {
		function gotJSONData(data:String):void {
			var md5:String;
			if (data) {
				var sprObj:Object = util.JSON.parse(data);
				if (sprObj.objName is String) setInfo(sprObj.objName);
				if (sprObj.costumes is Array && sprObj.currentCostumeIndex is Number) {
					var cList:Array = sprObj.costumes;
					var cObj:Object = cList[Math.round(sprObj.currentCostumeIndex) % cList.length];
					md5 = cObj ? cObj.baseLayerMD5 : null;
					if (md5) {
						setImageThumbnail(md5);
					}
				}
			}
		}

		this.loaders.push(ServerOnline.getInstance().getAsset(md5, gotJSONData));
	}

	override protected function deleteMe(param1:* = null):void {
		this.stopLoading();
		var backpackPart:BackpackPart = this.getBackpack() as BackpackPart;

		if (backpackPart) {
			Scratch.app.runtime.recordForUndelete(this, 0, 0, 0, "backpack");
			backpackPart.deleteItem(this);
		} else {
			super.deleteMe(param1);
		}
	}

	override protected function getBackpack():UIPart {
		var o:DisplayObject = parent;

		while (o != null) {
			if (o is BackpackPart) {
				return o as BackpackPart;
			}
			o = o.parent;
		}

		return null;
	}
}
}
