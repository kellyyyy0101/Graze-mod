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

// BitmapEditOnline.as
// Who knows?
//
// Wrapper around BitmapEdit that adds backpack drag and drop support.

package svgeditor {
import ui.media.MediaInfoOnline;
import ui.parts.ImagesPart;

import util.JSON;
import util.ServerOnline;

public class BitmapEditOnline extends BitmapEdit {

	public function BitmapEditOnline(app:Scratch, imagesPart:ImagesPart) {
		super(app, imagesPart);
	}

	override public function handleDrop(obj:*):Boolean {
		if (super.handleDrop(obj)) {
			var mio:MediaInfoOnline = obj as MediaInfoOnline;
			if (Boolean(mio) && mio.fromBackpack) {
				ServerOnline.getInstance().logUseItemFromBackpack(util.JSON.stringify({
					"target": ScratchOnline.app.projectID,
					"item": mio.backpackRecord(),
					"uipart": "bmpimageedit"
				}));
			}
			return true;
		}
		return false;
	}
}
}
