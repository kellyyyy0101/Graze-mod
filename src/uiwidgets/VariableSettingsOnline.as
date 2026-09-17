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

// VariableSettingsOnline.as
// Who knows?
//
// Wrapper around VariableSettings that adss cloud variable support.

package uiwidgets {
	import assets.Resources;
	import flash.text.TextField;
	import translation.Translator;

public class VariableSettingsOnline extends VariableSettings {

	public var isPersistent:Boolean;

	private var loggedIn:Boolean;
	private var isScratcher:Boolean;

	private var cloudButton:IconButton;
	private var cloudLabel:TextField;

	public function VariableSettingsOnline(isList:Boolean, isStage:Boolean, loggedIn:Boolean, isScratcher:Boolean) {
		this.loggedIn = loggedIn;
		this.isScratcher = isScratcher;
		super(isList, isStage);

		var canBeCloud:Boolean = !isList && loggedIn && isScratcher && ScratchOnline.app.isCloudDataEnabled();
		this.cloudLabel.visible = canBeCloud;
		this.cloudButton.visible = canBeCloud;

		if (canBeCloud) drawLine();
	}

	public static function strings():Array {
		return [
			'Cloud list (stored on server)',
			'Cloud variable (stored on server)',
			'requires sign in',
			'limit reached'
		];
	}

	override protected function addLabels():void {
		super.addLabels();
		addChild(this.cloudLabel = Resources.makeLabel(Translator.map(isList ? 'Cloud list (stored on server)' : 'Cloud variable (stored on server)'), CSS.normalTextFormat));
	}

	override protected function addButtons():void {
		function setCloud (b:IconButton):void { isPersistent = !isPersistent; updateButtons() }

		super.addButtons();

		addChild(this.cloudButton = new IconButton(setCloud, "checkbox"));
		this.cloudButton.disableMouseover();
		updateCloudButtonAndLabel();
	}

	override protected function updateButtons():void {
		if (this.isPersistent) {
			isLocal = false;
			this.cloudButton.setOn(true);
			localButton.setDisabled(true, 0.2);
			localLabel.alpha = 0.5;
		} else {
			this.cloudButton.setDisabled(isLocal, 0.2);
			this.cloudLabel.alpha = isLocal ? 0.5 : 1;
			super.updateButtons();
		}

		globalButton.setOn(!isLocal);
		this.updateCloudButtonAndLabel();
	}

	private function updateCloudButtonAndLabel():void {
		if (ScratchOnline.app.persistentDataCount >= 10) {
			// We've reached the limit
			this.cloudLabel.text = this.cloudLabel.text.replace(Translator.map('stored on server'), Translator.map('limit reached'));
			this.cloudLabel.alpha = 0.5;
			this.cloudButton.setDisabled(true, 0.2);
		}
	}

	override protected function fixLayout():void {
		super.fixLayout();

		var nextX:int = 15;
		var baseY:int = 45;

		this.cloudButton.x = nextX;
		this.cloudButton.y = baseY + 3;
		this.cloudLabel.x = nextX + 16;
		this.cloudLabel.y = baseY;
	}
}
}
