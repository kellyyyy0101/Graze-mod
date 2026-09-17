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

// ScriptsPaneOnline.as
// Who knows?
//
// Wrapper around ScripsPane that makes it support backpack drag and drop.

package uiwidgets {
	import ui.media.MediaInfoOnline;

	import util.JSON;
	import util.ServerOnline;

public class ScriptsPaneOnline extends ScriptsPane {

	public function ScriptsPaneOnline(app:Scratch)
	{
		super(app);
	}

	override public function handleDrop(obj:*):Boolean {
		var info:MediaInfoOnline = obj as MediaInfoOnline;
		if (Boolean(info) && info.fromBackpack) {
			if (super.handleDrop(obj)) {
				ServerOnline.getInstance().logUseItemFromBackpack(util.JSON.stringify({
					"target": ScratchOnline.app.projectID,
					"item": info.backpackRecord(),
					"uipart": "scriptspane"
				}));

				return true;
			}

			return false;
		}

		return super.handleDrop(obj);
	}
}
}
