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

// StagePartOnline.as
// Who knows?
//
// Wrapper around StagePart that adds a title field.


package ui.parts {
	import flash.text.TextFormat;
	import translation.Translator;
	import uiwidgets.EditableLabel;

public class StagePartOnline extends StagePart {

	public function StagePartOnline(app:Scratch)
	{
		super(app);
	}

	override protected function fixLayout():void {
		super.fixLayout();

		if (ScratchOnline.app.isLoggedIn()) {
			projectInfo.y += 2;
		}
	}

	override protected function getProjectTitle(fmt:TextFormat):EditableLabel {
		return new EditableLabel(ScratchOnline.app.jsEditTitle, fmt);
	}

	override protected function updateProjectInfo():void {
		if (app.projectOwner == "") {
			// The project has no owner
			projectInfo.text = "";

			if (app.projectID == "") {
				// The project is a new project
				projectTitle.setEditable(true);
			}
		} else {
			// The project has an owner
			var title:String = Translator.map("by") + " ";
			var sharedText:String = " (" + Translator.map(app.projectIsPrivate ? "unshared" : "shared") + ")";

			if (ScratchOnline.app.userName == app.projectOwner) {
				// We are the owner, show the "(shared)" text
				projectInfo.text = title + app.projectOwner + sharedText;
				projectTitle.setEditable(true);
			} else {
				// We aren't the owner
				projectInfo.text = title + app.projectOwner;
			}
		}
	}
}
}
