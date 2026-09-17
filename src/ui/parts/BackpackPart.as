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

// BackpackPart.as
// Who knows?
//
// This part handles the backpack.

package ui.parts {
import blocks.*;
import flash.display.*;
import flash.events.*;
import flash.geom.*;
import flash.net.SharedObject;
import flash.text.*;
import flash.utils.*;
import scratch.*;
import translation.Translator;
import ui.media.*;
import uiwidgets.*;
import util.Base64Encoder;
import util.CachedTimer;
import util.JSON;
import util.ProjectIOOnline;
import util.ServerOnline;
import util.Transition;

public class BackpackPart extends UIPart
{

	public static var localAssets:Object = {};

	public const fullHeight:int = 135;
	public const closedHeight:int = 17;
	public var openAmount:int = 17;
	private const backpackBarH:int = 20;

	private const checkInterval:uint = 3000;

	private var shape:Shape;
	private var title:TextField;
	private var arrow:Shape;

	private var contentsFrame:ScrollFrame;
	private var contents:ScrollFrameContents;

	private var animationRunning:Boolean;
	private var lastThumbnailCheckTime:uint;

	private var onlineApp:ScratchOnline;
	private const disableLocalStorage:Boolean = true;

	public function BackpackPart(app:ScratchOnline) {
		this.app = this.onlineApp = app;
		addChild(this.shape = new Shape());

		addChild(this.title = makeLabel("", CSS.titleFormat));
		addChild(this.arrow = new Shape());

		addContentsPane();
		addEventListener(MouseEvent.MOUSE_DOWN, this.mouseDown);
		updateTranslation();
	}

	public static function strings():Array {
		// Yes, this entire 500+ lines long file only requires 1 string.
		return ["Backpack"];
	}

	public function updateTranslation():void {
		this.title.text = Translator.map("Backpack");
	}

	public function loadBackpack():void {
		fetchInitialContents();
	}

	public function setWidthHeight(w:int, h:int):void {
		this.w = w;
		this.h = h;

		var g:Graphics = this.shape.graphics;
		g.clear();

		drawTopBar(g, CSS.titleBarColors, getTopBarPath(w, this.backpackBarH), w, this.backpackBarH);
		if (this.openAmount > this.closedHeight) {
			drawArrowDown();
		} else {
			drawArrowUp();
		}

		g.lineStyle(1, CSS.borderColor);
		g.drawRect(0, this.backpackBarH, w, h - this.backpackBarH);

		fixLayout();
	}

	private function fixLayout():void {
		this.title.x = 16;
		this.title.y = -1;

		this.arrow.x = (w - this.arrow.width) / 2;
		this.arrow.y = 5;

		this.contentsFrame.x = 1;
		this.contentsFrame.y = this.backpackBarH + 1;
		this.contentsFrame.setWidthHeight(w - 1, h - this.contentsFrame.y);
	}

	private function drawArrowUp():void {
		var g:Graphics = this.arrow.graphics;
		g.clear();

		g.beginFill(CSS.arrowColor);
		g.moveTo(0, 8);
		g.lineTo(10, 8);
		g.lineTo(5, 0);

		g.endFill();
	}

	private function drawArrowDown():void {
		var g:Graphics = this.arrow.graphics;
		g.clear();

		g.beginFill(CSS.arrowColor);
		g.moveTo(0, 2);
		g.lineTo(10, 2);
		g.lineTo(5, 10);

		g.endFill();
	}

	private function addContentsPane():void {
		this.contents = new ScrollFrameContents();
		this.contents.color = CSS.panelColor;

		this.contentsFrame = new ScrollFrame();
		this.contentsFrame.setContents(this.contents);

		addChild(this.contentsFrame);
	}

	public function handleDrop(obj:*):Boolean {
		if (obj is MediaInfo) {
			insertAndSave(obj);
			return true;
		}

		if (obj is Block) {
			var block:MediaInfoOnline = new MediaInfoOnline(obj);
			block.x = obj.x;

			insertAndSave(block);
			return false;
		}

		if (obj is ScratchSprite) {
			var spr:ScratchSprite = obj.duplicate();

			if (this.onlineApp.stagePane.scaleX != 1) {
				spr.scaleX = spr.scaleY = spr.scaleX / this.onlineApp.stagePane.scaleX;
			}

			insertAndSave(new MediaInfoOnline(spr));
			return false;
		}

		return false;
	}

	public function insertAndSave(item:MediaInfoOnline):void {
		var fromBackpack:Boolean = item.fromBackpack;

		if (item.owner) {
			if (item.mycostume) {
				item.mycostume = item.mycostume.duplicate();
			}

			if (item.mysound) {
				item.mysound = item.mysound.duplicate();
			}
		}

		item.owner = null;
		item.fromBackpack = true;
		item.updateLabelAndInfo(true);
		item.computeThumbnail();
		insertItem(item);

		if (item.mysprite) {
			saveSpriteToServer(item);
		}

		this.saveToServer();

		if (this.openAmount < this.fullHeight) {
			toggleOpenClose();
		}

		computeMD5IfNeeded(item);
		ServerOnline.getInstance().logAddItemToBackpack(util.JSON.stringify({
			"source": ScratchOnline.app.projectID,
			"wasAlreadyInBackPack": fromBackpack,
			"item": item.backpackRecord()
		}));
	}

	private function saveSpriteToServer(item:MediaInfo):void {
		function uploadDone(md5:String):void {
			item.md5 = md5;
			saveToServer();
		}

		new ProjectIOOnline(this.onlineApp).uploadSprite(item.mysprite.copyToShare(), uploadDone);
	}

	private function fetchInitialContents():void {
		function gotBackpack(response:String):void {
			removeAllItems();

			if (!response) {
				return;
			}

			var items:Array = util.JSON.parse(response) as Array;
			if (!items) {
				return;
			}

			addAllItems(items);
			fixItemLayout();
		}

		if (this.onlineApp.isLoggedIn()) {
			ServerOnline.getInstance().getBackpack(this.onlineApp.userName, gotBackpack);
		} else {
			readFromLocalStorage();
		}
	}

	private function fetchNewItemsFromServer(whenDone:Function):void {
		function gotBackpack(response:String):void {
			if (response) {
				var items:Array = util.JSON.parse(response) as Array;

				if (Boolean(items) && items.length > 0) {
					var md5s:Array = [];

					for each (var item:MediaInfo in allItems()) {
						md5s.push(item.md5);
					}

					var newItems:Array = [];
					for each (var obj:Object in items) {
						if (md5s.indexOf(obj.md5) < 0) {
							newItems.push(obj);
						}
					}
					addAllItems(newItems);
				}
			}

			if (whenDone != null) whenDone();
		}

		ServerOnline.getInstance().getBackpack(this.onlineApp.userName, gotBackpack);
	}

	private function saveToServer():void {
		function done(response:String):void {};

		for each (var item:MediaInfo in allItems()) {
			computeMD5IfNeeded(item);
		}


		var elements:Array = [];

		for each (var item:MediaInfo in allItems()) {
			if (Boolean(item.md5) && Boolean(item.md5.length > 0) || Boolean(item.scripts)) {
				elements.push(item.backpackRecord());
			}
		}

		// You can't use the backpack while logged out so I guess this is pointless?
		if (this.onlineApp.isLoggedIn()) {
			ServerOnline.getInstance().setBackpack(util.JSON.stringify(elements), this.onlineApp.userName, done);
		} else {
			saveToLocalStorage(elements);
		}
	}

	private function computeMD5IfNeeded(item:MediaInfo):void {
		var WasEdited:int = -10;
		var count:int = 0;
		var md5Missing:Boolean = !(Boolean(item.md5) && item.md5.length > 0 || item.scripts);

		if (Boolean(item.mycostume) && (md5Missing || item.mycostume.baseLayerID == WasEdited)) {
			item.mycostume.prepareToSave();
			item.md5 = item.mycostume.baseLayerMD5;
			count++;
		}

		if (Boolean(item.mysound) && (md5Missing || item.mysound.soundID == WasEdited || item.mysound.format == "squeak")) {
			item.mysound.prepareToSave();
			item.md5 = item.mysound.md5;
			new ProjectIOOnline(this.onlineApp).uploadAsset(item.md5, ".wav", item.mysound.soundData, function():void {});
			count++;
		}

		if (count > 0) {
			this.onlineApp.setSaveNeeded(true);
		}
	}

	private function removeDuplicates():void {
		var items:Array = [];

		for each (var item:MediaInfo in allItems()) {
			if (item.md5) {
				if (items.indexOf(item.md5) < 0) {
					items.push(item.md5);
				} else {
					this.contents.removeChild(item);
				}
			}
		}
		fixItemLayout();
	}

	private function saveToLocalStorage(param1:Array):void {
		if (this.disableLocalStorage || !this.onlineApp.isOffline) {
			return;
		}

		var assets:Object = {};

		for each(var item:MediaInfo in allItems()) {
			recordAssetsIn(item, assets);
		}
		var sharedObj:SharedObject = SharedObject.getLocal("Scratch");
		sharedObj.data.backpack = util.JSON.stringify(param1);
		sharedObj.data.backpackAssets = assets;
		sharedObj.flush();
	}

	private function recordAssetsIn(item:MediaInfo, dict:Object):void {
		if (item.mycostume) {
			var costume:ScratchCostume = item.mycostume;

			costume.prepareToSave();
			if (costume.baseLayerData) {
				dict[costume.baseLayerMD5] = Base64Encoder.encode(costume.baseLayerData);
			} else {
				recordAsset(costume.baseLayerMD5, dict);
			}
		} else if (item.mysound) {
			var sound:ScratchSound = item.mysound;

			if (sound.soundData) {
				dict[sound.md5] = Base64Encoder.encode(sound.soundData);
			} else {
				recordAsset(sound.md5, dict);
			}
		} else {
			recordAsset(item.md5, dict);
		}
	}

	private function recordAsset(md5:String, dict:Object):void {
		function gotAsset(data:ByteArray):void {
			dict[md5] = Base64Encoder.encode(data);
		}

		ServerOnline.getInstance().getAsset(md5, gotAsset);
	}

	private function readFromLocalStorage():void {
		if (this.disableLocalStorage || !this.onlineApp.isOffline) {
			return;
		}

		var sharedObj:SharedObject = SharedObject.getLocal("Scratch");

		if (sharedObj.data.backpackAssets) {
			localAssets = {};
			for (var md5:String in sharedObj.data.backpackAssets) {
				localAssets[md5] = Base64Encoder.decode(sharedObj.data.backpackAssets[md5]);
			}
		}

		removeAllItems();

		if (sharedObj.data.backpack) {
			addAllItems(util.JSON.parse(sharedObj.data.backpack) as Array);
		}
	}

	public function deleteItem(item:MediaInfo):void {
		this.contents.removeChild(item);
		this.onlineApp.runtime.recordForUndelete(item, 0, 0, 0, "backpack");
		this.saveToServer();
		this.fixItemLayout();

		ServerOnline.getInstance().logDeleteItemFromBackpack(util.JSON.stringify({"item": item.backpackRecord()}));
	}

	private function addAllItems(items:Array):void {
		if (items.length == 0) {
			return;
		}

		for each (var item:Object in items) {
			if ("script" == item.type) {
				if (Boolean(item.md5) && !item.script) {
					item.script = item.md5;
					delete item.md5;
				}

				if (!item.scripts) {
					item.scripts = [];
				}

				if (item.script is String) {
					item.scripts.push(BlockIO.stackToArray(BlockIO.stringToStack(item.script)));
				}
			}

			if (["image", "script", "sound", "sprite"].indexOf(item.type) >= 0) {
				var mio:MediaInfo = new MediaInfoOnline(item);
				mio.updateLabelAndInfo(true);
				mio.computeThumbnail();
				this.contents.addChild(mio);
			}
		}
		fixItemLayout();
	}

	private function insertItem(item:MediaInfoOnline):void {
		for each(var mio:MediaInfoOnline in this.allItems()) {
			if (Boolean(mio.md5) && mio.md5 == item.md5) {
				this.contents.removeChild(mio);
			}
		}

		var x:int = this.contents.globalToLocal(item.localToGlobal(new Point(0, 0))).x;

		for (var i:int = 0; i < this.contents.numChildren; i++) {
			if (this.contents.getChildAt(i).x > x) {
				break;
			}
		}

		item.addDeleteButton();
		item.fromBackpack = true;

		this.contents.addChildAt(item, i);
		fixItemLayout();
	}

	private function allItems():Array {
		var items:Array = [];

		for (var i:int = 0; i < this.contents.numChildren; i++) {
			var item:MediaInfo = this.contents.getChildAt(i) as MediaInfo;

			if (item) {
				items.push(item);
			}
		}

		return items;
	}

	private function removeAllItems():void {
		while (this.contents.numChildren > 0) {
			this.contents.removeChildAt(0);
		}
	}

	private function fixItemLayout():void {
		var offset:int = 10;

		for each (var item:MediaInfo in this.allItems()) {
			item.x = offset;
			item.y = 2;
			offset += item.frameWidth + 10;
		}
	}

	private function mouseDown(evt:MouseEvent):void {
		var p:Point = globalToLocal(new Point(evt.stageX, evt.stageY));

		if (p.y > 0 && p.y < this.backpackBarH) {
			toggleOpenClose();
			evt.stopImmediatePropagation();
		}
	}

	private function toggleOpenClose():void {
		function setOpenAmount(amount:int):void {
			openAmount = amount;
			onlineApp.fixLayout();
		}

		function animationDone():void {
			animationRunning = false;
			if (openAmount == fullHeight) {
				addEventListener(Event.ENTER_FRAME, updateThumbnails);
			} else {
				removeEventListener(Event.ENTER_FRAME, updateThumbnails);
			}
		}

		// Hey, look, that's us!
		// If only it was used...
		var backpack:BackpackPart = this;

		if (this.animationRunning) return;

		var h:int = this.openAmount < this.fullHeight ? this.fullHeight : this.closedHeight;
		this.animationRunning = true;

		Transition.cubic(setOpenAmount, this.openAmount, h, 0.1, animationDone);
	}

	private function updateThumbnails(evt:Event):void {
		if (CachedTimer.getCachedTimer() - this.lastThumbnailCheckTime > this.checkInterval) {
			for each (var item:MediaInfo in this.allItems()) {
				item.updateMediaThumbnail();
			}

			this.lastThumbnailCheckTime = CachedTimer.getCachedTimer();
		}
	}
}
}
