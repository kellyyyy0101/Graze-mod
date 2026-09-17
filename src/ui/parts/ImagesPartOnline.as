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

// ImagesPartOnline.as
// Who knows?
//
// Wrapper around ImagesPart that makes it use the online image editors.

package ui.parts {
import flash.display.BitmapData;
import svgeditor.BitmapEditOnline;
import svgeditor.SVGEditOnline;

public class ImagesPartOnline extends ImagesPart {

	public function ImagesPartOnline(app:Scratch)
	{
		super(app);
	}

	override protected function addEditor(isSVG:Boolean):void {
		if (isSVG) {
			addChild(editor = new SVGEditOnline(app, this));
		}
		else {
			addChild(editor = new BitmapEditOnline(app, this));
		}
	}

	override protected function savePhotoAsCostume(photo:BitmapData):void {
		try {
			ScratchOnline.app.logImageImported("photo.png", true);
		}
		catch (error:Error) {
		}

		super.savePhotoAsCostume(photo);
	}
}
}
