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

// ScriptsPartOnline.as
// Who knows?
//
// Wrapper around ScriptsPart that makes it use the online version of ScriptsPane.

package ui.parts {
import uiwidgets.ScriptsPane;
import uiwidgets.ScriptsPaneOnline;
import uiwidgets.ScrollFrame;

public class ScriptsPartOnline extends ScriptsPart {

	public function ScriptsPartOnline(app:Scratch) {
		super(app);
	}

	override protected function addScriptsPane():ScriptsPane {
		var scriptsPane:ScriptsPane = new ScriptsPaneOnline(app);
		scriptsFrame = new ScrollFrame();
		scriptsFrame.setContents(scriptsPane);
		addChild(scriptsFrame);

		return scriptsPane;
	}
}
}
