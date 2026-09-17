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

// MediaLibBuilder.as
// Who knows?
//
// Builds the media library.

package util {
import blocks.Block;

import flash.display.DisplayObject;
import flash.events.Event;
import flash.geom.Rectangle;
import flash.net.FileReference;
import flash.utils.ByteArray;

import logging.LogLevel;

import scratch.ScratchCostume;
import scratch.ScratchObj;
import scratch.ScratchSound;
import scratch.ScratchSprite;

import uiwidgets.DialogBox;

public class MediaLibBuilder
{

	private static var processed:Array;
	private static var result:String;

	public static function exportMedia():void {
		function saved():void {
			for each (var c:ScratchCostume in Scratch.app.stagePane.costumes) {
				addCostume(c, "backdrop");
			}

			for each (var obj:ScratchObj in Scratch.app.stagePane.sprites()) {
				for each (var c:ScratchCostume in obj.costumes) {
					addCostume(c, "costume");
				}
			}

			for each (var obj:ScratchObj in Scratch.app.stagePane.allObjects()) {
				for each (var snd:ScratchSound in obj.sounds) {
					addSound(snd);
				}
			}

			finish();
		}

		start();
		ScratchOnline.app.setSaveNeeded();
		ScratchOnline.app.saveNow(true, saved);
	}

	public static function exportSprites():void {
		function uploadSprite(spr:ScratchSprite):void {
			function spriteSaved(name:String):void {
				addSprite(spr, name);
				if (++uploadCount == sprites.length) finish();
			}

			new ProjectIOOnline(ScratchOnline.app).uploadSprite(spr.copyToShare(), spriteSaved);
		}

		start();
		var uploadCount:int = 0;
		var sprites:Array = Scratch.app.stagePane.sprites();
		for each(var spr:ScratchSprite in sprites) {
			uploadSprite(spr);
		}
	}

	public static function checkJSONFile():void {
		function fileLoaded (evt:Event):void {
			var data:ByteArray = FileReference(evt.target).data;
			try {
				var jsonData:String = data.readUTFBytes(data.length);
				var jsonObj:Array = util.JSON.parse(jsonData) as Array;
			}
			catch (e:*) {
			}

			if (jsonObj) {
				DialogBox.notify("Success!", "JSON parsed. " + jsonObj.length + " items", Scratch.app.stage);
			} else {
				DialogBox.notify("Error", "Bad JSON file. Missing comma?", Scratch.app.stage);
			}
		}

		Scratch.loadSingleFile(fileLoaded);
	}

	private static function addCostume(c:ScratchCostume, type:String):void {
		var md5:String = c.baseLayerMD5;
		if (processed.indexOf(md5) != -1) return;
		processed.push(md5);

		var data:String = "  {";
		data += pair("name", c.costumeName);
		data += pair("md5", md5);
		data += pair("type", type);
		data += pair("tags", []);
		data += pair("info", costumeWidthHeight(c), true);
		result += data;
	}

	private static function costumeWidthHeight(c:ScratchCostume):Array {
		var o:DisplayObject = c.displayObj();
		var r:Rectangle = o.getBounds(o);
		return [Math.ceil(r.width), Math.ceil(r.height)];
	}

	private static function addSound(snd:ScratchSound):void {
		var md5:String = snd.md5;
		if (processed.indexOf(md5) != -1) return;
		processed.push(md5);

		var rate:Number = Math.round(snd.sampleCount * 1000 / snd.rate) / 1000;
		var data:String = "  {";
		data += pair("name", snd.soundName);
		data += pair("md5", md5);
		data += pair("type", "sound");
		data += pair("tags", []);
		data += pair("info", [rate], true);
		result += data;
	}

	private static function addSprite(spr:ScratchSprite, md5:String):void {
		if (processed.indexOf(md5) != -1) return;
		processed.push(md5);

		var data:String = "  {";
		data += pair("name", spr.objName);
		data += pair("md5", md5);
		data += pair("type", "sprite");
		data += pair("tags", []);
		data += pair("info", [countScripts(spr), spr.costumes.length, spr.sounds.length], true);
		result += data;
	}

	private static function countScripts(spr:ScratchSprite):int {
		var count:int = 0;
		for each (var b:Block in spr.scripts) {
			// Every script starts with a hat block.
			if (b.isHat) {
				count++;
			}
		}

		return count;
	}

	private static function start():void {
		result = "[\n";
		processed = [];
	}

	private static function finish():void {
		if (result.length < 5) {
			result = "[]";
		} else {
			result = result.substring(0, result.length - 2) + "\n]\n";
		}

		Scratch.app.log(LogLevel.INFO, result);
	}

	private static function pair(field:String, value:*, isEnding:Boolean = false):String {
		return "\"" + field + "\": " + util.JSON.stringify(value) + (isEnding ? "},\n" : ", ");
	}
}
}
